-- Migration: Fix is_current_user_admin execution permissions and content RLS policies
-- Resolves: 42501 "permission denied for function is_current_user_admin" which blocked public and visitor catalog queries.

-- 1. Replace is_current_user_admin with safe NULL check and SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.is_current_user_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  _is_admin BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  SELECT is_admin INTO _is_admin
  FROM public.user_profiles
  WHERE id = auth.uid();

  RETURN COALESCE(_is_admin, false);
END;
$$;

-- 2. Grant EXECUTE to anon and authenticated (it safely returns false for non-admins and anonymous visitors)
GRANT EXECUTE ON FUNCTION public.is_current_user_admin() TO anon, authenticated;

-- 3. Ensure videos RLS allows public viewing and restricts admin writes to authenticated users
ALTER TABLE public.videos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view videos" ON public.videos;
CREATE POLICY "Anyone can view videos"
  ON public.videos
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Admins manage videos" ON public.videos;
CREATE POLICY "Admins manage videos"
  ON public.videos
  FOR ALL
  TO authenticated
  USING (public.is_current_user_admin())
  WITH CHECK (public.is_current_user_admin());

-- 4. Ensure series RLS allows public viewing and restricts admin writes to authenticated users
ALTER TABLE public.series ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.series_seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.series_episodes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view series" ON public.series;
CREATE POLICY "Anyone can view series"
  ON public.series
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Admins manage series" ON public.series;
CREATE POLICY "Admins manage series"
  ON public.series
  FOR ALL
  TO authenticated
  USING (public.is_current_user_admin())
  WITH CHECK (public.is_current_user_admin());

DROP POLICY IF EXISTS "Anyone can view series seasons" ON public.series_seasons;
CREATE POLICY "Anyone can view series seasons"
  ON public.series_seasons
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Admins manage series seasons" ON public.series_seasons;
CREATE POLICY "Admins manage series seasons"
  ON public.series_seasons
  FOR ALL
  TO authenticated
  USING (public.is_current_user_admin())
  WITH CHECK (public.is_current_user_admin());

DROP POLICY IF EXISTS "Anyone can view series episodes" ON public.series_episodes;
CREATE POLICY "Anyone can view series episodes"
  ON public.series_episodes
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Admins manage series episodes" ON public.series_episodes;
CREATE POLICY "Admins manage series episodes"
  ON public.series_episodes
  FOR ALL
  TO authenticated
  USING (public.is_current_user_admin())
  WITH CHECK (public.is_current_user_admin());

-- 5. Prevent infinite recursion on user_profiles
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.user_profiles;
CREATE POLICY "Admins can view all profiles"
  ON public.user_profiles
  FOR SELECT
  TO authenticated
  USING (
    (auth.uid() != id) AND public.is_current_user_admin()
  );
