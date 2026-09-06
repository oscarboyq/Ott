-- Run in Supabase SQL Editor AFTER migrations and creating your confirmed
-- account in Authentication > Users. Replace ONLY the UUID below.
-- This operation is deliberately unavailable through the browser/Data API.
BEGIN;
DO $owner$
DECLARE
  chosen_id uuid := 'REPLACE_WITH_YOUR_AUTH_USER_UUID';
  existing_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users
    WHERE id = chosen_id AND email_confirmed_at IS NOT NULL) THEN
    RAISE EXCEPTION 'Create and confirm the owner account first';
  END IF;
  LOCK TABLE public.installation_owner IN EXCLUSIVE MODE;
  SELECT user_id INTO existing_id FROM public.installation_owner WHERE singleton;
  IF existing_id IS NOT NULL AND existing_id <> chosen_id THEN
    RAISE EXCEPTION 'A different owner is already designated';
  END IF;
  INSERT INTO public.installation_owner(singleton,user_id) VALUES(true,chosen_id)
    ON CONFLICT(singleton) DO NOTHING;
  INSERT INTO public.user_profiles(id,is_admin) VALUES(chosen_id,true)
    ON CONFLICT(id) DO UPDATE SET is_admin = true;
END;
$owner$;
COMMIT;
