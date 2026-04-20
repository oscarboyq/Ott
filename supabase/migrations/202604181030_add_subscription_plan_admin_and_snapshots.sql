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

ALTER TABLE public.user_subscriptions
  ADD COLUMN IF NOT EXISTS plan_name_snapshot TEXT,
  ADD COLUMN IF NOT EXISTS plan_description_snapshot TEXT,
  ADD COLUMN IF NOT EXISTS price_amount_snapshot NUMERIC(10, 2),
  ADD COLUMN IF NOT EXISTS price_currency_snapshot TEXT,
  ADD COLUMN IF NOT EXISTS billing_period_snapshot TEXT;

UPDATE public.user_subscriptions AS subscriptions
SET
  plan_name_snapshot = COALESCE(subscriptions.plan_name_snapshot, plans.name),
  plan_description_snapshot = COALESCE(
    subscriptions.plan_description_snapshot,
    plans.description
  ),
  price_amount_snapshot = COALESCE(
    subscriptions.price_amount_snapshot,
    plans.monthly_price
  ),
  price_currency_snapshot = COALESCE(
    subscriptions.price_currency_snapshot,
    'usdt'
  ),
  billing_period_snapshot = COALESCE(
    subscriptions.billing_period_snapshot,
    'monthly'
  )
FROM public.subscription_plans AS plans
WHERE subscriptions.plan_id = plans.id;

ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view subscription plans" ON public.subscription_plans;
CREATE POLICY "Anyone can view subscription plans"
  ON public.subscription_plans
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Admins manage subscription plans" ON public.subscription_plans;
CREATE POLICY "Admins manage subscription plans"
  ON public.subscription_plans
  FOR ALL
  USING (public.is_current_user_admin())
  WITH CHECK (public.is_current_user_admin());