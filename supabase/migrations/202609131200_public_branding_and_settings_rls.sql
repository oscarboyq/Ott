-- Migration: Public Branding & Runtime Settings Access
-- Allows public (anon and authenticated) client viewers to fetch platform branding,
-- logos, taglines, legal policies, and runtime toggles while keeping API keys secret.

-- 1. Ensure all platform setting keys exist with safe defaults
INSERT INTO public.app_settings (key, value, description, is_secret) VALUES
  ('bunny_cdn_api_key',        '', 'Bunny.net Stream API Key',              true),
  ('bunny_cdn_library_id',     '', 'Bunny.net Stream Library ID',           false),
  ('bunny_cdn_pull_zone',      '', 'Bunny.net CDN Pull Zone hostname',      false),
  ('nowpayments_api_key',      '', 'NOWPayments API Key',                   true),
  ('nowpayments_ipn_secret',   '', 'NOWPayments IPN Webhook Secret',        true),
  ('nowpayments_pay_currency', 'usdtbsc', 'Default crypto pay currency',    false),
  ('app_name',                 'ReelHouse', 'Display name of the platform', false),
  ('app_tagline',              'Curated movies, series, and premium originals in one OTT home', 'Brand tagline / slogan', false),
  ('app_logo_url',             '', 'Website Header Navigation Bar Logo URL', false),
  ('app_favicon_url',          '', 'Browser Tab Favicon URL',               false),
  ('support_email',            '', 'Customer Care & Support Email',        false),
  ('terms_url',                '', 'Terms of Service URL',                  false),
  ('privacy_url',              '', 'Privacy Policy URL',                    false),
  ('copyright_text',           '© 2026 ReelHouse. All rights reserved.', 'Platform copyright statement', false),
  ('default_stream_quality',   'Auto', 'Default streaming quality profile', false),
  ('buffer_profile',           'Standard (Balanced)', 'Default video buffer & pre-roll strategy', false),
  ('autoplay_next_episode',    'true', 'Autoplay next episode in series',   false),
  ('autoplay_hero_trailers',   'true', 'Autoplay featured hero trailers',   false),
  ('enable_reels',             'true', 'Enable short-form reels feed',      false),
  ('enable_reviews',           'true', 'Enable audience reviews & ratings', false),
  ('platform_notice',          '', 'Global announcement notice banner',     false),
  ('setup_completed',          'false', 'Has initial setup been done',      false)
ON CONFLICT (key) DO UPDATE
SET is_secret = EXCLUDED.is_secret
WHERE public.app_settings.is_secret IS DISTINCT FROM EXCLUDED.is_secret;

-- 2. Ensure non-secret keys are explicitly marked as is_secret = false
UPDATE public.app_settings
SET is_secret = false
WHERE key IN (
  'app_name',
  'app_tagline',
  'app_logo_url',
  'app_favicon_url',
  'support_email',
  'terms_url',
  'privacy_url',
  'copyright_text',
  'default_stream_quality',
  'buffer_profile',
  'autoplay_next_episode',
  'autoplay_hero_trailers',
  'enable_reels',
  'enable_reviews',
  'platform_notice',
  'setup_completed'
);

-- 3. Explicitly mark private API keys as is_secret = true
UPDATE public.app_settings
SET is_secret = true
WHERE key IN (
  'bunny_cdn_api_key',
  'nowpayments_api_key',
  'nowpayments_ipn_secret'
);

-- 4. Recreate public SELECT policy so client viewers can read all non-secret settings
GRANT SELECT ON public.app_settings TO anon, authenticated;

DROP POLICY IF EXISTS "Anyone can read non-secret settings" ON public.app_settings;
DROP POLICY IF EXISTS "Read public app settings" ON public.app_settings;
CREATE POLICY "Read public app settings" ON public.app_settings
  FOR SELECT TO anon, authenticated
  USING (is_secret = false OR is_secret IS NULL);

-- 5. Add missing watch_history UPDATE and DELETE RLS policies
DROP POLICY IF EXISTS "Users can update their watch history" ON public.watch_history;
CREATE POLICY "Users can update their watch history"
  ON public.watch_history FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete from their watch history" ON public.watch_history;
CREATE POLICY "Users can delete from their watch history"
  ON public.watch_history FOR DELETE
  USING (auth.uid() = user_id);
