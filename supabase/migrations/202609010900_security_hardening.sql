-- Harden profile authorization and admin role management.
-- Apply this migration to projects that were initialized with
-- assets/complete_database_setup.sql.

CREATE OR REPLACE FUNCTION public.is_current_user_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $fn$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_profiles
    WHERE id = (SELECT auth.uid())
      AND is_admin = true
  );
$fn$;

REVOKE ALL ON FUNCTION public.is_current_user_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_current_user_admin() TO authenticated;

-- Profiles are private to their owner. Admins can list profiles for user
-- management, but signed-out visitors cannot read birth dates/preferences.
DROP POLICY IF EXISTS "Anyone can view public profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.user_profiles;

CREATE POLICY "Users can view their own profile"
ON public.user_profiles
FOR SELECT
TO authenticated
USING ((SELECT auth.uid()) = id);

CREATE POLICY "Admins can view all profiles"
ON public.user_profiles
FOR SELECT
TO authenticated
USING ((SELECT public.is_current_user_admin()));

CREATE POLICY "Users can update their own profile"
ON public.user_profiles
FOR UPDATE
TO authenticated
USING ((SELECT auth.uid()) = id)
WITH CHECK ((SELECT auth.uid()) = id);

-- RLS limits rows; column grants prevent a user from changing authorization
-- fields such as is_admin or subscription_tier on their own row.
REVOKE ALL ON TABLE public.user_profiles FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON TABLE public.user_profiles FROM authenticated;
GRANT SELECT ON TABLE public.user_profiles TO authenticated;
GRANT UPDATE (username, full_name, avatar_url, bio, birth_date, preferences)
ON TABLE public.user_profiles TO authenticated;

-- Admin role changes go through a narrow SECURITY DEFINER function instead of
-- granting every authenticated client UPDATE access to is_admin.
CREATE OR REPLACE FUNCTION public.admin_set_user_admin(
  target_user_id UUID,
  make_admin BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  affected_rows INTEGER;
BEGIN
  IF (SELECT auth.uid()) IS NULL OR NOT public.is_current_user_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  IF make_admin = false
     AND EXISTS (
       SELECT 1
       FROM public.user_profiles
       WHERE id = target_user_id AND is_admin = true
     )
     AND (SELECT COUNT(*) FROM public.user_profiles WHERE is_admin = true) <= 1
  THEN
    RAISE EXCEPTION 'Cannot remove the last admin';
  END IF;

  UPDATE public.user_profiles
  SET is_admin = make_admin,
      updated_at = NOW()
  WHERE id = target_user_id;

  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  IF affected_rows = 0 THEN
    RAISE EXCEPTION 'User profile not found';
  END IF;
END;
$fn$;

REVOKE ALL ON FUNCTION public.admin_set_user_admin(UUID, BOOLEAN)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_user_admin(UUID, BOOLEAN)
TO authenticated;

-- The initial client-side bootstrap function must not remain callable after
-- setup. Existing installations already have an admin, so close it now.
DO $block$
BEGIN
  IF to_regprocedure('public.promote_first_admin()') IS NOT NULL THEN
    EXECUTE
      'REVOKE ALL ON FUNCTION public.promote_first_admin() FROM PUBLIC, anon, authenticated';
  END IF;
END;
$block$;
