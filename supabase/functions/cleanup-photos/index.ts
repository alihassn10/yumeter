// Removes meal photos that no meal points to. Run daily by pg_cron.
//
// The schedule calls with the publishable key, which is public, so this
// function may be triggered by anyone. That is safe by construction: it only
// ever deletes what the orphaned_meal_photos() query returns, photos at least
// a week old that belong to no meal, and each call is capped.

import { withSupabase } from 'npm:@supabase/server@1.8.0'

const BUCKET = 'meal-photos'

// A run removes at most BATCH × MAX_BATCHES photos; the next day's run picks
// up anything left, so one call can never turn into a long, heavy job.
const BATCH = 500
const MAX_BATCHES = 4

export default {
  fetch: withSupabase({ auth: 'publishable' }, async (_req, ctx) => {
    let removed = 0

    for (let i = 0; i < MAX_BATCHES; i++) {
      const { data: paths, error } = await ctx.supabaseAdmin.rpc('orphaned_meal_photos', {
        max_rows: BATCH,
      })
      if (error) {
        console.error('cleanup-photos: listing orphans failed', error.message)
        return Response.json({ removed, error: 'list_failed' }, { status: 500 })
      }
      if (!paths || paths.length === 0) break

      const { error: removeError } = await ctx.supabaseAdmin.storage
        .from(BUCKET)
        .remove(paths as string[])
      if (removeError) {
        console.error('cleanup-photos: removing orphans failed', removeError.message)
        return Response.json({ removed, error: 'remove_failed' }, { status: 500 })
      }

      removed += paths.length
      if (paths.length < BATCH) break
    }

    console.log(`cleanup-photos: removed ${removed} orphaned photo(s)`)
    return Response.json({ removed })
  }),
}
