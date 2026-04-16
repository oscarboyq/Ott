export const nowPaymentsApiBase = 'https://api.nowpayments.io/v1';

export function sortKeysRecursively(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(sortKeysRecursively);
  }

  if (value && typeof value === 'object') {
    return Object.keys(value as Record<string, unknown>)
      .sort()
      .reduce<Record<string, unknown>>((result, key) => {
        result[key] = sortKeysRecursively(
          (value as Record<string, unknown>)[key],
        );
        return result;
      }, {});
  }

  return value;
}

export async function signNowPaymentsPayload(
  payload: unknown,
  secret: string,
): Promise<string> {
  const sortedPayload = JSON.stringify(sortKeysRecursively(payload));
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-512' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(sortedPayload),
  );

  return Array.from(new Uint8Array(signature))
    .map((value) => value.toString(16).padStart(2, '0'))
    .join('');
}

export function normalizeNowPaymentsStatus(status: unknown): string {
  return String(status ?? '').trim().toLowerCase();
}

export function isSuccessfulNowPaymentsStatus(status: string): boolean {
  return normalizeNowPaymentsStatus(status) === 'finished';
}

export function isTerminalNowPaymentsStatus(status: string): boolean {
  const normalized = normalizeNowPaymentsStatus(status);
  return ['finished', 'failed', 'expired', 'refunded'].includes(normalized);
}
