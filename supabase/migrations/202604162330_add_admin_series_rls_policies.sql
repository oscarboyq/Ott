CREATE OR REPLACE FUNCTION public.is_current_user_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_profiles
    WHERE id = auth.uid()
      AND is_admin = true
  );
$$;

DROP POLICY IF EXISTS "Admins manage series" ON public.series;
CREATE POLICY "Admins manage series"
  ON public.series
  FOR ALL
  USING (public.is_current_user_admin())
  WITH CHECK (public.is_current_user_admin());

DROP POLICY IF EXISTS "Admins manage series seasons" ON public.series_seasons;
CREATE POLICY "Admins manage series seasons"
  ON public.series_seasons
  FOR ALL
  USING (public.is_current_user_admin())
  WITH CHECK (public.is_current_user_admin());

DROP POLICY IF EXISTS "Admins manage series episodes" ON public.series_episodes;
CREATE POLICY "Admins manage series episodes"
  ON public.series_episodes
  FOR ALL
  USING (public.is_current_user_admin())
  WITH CHECK (public.is_current_user_admin());