-- Add missing UPDATE and DELETE RLS policies for watch_history.
-- Without UPDATE, re-watches silently fail to update the row in Supabase.
-- Without DELETE, _trimWatchHistory silently fails, leaving stale entries forever.

DROP POLICY IF EXISTS "Users can update their watch history" ON watch_history;
CREATE POLICY "Users can update their watch history"
  ON watch_history FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete from their watch history" ON watch_history;
CREATE POLICY "Users can delete from their watch history"
  ON watch_history FOR DELETE
  USING (auth.uid() = user_id);
