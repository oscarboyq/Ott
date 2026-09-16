-- Add Bunny Stream media provider fields to series_episodes,
-- mirroring the same columns on the videos table.

ALTER TABLE public.series_episodes
  ADD COLUMN IF NOT EXISTS media_provider      TEXT,
  ADD COLUMN IF NOT EXISTS provider_video_id   TEXT,
  ADD COLUMN IF NOT EXISTS media_status        TEXT,
  ADD COLUMN IF NOT EXISTS processing_progress INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS media_error         TEXT;
