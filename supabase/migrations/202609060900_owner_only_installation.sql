-- Apply after 202609010900_security_hardening.sql. Does not reset setup state.
BEGIN;

CREATE TABLE IF NOT EXISTS public.installation_owner (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE RESTRICT
);
ALTER TABLE public.installation_owner ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.installation_owner FROM PUBLIC, anon, authenticated;

-- Never let any signed-in visitor claim the initial admin role.
DO $block$
BEGIN
  IF to_regprocedure('public.promote_first_admin()') IS NOT NULL THEN
    REVOKE ALL ON FUNCTION public.promote_first_admin() FROM PUBLIC, anon, authenticated;
  END IF;
END;
$block$;

CREATE OR REPLACE FUNCTION public.is_installation_owner()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $fn$
  SELECT EXISTS (
    SELECT 1 FROM public.installation_owner o
    JOIN auth.users u ON u.id = o.user_id
    WHERE o.user_id = (SELECT auth.uid()) AND u.email_confirmed_at IS NOT NULL
  );
$fn$;
REVOKE ALL ON FUNCTION public.is_installation_owner() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_installation_owner() TO authenticated;

-- Explicit reads for the one public installation status row.
-- Keep the admin predicate out of anonymous SELECT evaluation.
DROP POLICY IF EXISTS "Admins manage app settings" ON public.app_settings;
CREATE POLICY "Admins manage app settings" ON public.app_settings FOR ALL
  TO authenticated USING (public.is_current_user_admin())
  WITH CHECK (public.is_current_user_admin());
GRANT SELECT ON public.app_settings TO anon, authenticated;
REVOKE TRUNCATE ON public.app_settings FROM anon, authenticated;
DROP POLICY IF EXISTS "Read installation status" ON public.app_settings;
CREATE POLICY "Read installation status" ON public.app_settings
  FOR SELECT TO anon, authenticated USING (key = 'setup_completed');

-- Restrictive policies also constrain the existing broad admin ALL policy.
DROP POLICY IF EXISTS "Protect installation update" ON public.app_settings;
CREATE POLICY "Protect installation update" ON public.app_settings
  AS RESTRICTIVE FOR UPDATE TO anon, authenticated
  USING (key <> 'setup_completed') WITH CHECK (key <> 'setup_completed');
DROP POLICY IF EXISTS "Protect installation insert" ON public.app_settings;
CREATE POLICY "Protect installation insert" ON public.app_settings
  AS RESTRICTIVE FOR INSERT TO anon, authenticated
  WITH CHECK (key <> 'setup_completed');
DROP POLICY IF EXISTS "Protect installation delete" ON public.app_settings;
CREATE POLICY "Protect installation delete" ON public.app_settings
  AS RESTRICTIVE FOR DELETE TO anon, authenticated USING (key <> 'setup_completed');

CREATE OR REPLACE FUNCTION public.complete_installation(platform_name text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $fn$
DECLARE
  current_status text;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_installation_owner() THEN
    RAISE EXCEPTION 'Installation owner access required' USING ERRCODE = '42501';
  END IF;
  IF platform_name IS NULL OR length(btrim(platform_name)) NOT BETWEEN 1 AND 80 THEN
    RAISE EXCEPTION 'Platform name must contain 1 to 80 characters';
  END IF;
  SELECT value INTO current_status FROM public.app_settings
    WHERE key = 'setup_completed' FOR UPDATE;
  IF NOT FOUND OR current_status NOT IN ('true', 'false') THEN
    RAISE EXCEPTION 'Installation status is missing or invalid';
  END IF;
  IF current_status = 'true' THEN RETURN; END IF; -- safe retry; never reset
  IF NOT EXISTS (
    SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Owner administrator profile is missing';
  END IF;
  INSERT INTO public.app_settings(key, value, is_secret, updated_by, updated_at)
    VALUES ('app_name', btrim(platform_name), false, auth.uid(), now())
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value,
      updated_by = EXCLUDED.updated_by, updated_at = EXCLUDED.updated_at;
  UPDATE public.app_settings SET value = 'true', is_secret = false,
    updated_by = auth.uid(), updated_at = now() WHERE key = 'setup_completed';
END;
$fn$;
REVOKE ALL ON FUNCTION public.complete_installation(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_installation(text) TO authenticated;
COMMIT;
