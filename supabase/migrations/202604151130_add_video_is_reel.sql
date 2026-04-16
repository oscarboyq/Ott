ALTER TABLE public.videos
ADD COLUMN IF NOT EXISTS is_reel BOOLEAN NOT NULL DEFAULT false;

UPDATE public.videos
SET is_reel = false
WHERE is_reel IS NULL;

CREATE INDEX IF NOT EXISTS videos_is_reel_created_at_idx
ON public.videos (is_reel, created_at DESC);