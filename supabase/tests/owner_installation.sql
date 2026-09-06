-- Run only in an isolated empty PostgreSQL database. Supplies Supabase shims.
\set ON_ERROR_STOP on
DO $$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF;
END $$;
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY, email_confirmed_at timestamptz);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
GRANT USAGE ON SCHEMA public, auth TO anon, authenticated;
CREATE TABLE public.user_profiles(id uuid PRIMARY KEY, is_admin boolean);
CREATE TABLE public.app_settings(key text PRIMARY KEY, value text NOT NULL,
 is_secret boolean DEFAULT false, updated_by uuid, updated_at timestamptz);
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.app_settings TO anon, authenticated;
CREATE FUNCTION public.is_current_user_admin() RETURNS boolean LANGUAGE sql
 SECURITY DEFINER SET search_path = '' AS $$
 SELECT EXISTS(SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND is_admin);
$$;
REVOKE ALL ON FUNCTION public.is_current_user_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_current_user_admin() TO authenticated;
CREATE POLICY "Admins manage app settings" ON public.app_settings FOR ALL
 USING (public.is_current_user_admin()) WITH CHECK (public.is_current_user_admin());
CREATE FUNCTION public.promote_first_admin() RETURNS void LANGUAGE sql AS $$ SELECT; $$;
INSERT INTO auth.users VALUES
 ('00000000-0000-0000-0000-000000000001',now()),
 ('00000000-0000-0000-0000-000000000002',now());
INSERT INTO public.user_profiles VALUES
 ('00000000-0000-0000-0000-000000000001',true),
 ('00000000-0000-0000-0000-000000000002',true);
INSERT INTO public.app_settings(key,value) VALUES ('setup_completed','false');
\ir ../migrations/202609060900_owner_only_installation.sql
INSERT INTO public.installation_owner VALUES(true,'00000000-0000-0000-0000-000000000001');

SET ROLE anon;
DO $$ BEGIN
 IF (SELECT value FROM public.app_settings WHERE key='setup_completed') <> 'false' THEN
   RAISE EXCEPTION 'Anonymous status read failed'; END IF;
 BEGIN PERFORM public.complete_installation('Attack'); RAISE EXCEPTION 'Anon completed setup';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
DO $$ BEGIN
 IF public.is_installation_owner() THEN RAISE EXCEPTION 'Nonowner recognized as owner'; END IF;
 BEGIN PERFORM public.promote_first_admin(); RAISE EXCEPTION 'Promotion still callable';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.complete_installation('Attack'); RAISE EXCEPTION 'Nonowner completed setup';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE public.app_settings SET value='true' WHERE key='setup_completed';
 IF FOUND THEN RAISE EXCEPTION 'Direct update bypassed protection'; END IF;
 DELETE FROM public.app_settings WHERE key='setup_completed';
 IF FOUND THEN RAISE EXCEPTION 'Direct delete bypassed protection'; END IF;
 BEGIN INSERT INTO public.installation_owner VALUES(false,auth.uid());
 RAISE EXCEPTION 'Owner assignment exposed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
RESET ROLE;
UPDATE auth.users SET email_confirmed_at = NULL WHERE id='00000000-0000-0000-0000-000000000001';
SET ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.complete_installation('Unconfirmed'); RAISE EXCEPTION 'Unconfirmed owner completed setup';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
UPDATE auth.users SET email_confirmed_at = now() WHERE id='00000000-0000-0000-0000-000000000001';
SET ROLE authenticated;
SELECT public.complete_installation('My ReelHouse');
SELECT public.complete_installation('Retry must not overwrite');
DO $$ BEGIN
 IF (SELECT value FROM public.app_settings WHERE key='setup_completed') <> 'true' THEN
 RAISE EXCEPTION 'Owner completion failed'; END IF;
 IF (SELECT value FROM public.app_settings WHERE key='app_name') <> 'My ReelHouse' THEN
 RAISE EXCEPTION 'Retry overwrote platform name'; END IF;
 UPDATE public.app_settings SET value='false' WHERE key='setup_completed';
 IF FOUND THEN RAISE EXCEPTION 'Owner could reset setup via direct API'; END IF;
END $$;
RESET ROLE;
-- Migration reruns preserve completed installations.
\ir ../migrations/202609060900_owner_only_installation.sql
DO $$ BEGIN
 IF (SELECT value FROM public.app_settings WHERE key='setup_completed') <> 'true' THEN
 RAISE EXCEPTION 'Migration reset setup'; END IF;
END $$;
