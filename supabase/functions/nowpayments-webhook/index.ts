import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

import { getCorsHeaders } from '../_shared/cors.ts';
import {
  isSuccessfulNowPaymentsStatus,
  normalizeNowPaymentsStatus,
  signNowPaymentsPayload,
} from '../_shared/nowpayments.ts';

function jsonResponse(req: Request, body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...getCorsHeaders(req), 'Content-Type': 'application/json' },
  });
}

function asRecord(value: unknown): Record<string, unknown> {
  return value != null && typeof value === 'object' && !Array.isArray(value)
      ? value as Record<string, unknown>
      : {};
}

function sameDayPrice(left: number | null, right: number | null): boolean {
  if (left == null || right == null) {
    return false;
  }

  return Math.abs(left - right) < 0.01;
}

function durationDaysForPlan(plan: Record<string, unknown>, paymentAmount: number | null): number {
  const annualPrice = plan.annual_price != null ? Number(plan.annual_price) : null;
  const monthlyPrice = plan.monthly_price != null ? Number(plan.monthly_price) : null;

  if (sameDayPrice(paymentAmount, annualPrice) && annualPrice != null) {
    return 365;
  }

  if (sameDayPrice(paymentAmount, monthlyPrice) && monthlyPrice != null) {
    return 30;
  }

  return 30;
}

function billingPeriodForPlan(plan: Record<string, unknown>, paymentAmount: number | null): string {
  const annualPrice = plan.annual_price != null ? Number(plan.annual_price) : null;
  const monthlyPrice = plan.monthly_price != null ? Number(plan.monthly_price) : null;

  if (sameDayPrice(paymentAmount, annualPrice) && annualPrice != null) {
    return 'annual';
  }

  if (sameDayPrice(paymentAmount, monthlyPrice) && monthlyPrice != null) {
    return 'monthly';
  }

  return 'monthly';
}

async function activateSubscription(
  supabaseAdmin: ReturnType<typeof createClient>,
  paymentRow: Record<string, unknown>,
) {
  const userId = String(paymentRow.user_id);
  const planId = String(paymentRow.plan_id);
  const providerPaymentId = paymentRow.provider_payment_id != null
      ? String(paymentRow.provider_payment_id)
      : null;

  const { data: plan, error: planError } = await supabaseAdmin
    .from('subscription_plans')
    .select('id, name, description, monthly_price, annual_price')
    .eq('id', planId)
    .single();

  if (planError) {
    throw new Error(`Failed to load subscription plan: ${planError.message}`);
  }

  const paymentAmount = paymentRow.price_amount != null
      ? Number(paymentRow.price_amount)
      : null;
  const durationDays = durationDaysForPlan(plan, paymentAmount);
    const billingPeriod = billingPeriodForPlan(plan, paymentAmount);
    const priceCurrency = paymentRow.price_currency != null
      ? String(paymentRow.price_currency)
      : 'usdt';

  const { data: existingSubscription } = await supabaseAdmin
    .from('user_subscriptions')
    .select('expires_at')
    .eq('user_id', userId)
    .eq('plan_id', planId)
    .maybeSingle();

  const now = new Date();
  const baseDate = existingSubscription?.expires_at != null && new Date(existingSubscription.expires_at) > now
    ? new Date(existingSubscription.expires_at)
    : now;
  const expiresAt = new Date(baseDate.getTime() + durationDays * 24 * 60 * 60 * 1000);

  await supabaseAdmin
    .from('user_subscriptions')
    .update({ is_active: false, updated_at: new Date().toISOString() })
    .eq('user_id', userId)
    .neq('plan_id', planId)
    .eq('is_active', true);

  const { error: upsertError } = await supabaseAdmin.from('user_subscriptions').upsert(
    {
      user_id: userId,
      plan_id: planId,
      started_at: now.toISOString(),
      expires_at: expiresAt.toISOString(),
      is_active: true,
      auto_renew: false,
      plan_name_snapshot: plan.name ?? null,
      plan_description_snapshot: plan.description ?? null,
      price_amount_snapshot: paymentAmount,
      price_currency_snapshot: priceCurrency,
      billing_period_snapshot: billingPeriod,
      payment_provider: 'nowpayments',
      external_payment_id: providerPaymentId,
      stripe_subscription_id: null,
    },
    { onConflict: 'user_id,plan_id' },
  );

  if (upsertError) {
    throw new Error(`Failed to activate subscription: ${upsertError.message}`);
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: getCorsHeaders(req) });
  }

  if (req.method !== 'POST') {
    return jsonResponse(req, { error: 'Method not allowed' }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const ipnSecret = Deno.env.get('NOWPAYMENTS_IPN_SECRET');

    if (!supabaseUrl || !serviceRoleKey || !ipnSecret) {
      return jsonResponse(req, { error: 'Missing Supabase or NOWPayments IPN secret' }, 500);
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
    const signature = req.headers.get('x-nowpayments-sig');
    const payload = await req.json();

    if (!signature) {
      return jsonResponse(req, { error: 'Missing NOWPayments signature' }, 401);
    }

    const expectedSignature = await signNowPaymentsPayload(payload, ipnSecret);
    if (expectedSignature !== signature) {
      return jsonResponse(req, { error: 'Invalid NOWPayments signature' }, 401);
    }

    const paymentStatus = normalizeNowPaymentsStatus(payload.payment_status);
    const providerPaymentId = payload.payment_id != null ? String(payload.payment_id) : null;
    const orderId = payload.order_id != null ? String(payload.order_id) : null;
    const paymentLookupColumn = providerPaymentId != null ? 'provider_payment_id' : 'order_id';
    const paymentLookupValue = providerPaymentId ?? orderId;

    if (!paymentLookupValue) {
      return jsonResponse(req, { error: 'Payment id or order id is required' }, 400);
    }

    const { data: paymentRow, error: paymentError } = await supabaseAdmin
      .from('payments')
      .select('*')
      .eq(paymentLookupColumn, paymentLookupValue)
      .maybeSingle();

    await supabaseAdmin.from('payment_webhook_events').insert({
      provider: 'nowpayments',
      external_id: providerPaymentId ?? orderId,
      event_type: paymentStatus,
      payload,
    });

    if (paymentError || !paymentRow) {
      return jsonResponse(req, { error: 'Payment record not found' }, 404);
    }

    const existingRawResponse = asRecord(paymentRow.raw_response);
    const wasCancelledByUser =
      normalizeNowPaymentsStatus(paymentRow.payment_status) === 'cancelled' ||
      existingRawResponse['cancelled_by_user'] == true;

    if (wasCancelledByUser) {
      const cancelledPaymentUpdate = {
        provider_payment_id: providerPaymentId ?? paymentRow.provider_payment_id,
        pay_address: payload.pay_address ?? paymentRow.pay_address,
        pay_amount: payload.pay_amount != null ? Number(payload.pay_amount) : paymentRow.pay_amount,
        pay_currency: payload.pay_currency ?? paymentRow.pay_currency,
        payin_extra_id: payload.payin_extra_id ?? paymentRow.payin_extra_id,
        outcome_amount: payload.outcome_amount != null ? Number(payload.outcome_amount) : paymentRow.outcome_amount,
        outcome_currency: payload.outcome_currency ?? paymentRow.outcome_currency,
        actually_paid: payload.actually_paid != null ? Number(payload.actually_paid) : paymentRow.actually_paid,
        actually_paid_at_fiat: payload.actually_paid_at_fiat != null
            ? Number(payload.actually_paid_at_fiat)
            : paymentRow.actually_paid_at_fiat,
        parent_payment_id: payload.parent_payment_id != null ? String(payload.parent_payment_id) : paymentRow.parent_payment_id,
        raw_response: {
          ...existingRawResponse,
          provider_latest_status: paymentStatus,
          provider_latest_payload: payload,
          webhook_received_after_cancel: true,
          last_webhook_received_at: new Date().toISOString(),
        },
      };

      const { error: cancelledUpdateError } = await supabaseAdmin
        .from('payments')
        .update(cancelledPaymentUpdate)
        .eq('id', paymentRow.id);

      if (cancelledUpdateError) {
        return jsonResponse(req, { error: cancelledUpdateError.message }, 500);
      }

      return jsonResponse(req, { ok: true, ignored: 'payment_cancelled_locally' });
    }

    const paymentUpdate = {
      provider_payment_id: providerPaymentId ?? paymentRow.provider_payment_id,
      payment_status: paymentStatus,
      pay_address: payload.pay_address ?? paymentRow.pay_address,
      pay_amount: payload.pay_amount != null ? Number(payload.pay_amount) : paymentRow.pay_amount,
      pay_currency: payload.pay_currency ?? paymentRow.pay_currency,
      payin_extra_id: payload.payin_extra_id ?? paymentRow.payin_extra_id,
      price_amount: payload.price_amount != null ? Number(payload.price_amount) : paymentRow.price_amount,
      price_currency: payload.price_currency ?? paymentRow.price_currency,
      order_description: payload.order_description ?? paymentRow.order_description,
      purchase_id: payload.purchase_id != null ? String(payload.purchase_id) : paymentRow.purchase_id,
      outcome_amount: payload.outcome_amount != null ? Number(payload.outcome_amount) : paymentRow.outcome_amount,
      outcome_currency: payload.outcome_currency ?? paymentRow.outcome_currency,
      actually_paid: payload.actually_paid != null ? Number(payload.actually_paid) : paymentRow.actually_paid,
      actually_paid_at_fiat: payload.actually_paid_at_fiat != null
          ? Number(payload.actually_paid_at_fiat)
          : paymentRow.actually_paid_at_fiat,
      parent_payment_id: payload.parent_payment_id != null ? String(payload.parent_payment_id) : paymentRow.parent_payment_id,
      paid_at: isSuccessfulNowPaymentsStatus(paymentStatus)
          ? new Date().toISOString()
          : paymentRow.paid_at,
      raw_response: {
        ...existingRawResponse,
        provider_latest_status: paymentStatus,
        provider_latest_payload: payload,
        last_webhook_received_at: new Date().toISOString(),
      },
    };

    const { data: updatedPayments, error: updateError } = await supabaseAdmin
      .from('payments')
      .update(paymentUpdate)
      .eq('id', paymentRow.id)
      .select();

    if (updateError) {
      return jsonResponse(req, { error: updateError.message }, 500);
    }

    const updatedPaymentRow = Array.isArray(updatedPayments) && updatedPayments.length > 0
      ? updatedPayments[0]
      : { ...paymentRow, ...paymentUpdate };

    if (isSuccessfulNowPaymentsStatus(paymentStatus)) {
      await activateSubscription(supabaseAdmin, updatedPaymentRow);
    }

    return jsonResponse(req, { ok: true });
  } catch (error) {
    return jsonResponse(
      req,
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
