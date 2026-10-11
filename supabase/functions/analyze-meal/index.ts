// Estimates a meal's calories and macros from a photo the user has already
// uploaded to the meal-photos bucket.
//
// POST { "photo_path": "<user id>/<meal id>.jpg" }
//
// The function only returns an estimate. The app shows it for the user to
// review and edit, then saves the meal itself, so nothing reaches the log
// without the user seeing it first.

import { withSupabase } from 'npm:@supabase/server@1.8.0'
import { estimateMeal, ProviderError, type RawEstimate } from './gemini.ts'

const BUCKET = 'meal-photos'

// Photos a user may analyse per UTC day. Several meals a day with room for
// retakes; override with the DAILY_PHOTO_LIMIT secret without redeploying.
const DEFAULT_DAILY_LIMIT = 20

// Matches the bucket's allowed types; used when storage reports no type.
const MIME_BY_EXTENSION: Record<string, string> = {
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
  heic: 'image/heic',
  heif: 'image/heif',
}

function error(status: number, code: string, message: string, headers?: HeadersInit) {
  return Response.json({ error: { code, message } }, { status, headers })
}

// Bounds mirror the meals table's check constraints, so an estimate the app
// saves unchanged can never be rejected by the database.
function grams(value: unknown, max = 2000): number {
  const n = typeof value === 'number' && Number.isFinite(value) ? Math.round(value) : 0
  return Math.min(Math.max(n, 0), max)
}

function text(value: unknown, fallback: string, max: number): string {
  const s = typeof value === 'string' ? value.trim() : ''
  return (s || fallback).slice(0, max)
}

/**
 * Cleans the model's output. Totals are summed here from the items rather than
 * taken from the model, so the meal always equals the sum of what it lists.
 */
function normalize(raw: RawEstimate) {
  const items = (Array.isArray(raw.items) ? raw.items : []).slice(0, 20).map((item) => ({
    name: text(item?.name, 'Item', 100),
    portion: text(item?.portion, '', 60),
    calories: grams(item?.calories, 20000),
    protein_grams: grams(item?.protein_grams),
    carb_grams: grams(item?.carb_grams),
    fat_grams: grams(item?.fat_grams),
  }))

  const sum = (key: 'calories' | 'protein_grams' | 'carb_grams' | 'fat_grams') =>
    items.reduce((total, item) => total + item[key], 0)

  return {
    name: text(raw.name, 'Meal', 200),
    calories: Math.min(sum('calories'), 20000),
    protein_grams: Math.min(sum('protein_grams'), 2000),
    carb_grams: Math.min(sum('carb_grams'), 2000),
    fat_grams: Math.min(sum('fat_grams'), 2000),
    items,
  }
}

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method !== 'POST') return error(405, 'method_not_allowed', 'Use POST.')

    const userId = ctx.userClaims!.id

    let photoPath: unknown
    try {
      photoPath = (await req.json())?.photo_path
    } catch {
      return error(400, 'invalid_body', 'Send JSON with a photo_path.')
    }

    // Storage policies already confine the user to their own folder; checking
    // here as well gives a clear error instead of a confusing "not found".
    if (
      typeof photoPath !== 'string' ||
      photoPath.length > 300 ||
      !photoPath.startsWith(`${userId}/`) ||
      photoPath.includes('..')
    ) {
      return error(400, 'invalid_photo_path', 'photo_path must point into your own folder.')
    }

    // Downloaded with the caller's session, so RLS decides access.
    const { data: blob, error: downloadError } = await ctx.supabase.storage
      .from(BUCKET)
      .download(photoPath)
    if (downloadError || !blob) {
      return error(404, 'photo_not_found', 'No photo at that path.')
    }

    const extension = photoPath.split('.').pop()?.toLowerCase() ?? ''
    const mimeType = Object.values(MIME_BY_EXTENSION).includes(blob.type)
      ? blob.type
      : MIME_BY_EXTENSION[extension]
    if (!mimeType) {
      return error(415, 'unsupported_image', 'Use a JPEG, PNG, WebP or HEIC photo.')
    }

    // Claimed only now, so a malformed request never spends allowance.
    const configured = Number(Deno.env.get('DAILY_PHOTO_LIMIT'))
    const limit = Number.isInteger(configured) && configured > 0 ? configured : DEFAULT_DAILY_LIMIT
    const { data: allowed, error: claimError } = await ctx.supabaseAdmin.rpc('claim_analysis', {
      p_user: userId,
      daily_limit: limit,
    })
    if (claimError) {
      // Fail closed: without the counter there is no way to protect the quota.
      console.error('analyze-meal: claiming allowance failed', claimError.message)
      return error(503, 'busy', 'Photo analysis is busy right now. Try again shortly.')
    }
    if (allowed !== true) {
      const now = new Date()
      const midnight = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1)
      const seconds = Math.ceil((midnight - now.getTime()) / 1000)
      return error(
        429,
        'daily_limit',
        `You have used today's ${limit} photo analyses.`,
        { 'Retry-After': `${seconds}` },
      )
    }

    let raw: RawEstimate
    try {
      raw = await estimateMeal(new Uint8Array(await blob.arrayBuffer()), mimeType)
    } catch (e) {
      console.error('analyze-meal provider failure', e instanceof Error ? e.message : e)
      // The user got nothing, so the attempt does not count.
      const { error: refundError } = await ctx.supabaseAdmin.rpc('refund_analysis', { p_user: userId })
      if (refundError) console.error('analyze-meal: refund failed', refundError.message)
      if (e instanceof ProviderError && e.kind === 'rateLimited') {
        return error(
          429,
          'rate_limited',
          'Too many photos analysed just now. Try again shortly.',
          e.retryAfter ? { 'Retry-After': e.retryAfter } : undefined,
        )
      }
      if (e instanceof ProviderError && e.kind === 'busy') {
        return error(503, 'busy', 'Photo analysis is busy right now. Try again shortly.')
      }
      return error(502, 'analysis_failed', 'The photo could not be analysed. Try again.')
    }

    if (raw?.is_food !== true) {
      return error(422, 'not_food', 'No food or drink was found in the photo.')
    }

    const estimate = normalize(raw)
    if (estimate.items.length === 0) {
      return error(422, 'not_food', 'No food or drink was found in the photo.')
    }

    return Response.json(estimate)
  }),
}
