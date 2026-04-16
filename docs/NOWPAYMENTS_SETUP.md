# NOWPayments Setup

This project now includes a first-pass NOWPayments crypto checkout flow for premium subscriptions.

## 1. Apply the SQL migration

Run the migration in [supabase/migrations/20260415_nowpayments_crypto.sql](/home/asif/code/flutter/video/supabase/migrations/20260415_nowpayments_crypto.sql) against your Supabase database.

## 2. Set the required Edge Function secrets

Configure these secrets in Supabase:

- `NOWPAYMENTS_API_KEY`
- `NOWPAYMENTS_IPN_SECRET`
- `NOWPAYMENTS_DEFAULT_PAY_CURRENCY=usdtbsc`

## 3. Deploy the new Edge Functions

Deploy:

- `nowpayments-create-payment`
- `nowpayments-webhook`

## 4. NOWPayments dashboard settings

- Keep your payout wallet configured as `USDT BSC/BEP20`
- Save the IPN secret shown in NOWPayments exactly once
- Make sure NOWPayments can reach your Supabase function URL

The webhook URL used by this integration is:

`https://<your-project-ref>.supabase.co/functions/v1/nowpayments-webhook`

## 5. Current product behavior

- The Flutter app creates a one-time NOWPayments payment for a plan
- The app shows the wallet address and amount to send
- Premium access is activated only after the webhook marks the payment as `finished`
- This version assumes monthly plan purchases and defaults to a 30-day entitlement

## 6. Current limitations

- This is a one-time crypto checkout flow, not automatic recurring billing
- Annual duration detection only works when the paid amount matches `annual_price`
- The app currently expects webhook delivery for final confirmation