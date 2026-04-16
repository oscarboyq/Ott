import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

import { getCorsHeaders } from '../_shared/cors.ts';
import { nowPaymentsApiBase } from '../_shared/nowpayments.ts';

function jsonResponse(req: Request, body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...getCorsHeaders(req), 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      status: 200,
      headers: getCorsHeaders(req),
    });
  }

  if (req.method !== 'POST') {
    return jsonResponse(req, { error: 'Method not allowed' }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const nowPaymentsApiKey = Deno.env.get('NOWPAYMENTS_API_KEY');
    const defaultPayCurrency =
      Deno.env.get('NOWPAYMENTS_DEFAULT_PAY_CURRENCY') ?? 'usdtbsc';

    if (!supabaseUrl || !serviceRoleKey || !nowPaymentsApiKey) {
      return jsonResponse(
        req,
        { error: 'Missing Supabase or NOWPayments secrets' },
        500,
      );
    }

    const authorization = req.headers.get('Authorization');
    const token = authorization?.replace('Bearer ', '').trim();
    console.log('🔑 Authorization header:', authorization ? 'Present' : 'Missing');
    console.log('🔑 Token received:', token ? token.substring(0, 20) + '...' : 'No token');
    
    if (!token) {
      return jsonResponse(req, { error: 'Missing authorization token' }, 401);
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
    const {
      data: { user },
      error: authError,
    } = await supabaseAdmin.auth.getUser(token);

    console.log('🔐 Auth result - User:', user?.id ?? 'null', 'Error:', authError?.message ?? 'none');

    if (authError || !user) {
      return jsonResponse(req, { error: 'Unauthorized' }, 401);
    }

    const body = await req.json();
    const planId = String(body.planId ?? '').trim();
    const payCurrency = String(body.payCurrency ?? defaultPayCurrency).trim().toLowerCase();

    if (!planId) {
      return jsonResponse(req, { error: 'planId is required' }, 400);
    }

    const { data: plan, error: planError } = await supabaseAdmin
      .from('subscription_plans')
      .select('id, name, description, monthly_price, annual_price, is_active')
      .eq('id', planId)
      .maybeSingle();

    if (planError || !plan) {
      return jsonResponse(req, { error: 'Subscription plan not found' }, 404);
    }

    const monthlyPrice = Number(plan.monthly_price ?? 0);
    if (!plan.is_active || monthlyPrice <= 0) {
      return jsonResponse(req, { error: 'Selected plan cannot be purchased' }, 400);
    }

    const paymentId = crypto.randomUUID();
    const orderId = paymentId;
    const orderDescription = `Premium subscription for ${plan.name}`;
    const callbackUrl = `${supabaseUrl}/functions/v1/nowpayments-webhook`;

    const { error: draftError } = await supabaseAdmin.from('payments').insert({
      id: paymentId,
      user_id: user.id,
      plan_id: plan.id,
      provider: 'nowpayments',
      order_id: orderId,
      payment_status: 'creating',
      price_amount: monthlyPrice,
      price_currency: 'usd',
      pay_currency: payCurrency,
      order_description: orderDescription,
      raw_response: {
        stage: 'creating',
      },
    });

    if (draftError) {
      return jsonResponse(req, { error: draftError.message }, 500);
    }

    const nowPaymentsResponse = await fetch(`${nowPaymentsApiBase}/payment`, {
      method: 'POST',
      headers: {
        'x-api-key': nowPaymentsApiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        price_amount: monthlyPrice,
        price_currency: 'usd',
        pay_currency: payCurrency,
        order_id: orderId,
        order_description: orderDescription,
        ipn_callback_url: callbackUrl,
      }),
    });

    const providerPayload = await nowPaymentsResponse.json().catch(() => null);

    if (!nowPaymentsResponse.ok || !providerPayload) {
      await supabaseAdmin
        .from('payments')
        .update({
          payment_status: 'create_failed',
          raw_response: providerPayload ?? {
            error: 'Failed to decode NOWPayments response',
          },
        })
        .eq('id', paymentId);

      return jsonResponse(
        req,
        {
          error:
            providerPayload?.message ??
            providerPayload?.error ??
            'Failed to create NOWPayments payment',
        },
        502,
      );
    }

    const mappedPayment = {
      provider_payment_id: providerPayload.payment_id != null
          ? String(providerPayload.payment_id)
          : null,
      payment_status: String(providerPayload.payment_status ?? 'waiting'),
      pay_currency: providerPayload.pay_currency ?? payCurrency,
      pay_amount: providerPayload.pay_amount != null
          ? Number(providerPayload.pay_amount)
          : null,
      pay_address: providerPayload.pay_address ?? null,
      payin_extra_id: providerPayload.payin_extra_id ?? null,
      purchase_id: providerPayload.purchase_id != null
          ? String(providerPayload.purchase_id)
          : null,
      raw_response: providerPayload,
    };

    await supabaseAdmin.from('payments').update(mappedPayment).eq('id', paymentId);

    return jsonResponse(req, {
      id: paymentId,
      user_id: user.id,
      plan_id: plan.id,
      order_id: orderId,
      price_amount: monthlyPrice,
      price_currency: 'usd',
      order_description: orderDescription,
      ...mappedPayment,
    }, 201);
  } catch (error) {
    return jsonResponse(
      req,
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
