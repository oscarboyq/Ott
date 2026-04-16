-- ============================================================
-- OTT Platform Database Schema for Supabase PostgreSQL
-- ============================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. VIDEOS TABLE (Main Content)
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

-- ============================================================
-- 2. SUBSCRIPTION PLANS TABLE
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

-- ============================================================
-- 3. USER SUBSCRIPTIONS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS user_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES subscription_plans ON DELETE RESTRICT,
    started_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT true,
    stripe_subscription_id TEXT,
    auto_renew BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, plan_id)
);

-- ============================================================
-- 4. WATCHLIST TABLE (User's saved videos)
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

-- ============================================================
-- 5. USER PROFILES TABLE (Extended user info)
-- ============================================================
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
    username TEXT UNIQUE,
    full_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    birth_date DATE,
    subscription_tier TEXT DEFAULT 'free', -- free, premium, vip
    is_admin BOOLEAN DEFAULT false,
    preferences JSONB DEFAULT '{"language": "en", "notifications": true}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 6. WATCH HISTORY TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS watch_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
    video_id UUID NOT NULL REFERENCES videos ON DELETE CASCADE,
    watched_at TIMESTAMP DEFAULT NOW(),
    duration_watched_seconds INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 7. RATINGS & REVIEWS TABLE
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

-- ============================================================
-- 8. TRANSACTIONS TABLE (For payment tracking)
-- ============================================================
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
    subscription_id UUID REFERENCES user_subscriptions ON DELETE SET NULL,
    amount DECIMAL(10, 2) NOT NULL,
    currency TEXT DEFAULT 'USD',
    status TEXT DEFAULT 'pending', -- pending, completed, failed
    stripe_transaction_id TEXT UNIQUE,
    payment_method TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    CONSTRAINT amount_positive CHECK (amount > 0)
);

-- ============================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_videos_category ON videos(category);
CREATE INDEX IF NOT EXISTS idx_videos_is_free ON videos(is_free);
CREATE INDEX IF NOT EXISTS idx_videos_created_at ON videos(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_watchlist_user_id ON watchlist(user_id);
CREATE INDEX IF NOT EXISTS idx_watchlist_video_id ON watchlist(video_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id ON user_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_active ON user_subscriptions(user_id) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_watch_history_user_id ON watch_history(user_id, watched_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id, created_at DESC);

-- ============================================================
-- SAMPLE DATA (Optional - for testing)
-- ============================================================
-- Insert subscription plans
INSERT INTO subscription_plans (name, monthly_price, annual_price, features) VALUES
    ('Free', 0, 0, '{"key_features": ["Free videos only", "Standard streaming", "1 device access"]}'),
    ('Premium', 10, 0, '{"key_features": ["All videos unlocked", "HD quality streaming", "1 device access"]}'),
    ('VIP', 0, 0, '{"key_features": ["Coming soon", "Higher quality tiers", "More device support"]}')
ON CONFLICT DO NOTHING;

-- ============================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE watchlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE watch_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE video_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- USER PROFILES: Users can see their own profile + public profiles
CREATE POLICY "Users can view their own profile"
    ON user_profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Anyone can view public profiles"
    ON user_profiles FOR SELECT
    USING (true);

CREATE POLICY "Users can update their own profile"
    ON user_profiles FOR UPDATE
    USING (auth.uid() = id);

-- WATCHLIST: Users can only see/manage their own watchlist
CREATE POLICY "Users can view their own watchlist"
    ON watchlist FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can add to their watchlist"
    ON watchlist FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their watchlist"
    ON watchlist FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete from their watchlist"
    ON watchlist FOR DELETE
    USING (auth.uid() = user_id);

-- USER SUBSCRIPTIONS: Users can view their own subscriptions
CREATE POLICY "Users can view their own subscriptions"
    ON user_subscriptions FOR SELECT
    USING (auth.uid() = user_id);

-- WATCH HISTORY: Users can only see their own history
CREATE POLICY "Users can view their own watch history"
    ON watch_history FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can add to their watch history"
    ON watch_history FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- VIDEO RATINGS: Users can see/manage their own ratings
CREATE POLICY "Users can view ratings"
    ON video_ratings FOR SELECT
    USING (true);

CREATE POLICY "Users can rate videos"
    ON video_ratings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own ratings"
    ON video_ratings FOR UPDATE
    USING (auth.uid() = user_id);

-- VIDEOS: Public read access
ALTER TABLE videos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view videos"
    ON videos FOR SELECT
    USING (true);

-- TRANSACTIONS: Users can view their own transactions
CREATE POLICY "Users can view their own transactions"
    ON transactions FOR SELECT
    USING (auth.uid() = user_id);

-- ============================================================
-- STORED PROCEDURE FOR AUTO-UPDATE TIMESTAMPS
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables with updated_at
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
-- TESTS: Verify schema creation
-- ============================================================
-- SELECT * FROM information_schema.tables WHERE table_schema = 'public';
-- SELECT * FROM subscription_plans;
