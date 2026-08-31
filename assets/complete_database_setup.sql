-- ============================================================
-- ReelHouse – Complete Database Setup (One-Click)
-- ============================================================
-- Copy this ENTIRE file and paste it into the Supabase SQL Editor.
-- Go to: Supabase Dashboard → SQL Editor → New Query → Paste → Run
-- ============================================================

-- ── Extensions ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── Helper: auto-update timestamps ─────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $fn$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;

-- ============================================================
-- 1. VIDEOS
-- ============================================================
CREATE TABLE IF NOT EXISTS videos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    thumbnail_url TEXT,
    video_url TEXT NOT NULL,
    duration_seconds INTEGER,
    category TEXT,
    rating FLOAT DEFAULT 0,
    rating_count INTEGER DEFAULT 0,
    is_free BOOLEAN DEFAULT false,
    is_reel BOOLEAN DEFAULT false,
    is_featured BOOLEAN DEFAULT false,
    views_count INTEGER DEFAULT 0,
    tagline TEXT,
    release_date DATE,
    accent_hex TEXT DEFAULT '#FF5722',
    created_by UUID REFERENCES auth.users ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT duration_positive CHECK (duration_seconds > 0)
);

CREATE INDEX IF NOT EXISTS idx_videos_category ON videos(category);
CREATE INDEX IF NOT EXISTS idx_videos_is_free ON videos(is_free);
CREATE INDEX IF NOT EXISTS idx_videos_created_at ON videos(created_at DESC);
CREATE INDEX IF NOT EXISTS videos_is_reel_created_at_idx ON videos(is_reel, created_at DESC);

ALTER TABLE videos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view videos" ON videos FOR SELECT USING (true);

-- ============================================================
-- 2. SUBSCRIPTION PLANS
-- ============================================================
CREATE TABLE IF NOT EXISTS subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    monthly_price DECIMAL(10, 2) NOT NULL,
    annual_price DECIMAL(10, 2),
    features JSONB DEFAULT '{"key_features": []}',
    is_active BOOLEAN DEFAULT true,
    stripe_price_id TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT price_positive CHECK (monthly_price >= 0)
);

ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view subscription plans"
  ON subscription_plans FOR SELECT USING (true);

INSERT INTO subscription_plans (name, monthly_price, annual_price, features, is_active) VALUES
    ('Free',    0,  0, '{"key_features": ["Free videos only", "Standard streaming", "1 device access"]}',  true),
    ('Premium', 10, 0, '{"key_features": ["All videos unlocked", "HD quality streaming", "1 device access"]}', true),
    ('VIP',     0,  0, '{"key_features": ["Coming soon", "Higher quality tiers", "More device support"]}', false)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 3. USER SUBSCRIPTIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS user_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES subscription_plans ON DELETE RESTRICT,
    started_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT true,
    payment_provider TEXT,
    external_payment_id TEXT,
    plan_name_snapshot TEXT,
    plan_description_snapshot TEXT,
    price_amount_snapshot DECIMAL(10, 2),
    price_currency_snapshot TEXT,
    billing_period_snapshot TEXT,
    stripe_subscription_id TEXT,
    auto_renew BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, plan_id)
);

CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id ON user_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_active ON user_subscriptions(user_id) WHERE is_active = true;

ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own subscriptions"
  ON user_subscriptions FOR SELECT USING (auth.uid() = user_id);

-- ============================================================
-- 4. WATCHLIST
-- ============================================================
CREATE TABLE IF NOT EXISTS watchlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
    video_id UUID NOT NULL REFERENCES videos ON DELETE CASCADE,
    position_seconds INTEGER DEFAULT 0,
    percentage_watched FLOAT DEFAULT 0,
    is_completed BOOLEAN DEFAULT false,
    added_at TIMESTAMP DEFAULT NOW(),
    last_watched_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, video_id)
);

CREATE INDEX IF NOT EXISTS idx_watchlist_user_id ON watchlist(user_id);
CREATE INDEX IF NOT EXISTS idx_watchlist_video_id ON watchlist(video_id);

ALTER TABLE watchlist ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own watchlist" ON watchlist FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can add to their watchlist" ON watchlist FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their watchlist" ON watchlist FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete from their watchlist" ON watchlist FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 5. USER PROFILES
-- ============================================================
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
    username TEXT UNIQUE,
    full_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    birth_date DATE,
    subscription_tier TEXT DEFAULT 'free',
    is_admin BOOLEAN DEFAULT false,
    preferences JSONB DEFAULT '{"language": "en", "notifications": true}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own profile" ON user_profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Anyone can view public profiles" ON user_profiles FOR SELECT USING (true);
CREATE POLICY "Users can update their own profile" ON user_profiles FOR UPDATE USING (auth.uid() = id);

-- ============================================================
-- 6. WATCH HISTORY
-- ============================================================
CREATE TABLE IF NOT EXISTS watch_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
    video_id UUID NOT NULL REFERENCES videos ON DELETE CASCADE,
    watched_at TIMESTAMP DEFAULT NOW(),
    duration_watched_seconds INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, video_id)
);

CREATE INDEX IF NOT EXISTS idx_watch_history_user_id ON watch_history(user_id, watched_at DESC);
CREATE INDEX IF NOT EXISTS idx_watch_history_user_video ON watch_history(user_id, video_id);

ALTER TABLE watch_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own watch history" ON watch_history FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can add to their watch history" ON watch_history FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their watch history" ON watch_history FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete from their watch history" ON watch_history FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 7. VIDEO RATINGS (10-point scale)
-- ============================================================
CREATE TABLE IF NOT EXISTS video_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
    video_id UUID NOT NULL REFERENCES videos ON DELETE CASCADE,
    rating INTEGER CHECK (rating >= 1 AND rating <= 10),
    review_text TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, video_id)
);

ALTER TABLE video_ratings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view ratings" ON video_ratings FOR SELECT USING (true);
CREATE POLICY "Authenticated users can rate once" ON video_ratings FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Rating auto-sync to videos table
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
$fn$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sync_video_rating_stats ON video_ratings;
CREATE TRIGGER sync_video_rating_stats
  AFTER INSERT OR UPDATE OR DELETE ON video_ratings
  FOR EACH ROW EXECUTE FUNCTION sync_video_rating_stats_trigger();

-- ============================================================
-- 8. TRANSACTIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
    subscription_id UUID REFERENCES user_subscriptions ON DELETE SET NULL,
    amount DECIMAL(10, 2) NOT NULL,
    currency TEXT DEFAULT 'USD',
    status TEXT DEFAULT 'pending',
    stripe_transaction_id TEXT UNIQUE,
    payment_method TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    CONSTRAINT amount_positive CHECK (amount > 0)
);

CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id, created_at DESC);
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own transactions" ON transactions FOR SELECT USING (auth.uid() = user_id);

-- ============================================================
-- 9. PAYMENTS (NOWPayments crypto checkout)
-- ============================================================
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES subscription_plans ON DELETE RESTRICT,
    provider TEXT NOT NULL DEFAULT 'nowpayments',
    order_id TEXT NOT NULL UNIQUE,
    provider_payment_id TEXT UNIQUE,
    payment_status TEXT NOT NULL DEFAULT 'creating',
    price_amount NUMERIC(10, 2) NOT NULL,
    price_currency TEXT NOT NULL DEFAULT 'usd',
    pay_currency TEXT,
    pay_amount NUMERIC(20, 8),
    pay_address TEXT,
    payin_extra_id TEXT,
    order_description TEXT,
    purchase_id TEXT,
    outcome_amount NUMERIC(20, 8),
    outcome_currency TEXT,
    actually_paid NUMERIC(20, 8),
    actually_paid_at_fiat NUMERIC(20, 8),
    parent_payment_id TEXT,
    paid_at TIMESTAMPTZ,
    raw_response JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(payment_status);
CREATE INDEX IF NOT EXISTS idx_payments_provider_order ON payments(provider, order_id);

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own payments" ON payments FOR SELECT USING (auth.uid() = user_id);

DROP TRIGGER IF EXISTS update_payments_updated_at ON payments;
CREATE TRIGGER update_payments_updated_at
  BEFORE UPDATE ON payments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 10. PAYMENT WEBHOOK EVENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS payment_webhook_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider TEXT NOT NULL,
    external_id TEXT,
    event_type TEXT,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_webhook_events_provider ON payment_webhook_events(provider, created_at DESC);
ALTER TABLE payment_webhook_events ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 11. TV SERIES HIERARCHY
-- ============================================================
CREATE TABLE IF NOT EXISTS series (
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

CREATE TABLE IF NOT EXISTS series_seasons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    series_id UUID NOT NULL REFERENCES series(id) ON DELETE CASCADE,
    season_number INTEGER NOT NULL,
    title TEXT,
    description TEXT,
    poster_url TEXT,
    release_date DATE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (series_id, season_number),
    CHECK (season_number > 0)
);

CREATE TABLE IF NOT EXISTS series_episodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    series_id UUID NOT NULL REFERENCES series(id) ON DELETE CASCADE,
    season_id UUID NOT NULL REFERENCES series_seasons(id) ON DELETE CASCADE,
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
    UNIQUE (season_id, episode_number),
    CHECK (episode_number > 0),
    CHECK (duration_seconds IS NULL OR duration_seconds > 0)
);

CREATE TABLE IF NOT EXISTS series_watch_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
    series_id UUID NOT NULL REFERENCES series(id) ON DELETE CASCADE,
    season_id UUID NOT NULL REFERENCES series_seasons(id) ON DELETE CASCADE,
    episode_id UUID NOT NULL REFERENCES series_episodes(id) ON DELETE CASCADE,
    position_seconds INTEGER NOT NULL DEFAULT 0,
    is_completed BOOLEAN NOT NULL DEFAULT false,
    last_watched_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CHECK (position_seconds >= 0),
    UNIQUE (user_id, episode_id)
);

CREATE INDEX IF NOT EXISTS series_created_at_idx ON series(created_at DESC);
CREATE INDEX IF NOT EXISTS series_category_idx ON series(category);
CREATE INDEX IF NOT EXISTS series_is_featured_idx ON series(is_featured, created_at DESC);
CREATE INDEX IF NOT EXISTS series_seasons_series_id_idx ON series_seasons(series_id, season_number);
CREATE INDEX IF NOT EXISTS series_episodes_series_id_idx ON series_episodes(series_id);
CREATE INDEX IF NOT EXISTS series_episodes_season_id_idx ON series_episodes(season_id, episode_number);
CREATE INDEX IF NOT EXISTS series_watch_progress_user_id_idx ON series_watch_progress(user_id, last_watched_at DESC);
CREATE INDEX IF NOT EXISTS series_watch_progress_series_id_idx ON series_watch_progress(series_id, user_id);

ALTER TABLE series ENABLE ROW LEVEL SECURITY;
ALTER TABLE series_seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE series_episodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE series_watch_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view series" ON series FOR SELECT USING (true);
CREATE POLICY "Anyone can view series seasons" ON series_seasons FOR SELECT USING (true);
CREATE POLICY "Anyone can view series episodes" ON series_episodes FOR SELECT USING (true);
CREATE POLICY "Users can view their own series progress" ON series_watch_progress FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own series progress" ON series_watch_progress FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own series progress" ON series_watch_progress FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own series progress" ON series_watch_progress FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 12. APP SETTINGS (Runtime config managed by Super Admin)
-- ============================================================
CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL DEFAULT '',
    description TEXT,
    is_secret BOOLEAN DEFAULT false,
    updated_by UUID REFERENCES auth.users ON DELETE SET NULL,
    updated_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- Anyone can read non-secret settings; only admins manage settings
CREATE POLICY "Anyone can read non-secret settings"
  ON app_settings FOR SELECT
  USING (is_secret = false);

-- Seed the expected setting keys
INSERT INTO app_settings (key, value, description, is_secret) VALUES
    ('bunny_cdn_api_key',        '', 'Bunny.net Stream API Key',              true),
    ('bunny_cdn_library_id',     '', 'Bunny.net Stream Library ID',           false),
    ('bunny_cdn_pull_zone',      '', 'Bunny.net CDN Pull Zone hostname',      false),
    ('nowpayments_api_key',      '', 'NOWPayments API Key',                   true),
    ('nowpayments_ipn_secret',   '', 'NOWPayments IPN Webhook Secret',        true),
    ('nowpayments_pay_currency', 'usdtbsc', 'Default crypto pay currency',    false),
    ('app_name',                 'ReelHouse', 'Display name of the platform', false),
    ('setup_completed',          'false', 'Has initial setup been done',      false)
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- 13. ADMIN HELPER FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_current_user_admin()
RETURNS BOOLEAN
LANGUAGE sql STABLE AS $fn$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE id = auth.uid() AND is_admin = true
  );
$fn$;

-- Promote the calling user to admin. Only works when no admin exists yet.
CREATE OR REPLACE FUNCTION public.promote_first_admin()
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $fn$
BEGIN
  -- Only allow if there are no admins yet
  IF EXISTS (SELECT 1 FROM public.user_profiles WHERE is_admin = true) THEN
    RAISE EXCEPTION 'An admin already exists';
  END IF;
  -- Ensure the profile row exists (trigger may not have fired yet)
  INSERT INTO public.user_profiles (id)
  VALUES (auth.uid())
  ON CONFLICT (id) DO NOTHING;
  -- Promote
  UPDATE public.user_profiles SET is_admin = true WHERE id = auth.uid();
END;
$fn$;

-- ── Admin RLS policies for content management ───────────────
CREATE POLICY "Admins manage videos" ON videos FOR ALL
  USING (public.is_current_user_admin()) WITH CHECK (public.is_current_user_admin());
CREATE POLICY "Admins manage series" ON series FOR ALL
  USING (public.is_current_user_admin()) WITH CHECK (public.is_current_user_admin());
CREATE POLICY "Admins manage series seasons" ON series_seasons FOR ALL
  USING (public.is_current_user_admin()) WITH CHECK (public.is_current_user_admin());
CREATE POLICY "Admins manage series episodes" ON series_episodes FOR ALL
  USING (public.is_current_user_admin()) WITH CHECK (public.is_current_user_admin());
CREATE POLICY "Admins manage subscription plans" ON subscription_plans FOR ALL
  USING (public.is_current_user_admin()) WITH CHECK (public.is_current_user_admin());
CREATE POLICY "Admins manage app settings" ON app_settings FOR ALL
  USING (public.is_current_user_admin()) WITH CHECK (public.is_current_user_admin());

-- ── Storage bucket and policies for admin image uploads ─────
INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'thumbnails',
  'thumbnails',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE POLICY "Anyone can view thumbnails"
ON storage.objects
FOR SELECT
USING (bucket_id = 'thumbnails');

CREATE POLICY "Admins can upload thumbnails"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'thumbnails'
  AND (storage.foldername(name))[1] = 'admin'
  AND public.is_current_user_admin()
);

CREATE POLICY "Admins can update thumbnails"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'thumbnails'
  AND public.is_current_user_admin()
)
WITH CHECK (
  bucket_id = 'thumbnails'
  AND (storage.foldername(name))[1] = 'admin'
  AND public.is_current_user_admin()
);

CREATE POLICY "Admins can delete thumbnails"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'thumbnails'
  AND public.is_current_user_admin()
);

-- ============================================================
-- 14. AUTO-UPDATE TRIGGERS
-- ============================================================
CREATE TRIGGER update_videos_updated_at BEFORE UPDATE ON videos
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_subscription_plans_updated_at BEFORE UPDATE ON subscription_plans
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_subscriptions_updated_at BEFORE UPDATE ON user_subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_transactions_updated_at BEFORE UPDATE ON transactions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 15. AUTO-CREATE PROFILE ON SIGN-UP
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $fn$
BEGIN
  INSERT INTO public.user_profiles (id, username, full_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'username', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$fn$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- DONE! Your database is ready. Go back to the app and click
-- "Verify Connection" to continue setup.
-- ============================================================
