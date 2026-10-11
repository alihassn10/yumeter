// Permanently deletes the caller's account and everything in it.
//
// POST, signed in. Order matters:
//   1. Remove the user's photos from meal-photos/<user id>/ through the
//      Storage API (storage objects cannot be deleted from SQL).
//   2. Delete the auth user. The profiles and meals foreign keys cascade, so
//      the database rows go with it in one step.
//
// If removing a photo fails, the account is still deleted: the user asked
// for it, and any photo left behind belongs to no meal, so the daily
// cleanup-photos job removes it.

import { withSupabase } from 'npm:@supabase/server@1.8.0'

const BUCKET = 'meal-photos'
const PAGE = 1000

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method !== 'POST') {
      return Response.json({ error: { code: 'method_not_allowed' } }, { status: 405 })
    }

    const userId = ctx.userClaims!.id
    const storage = ctx.supabaseAdmin.storage.from(BUCKET)

    // Removing while listing would shift the offsets, so list the whole
    // folder first, then remove.
    const paths: string[] = []
    for (let offset = 0; ; offset += PAGE) {
      const { data, error } = await storage.list(userId, { limit: PAGE, offset })
      if (error) {
        console.error('delete-account: listing photos failed', error.message)
        break
      }
      paths.push(...data.map((file) => `${userId}/${file.name}`))
      if (data.length < PAGE) break
    }
    for (let i = 0; i < paths.length; i += PAGE) {
      const { error } = await storage.remove(paths.slice(i, i + PAGE))
      if (error) console.error('delete-account: removing photos failed', error.message)
    }

    const { error } = await ctx.supabaseAdmin.auth.admin.deleteUser(userId)
    if (error) {
      console.error('delete-account: deleting user failed', error.message)
      return Response.json(
        { error: { code: 'delete_failed', message: 'The account could not be deleted. Try again.' } },
        { status: 500 },
      )
    }

    console.log(`delete-account: deleted a user and ${paths.length} photo(s)`)
    return Response.json({ deleted: true })
  }),
}
