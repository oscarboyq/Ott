-- Upgrade video ratings to a 10-point scale and store aggregate rating counts on videos.

ALTER TABLE videos
  ADD COLUMN IF NOT EXISTS rating_count INTEGER NOT NULL DEFAULT 0;

ALTER TABLE video_ratings
  DROP CONSTRAINT IF EXISTS video_ratings_rating_check;

ALTER TABLE video_ratings
  ADD CONSTRAINT video_ratings_rating_check CHECK (rating >= 1 AND rating <= 10);

DO $$
DECLARE
  max_existing_rating INTEGER;
BEGIN
  SELECT MAX(rating) INTO max_existing_rating FROM video_ratings;

  IF max_existing_rating IS NOT NULL AND max_existing_rating <= 5 THEN
    UPDATE video_ratings
    SET rating = LEAST(10, GREATEST(1, rating * 2));
  END IF;
END $$;

CREATE OR REPLACE FUNCTION refresh_video_rating_stats(target_video_id UUID)
RETURNS VOID AS $fn$
BEGIN
  UPDATE videos SET
    rating = COALESCE((SELECT ROUND(AVG(rating)::numeric, 1)::double precision FROM video_ratings WHERE video_id = target_video_id), 0),
    rating_count = COALESCE((SELECT COUNT(*)::integer FROM video_ratings WHERE video_id = target_video_id), 0),
    updated_at = NOW()
  WHERE id = target_video_id;
END;
$fn$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_video_rating_stats_trigger()
RETURNS TRIGGER AS $fn$
BEGIN
  PERFORM refresh_video_rating_stats(COALESCE(NEW.video_id, OLD.video_id));
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sync_video_rating_stats ON video_ratings;
CREATE TRIGGER sync_video_rating_stats
  AFTER INSERT OR UPDATE OR DELETE ON video_ratings
  FOR EACH ROW
  EXECUTE FUNCTION sync_video_rating_stats_trigger();

UPDATE videos
SET rating = 0, rating_count = 0;

DO $$
DECLARE
  rating_row RECORD;
BEGIN
  FOR rating_row IN
    SELECT DISTINCT video_id FROM video_ratings
  LOOP
    PERFORM refresh_video_rating_stats(rating_row.video_id);
  END LOOP;
END $$;

ALTER TABLE video_ratings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can update their own ratings" ON video_ratings;
DROP POLICY IF EXISTS "Users can delete their own ratings" ON video_ratings;
DROP POLICY IF EXISTS "Users can rate videos" ON video_ratings;
DROP POLICY IF EXISTS "Users can view ratings" ON video_ratings;
DROP POLICY IF EXISTS "Anyone can view ratings" ON video_ratings;
DROP POLICY IF EXISTS "Authenticated users can rate once" ON video_ratings;

CREATE POLICY "Anyone can view ratings"
  ON video_ratings FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can rate once"
  ON video_ratings FOR INSERT
  WITH CHECK (auth.uid() = user_id);