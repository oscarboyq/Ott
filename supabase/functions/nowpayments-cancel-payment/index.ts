import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

import { getCorsHeaders } from '../_shared/cors.ts';
import {
  isTerminalNowPaymentsStatus,
  normalizeNowPaymentsStatus,
  nowPaymentsApiBase,
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

Deno.serve(async (req) => {
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

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse(req, { error: 'Missing Supabase secrets' }, 500);
    }

    const authorization = req.headers.get('Authorization');
    const token = authorization?.replace('Bearer ', '').trim();

    if (!token) {
      return jsonResponse(req, { error: 'Missing authorization token' }, 401);
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
    const {
      data: { user },
      error: authError,
    } = await supabaseAdmin.auth.getUser(token);

    if (authError || !user) {
      return jsonResponse(req, { error: 'Unauthorized' }, 401);
    }

    const body = await req.json();
    const paymentId = String(body.paymentId ?? '').trim();

    if (!paymentId) {
      return jsonResponse(req, { error: 'paymentId is required' }, 400);
    }

    const { data: payment, error: paymentError } = await supabaseAdmin
      .from('payments')
      .select('id, user_id, payment_status, provider_payment_id, raw_response')
      .eq('id', paymentId)
      .maybeSingle();

    if (paymentError || !payment || payment.user_id !== user.id) {
      return jsonResponse(req, { error: 'Payment not found' }, 404);
    }

    const cancellableStatuses = new Set([
      'creating',
      'new',
      'waiting',
      'confirming',
      'sending',
      'partially_paid',
    ]);

    if (!cancellableStatuses.has(String(payment.payment_status))) {
      return jsonResponse(req, { error: 'This payment can no longer be cancelled' }, 400);
    }

    let providerStatus = '';
    let providerStatusPayload: Record<string, unknown> | null = null;

    if (payment.provider_payment_id != null) {
      if (!nowPaymentsApiKey) {
        return jsonResponse(req, { error: 'Missing NOWPayments API key' }, 500);
      }

      const providerResponse = await fetch(
        `${nowPaymentsApiBase}/payment/${payment.provider_payment_id}`,
        {
          method: 'GET',
          headers: {
            'x-api-key': nowPaymentsApiKey,
          },
        },
      );

      const providerPayload = await providerResponse.json().catch(() => null);
      providerStatusPayload = asRecord(providerPayload);

      if (!providerResponse.ok || providerPayload == null) {
        return jsonResponse(
          req,
          {
            error: providerStatusPayload['message']?.toString() ??
                providerStatusPayload['error']?.toString() ??
                'Failed to confirm payment status with NOWPayments',
          },
          502,
        );
      }

      providerStatus = normalizeNowPaymentsStatus(providerStatusPayload['payment_status']);

      if (isTerminalNowPaymentsStatus(providerStatus)) {
        return jsonResponse(
          req,
          {
            error: `This payment is already ${providerStatus.isEmpty ? 'finalized' : providerStatus} on NOWPayments and can no longer be cancelled.`,
          },
          400,
        );
      }

      if (providerStatus.isNotEmpty && !cancellableStatuses.has(providerStatus)) {
        return jsonResponse(
          req,
          {
            error: `NOWPayments reports this payment as ${providerStatus}, so it can no longer be cancelled.`,
          },
          400,
        );
      }
    }

    const existingRawResponse = asRecord(payment.raw_response);
    const mergedRawResponse = {
      ...existingRawResponse,
      cancelled_by_user: true,
      cancelled_at: new Date().toISOString(),
      cancellation_source: 'app',
      provider_status_at_cancel: providerStatus.isEmpty ? null : providerStatus,
      provider_cancel_check: providerStatusPayload,
    };

    const { error: updateError } = await supabaseAdmin
      .from('payments')
      .update({
        payment_status: 'cancelled',
        raw_response: mergedRawResponse,
      })
      .eq('id', paymentId)
      .eq('user_id', user.id);

    if (updateError) {
      return jsonResponse(req, { error: updateError.message }, 500);
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