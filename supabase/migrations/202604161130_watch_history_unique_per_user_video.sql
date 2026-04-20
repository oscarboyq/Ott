-- Ensure each user has only one history row per video, preserving the latest
-- resume position and watched timestamp.

DELETE FROM watch_history AS older
USING watch_history AS newer
WHERE older.user_id = newer.user_id
  AND older.video_id = newer.video_id
  AND (
    older.watched_at < newer.watched_at
    OR (
      older.watched_at = newer.watched_at
      AND older.created_at < newer.created_at
    )
    OR (
      older.watched_at = newer.watched_at
      AND older.created_at = newer.created_at
      AND older.id < newer.id
    )
  );

ALTER TABLE watch_history
  DROP CONSTRAINT IF EXISTS watch_history_user_id_video_id_key;

ALTER TABLE watch_history
  ADD CONSTRAINT watch_history_user_id_video_id_key
  UNIQUE (user_id, video_id);

CREATE INDEX IF NOT EXISTS idx_watch_history_user_video
  ON watch_history(user_id, video_id);