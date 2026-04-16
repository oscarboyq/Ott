-- NOWPayments crypto checkout integration.
-- Apply this migration before deploying the new Edge Functions.

-- Create the helper function if it doesn't exist
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

ALTER TABLE user_subscriptions
  ADD COLUMN IF NOT EXISTS payment_provider TEXT,
  ADD COLUMN IF NOT EXISTS external_payment_id TEXT;

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

CREATE TABLE IF NOT EXISTS payment_webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL,
  external_id TEXT,
  event_type TEXT,
  payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(payment_status);
CREATE INDEX IF NOT EXISTS idx_payments_provider_order ON payments(provider, order_id);
CREATE INDEX IF NOT EXISTS idx_payment_webhook_events_provider ON payment_webhook_events(provider, created_at DESC);

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_webhook_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own payments" ON payments;
CREATE POLICY "Users can view their own payments"
  ON payments FOR SELECT
  USING (auth.uid() = user_id);

DROP TRIGGER IF EXISTS update_payments_updated_at ON payments;
CREATE TRIGGER update_payments_updated_at
  BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
