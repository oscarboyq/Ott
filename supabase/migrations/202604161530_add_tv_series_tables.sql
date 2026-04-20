-- Keep movies and reels in public.videos.
-- TV series use a separate hierarchy: series -> seasons -> episodes.

CREATE TABLE IF NOT EXISTS public.series (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  slug TEXT UNIQUE,
  description TEXT,
  poster_url TEXT,
  backdrop_url TEXT,
  trailer_url TEXT,
  category TEXT,
  tagline TEXT,
  release_date DATE,
  is_featured BOOLEAN NOT NULL DEFAULT false,
  is_published BOOLEAN NOT NULL DEFAULT true,
  is_free BOOLEAN NOT NULL DEFAULT false,
  views_count INTEGER NOT NULL DEFAULT 0,
  created_by UUID REFERENCES auth.users ON DELETE SET NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.series_seasons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  series_id UUID NOT NULL REFERENCES public.series(id) ON DELETE CASCADE,
  season_number INTEGER NOT NULL,
  title TEXT,
  description TEXT,
  poster_url TEXT,
  release_date DATE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  CONSTRAINT series_seasons_series_id_season_number_key UNIQUE (
    series_id,
    season_number
  ),
  CONSTRAINT series_seasons_season_number_positive CHECK (season_number > 0)
);

CREATE TABLE IF NOT EXISTS public.series_episodes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  series_id UUID NOT NULL REFERENCES public.series(id) ON DELETE CASCADE,
  season_id UUID NOT NULL REFERENCES public.series_seasons(id) ON DELETE CASCADE,
  episode_number INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  thumbnail_url TEXT,
  video_url TEXT NOT NULL,
  duration_seconds INTEGER,
  is_free BOOLEAN NOT NULL DEFAULT false,
  views_count INTEGER NOT NULL DEFAULT 0,
  release_date DATE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  CONSTRAINT series_episodes_season_id_episode_number_key UNIQUE (
    season_id,
    episode_number
  ),
  CONSTRAINT series_episodes_episode_number_positive CHECK (episode_number > 0),
  CONSTRAINT series_episodes_duration_positive CHECK (
    duration_seconds IS NULL OR duration_seconds > 0
  )
);

CREATE TABLE IF NOT EXISTS public.series_watch_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  series_id UUID NOT NULL REFERENCES public.series(id) ON DELETE CASCADE,
  season_id UUID NOT NULL REFERENCES public.series_seasons(id) ON DELETE CASCADE,
  episode_id UUID NOT NULL REFERENCES public.series_episodes(id) ON DELETE CASCADE,
  position_seconds INTEGER NOT NULL DEFAULT 0,
  is_completed BOOLEAN NOT NULL DEFAULT false,
  last_watched_at TIMESTAMP NOT NULL DEFAULT NOW(),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  CONSTRAINT series_watch_progress_position_non_negative CHECK (
    position_seconds >= 0
  ),
  CONSTRAINT series_watch_progress_user_episode_key UNIQUE (user_id, episode_id)
);

CREATE INDEX IF NOT EXISTS series_created_at_idx
  ON public.series (created_at DESC);

CREATE INDEX IF NOT EXISTS series_category_idx
  ON public.series (category);

CREATE INDEX IF NOT EXISTS series_is_featured_idx
  ON public.series (is_featured, created_at DESC);

CREATE INDEX IF NOT EXISTS series_seasons_series_id_idx
  ON public.series_seasons (series_id, season_number);

CREATE INDEX IF NOT EXISTS series_episodes_series_id_idx
  ON public.series_episodes (series_id);

CREATE INDEX IF NOT EXISTS series_episodes_season_id_idx
  ON public.series_episodes (season_id, episode_number);

CREATE INDEX IF NOT EXISTS series_watch_progress_user_id_idx
  ON public.series_watch_progress (user_id, last_watched_at DESC);

CREATE INDEX IF NOT EXISTS series_watch_progress_series_id_idx
  ON public.series_watch_progress (series_id, user_id);

ALTER TABLE public.series ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.series_seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.series_episodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.series_watch_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view series" ON public.series;
CREATE POLICY "Anyone can view series"
  ON public.series FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Anyone can view series seasons" ON public.series_seasons;
CREATE POLICY "Anyone can view series seasons"
  ON public.series_seasons FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Anyone can view series episodes" ON public.series_episodes;
CREATE POLICY "Anyone can view series episodes"
  ON public.series_episodes FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Users can view their own series progress" ON public.series_watch_progress;
CREATE POLICY "Users can view their own series progress"
  ON public.series_watch_progress FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own series progress" ON public.series_watch_progress;
CREATE POLICY "Users can insert their own series progress"
  ON public.series_watch_progress FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own series progress" ON public.series_watch_progress;
CREATE POLICY "Users can update their own series progress"
  ON public.series_watch_progress FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own series progress" ON public.series_watch_progress;
CREATE POLICY "Users can delete their own series progress"
  ON public.series_watch_progress FOR DELETE
  USING (auth.uid() = user_id);