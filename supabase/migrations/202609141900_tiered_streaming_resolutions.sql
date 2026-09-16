-- Migration: Tiered Maximum Streaming Resolutions (Free vs Premium)
-- Adds configurable quality caps for free-tier and premium-tier viewers.

INSERT INTO public.app_settings (key, value, description, is_secret) VALUES
  ('free_tier_max_quality',    '720p HD',        'Maximum streaming resolution cap for free-tier viewers', false),
  ('premium_tier_max_quality', '1080p Full HD',  'Maximum streaming resolution unlocked for VIP subscribers', false)
ON CONFLICT (key) DO UPDATE
SET description = EXCLUDED.description,
    is_secret = false;

-- Ensure both keys are explicitly non-secret so public viewers can read them
UPDATE public.app_settings
SET is_secret = false
WHERE key IN ('free_tier_max_quality', 'premium_tier_max_quality');
