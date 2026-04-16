-- Normalize subscription plan labels and pricing to the current product lineup.

ALTER TABLE subscription_plans
  DROP CONSTRAINT IF EXISTS price_positive;

ALTER TABLE subscription_plans
  ADD CONSTRAINT price_positive CHECK (monthly_price >= 0);

WITH ranked_plans AS (
  SELECT
    id,
    monthly_price,
    ROW_NUMBER() OVER (ORDER BY monthly_price ASC, created_at ASC, id ASC) AS plan_rank
  FROM subscription_plans
)
UPDATE subscription_plans AS plans
SET
  name = CASE ranked.plan_rank
    WHEN 1 THEN 'Free'
    WHEN 2 THEN 'Premium'
    WHEN 3 THEN 'VIP'
    ELSE plans.name
  END,
  description = CASE ranked.plan_rank
    WHEN 1 THEN 'Completely free access to the open catalog.'
    WHEN 2 THEN 'Unlock every video in HD quality on one device.'
    WHEN 3 THEN 'Upcoming premium tier with more devices and extra benefits.'
    ELSE plans.description
  END,
  monthly_price = CASE ranked.plan_rank
    WHEN 1 THEN 0
    WHEN 2 THEN 10
    WHEN 3 THEN 0
    ELSE plans.monthly_price
  END,
  annual_price = CASE ranked.plan_rank
    WHEN 1 THEN 0
    WHEN 2 THEN 0
    WHEN 3 THEN 0
    ELSE plans.annual_price
  END,
  features = CASE ranked.plan_rank
    WHEN 1 THEN '{"key_features": ["Free videos only", "Standard streaming", "1 device access"]}'::jsonb
    WHEN 2 THEN '{"key_features": ["All videos unlocked", "HD quality streaming", "1 device access"]}'::jsonb
    WHEN 3 THEN '{"key_features": ["Coming soon", "Higher quality tiers", "More device support"]}'::jsonb
    ELSE plans.features
  END,
  is_active = CASE ranked.plan_rank
    WHEN 3 THEN false
    ELSE true
  END,
  updated_at = NOW()
FROM ranked_plans AS ranked
WHERE plans.id = ranked.id;