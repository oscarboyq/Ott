export interface ValidatedSupabaseConfig {
  supabaseUrl: string;
  supabasePublishableKey: string;
}

export class SetupValidationError extends Error {
  override readonly name = 'SetupValidationError';
}

function decodeLegacyAnonPayload(key: string): Record<string, unknown> | null {
  const segments = key.split('.');
  if (segments.length !== 3) return null;

  try {
    return JSON.parse(
      Buffer.from(segments[1], 'base64url').toString('utf8'),
    ) as Record<string, unknown>;
  } catch {
    return null;
  }
}

export function validateSupabaseConfigInput(
  rawUrl: unknown,
  rawKey: unknown,
): ValidatedSupabaseConfig {
  if (typeof rawUrl !== 'string' || typeof rawKey !== 'string') {
    throw new SetupValidationError(
      'Supabase URL and publishable key are required',
    );
  }

  const key = rawKey.trim();
  let url: URL;
  try {
    url = new URL(rawUrl.trim());
  } catch {
    throw new SetupValidationError('Supabase URL is invalid');
  }

  if (
    url.protocol !== 'https:' ||
    url.username ||
    url.password ||
    url.search ||
    url.hash ||
    (url.pathname !== '' && url.pathname !== '/')
  ) {
    throw new SetupValidationError(
      'Use the HTTPS Supabase project URL without a path',
    );
  }

  if (!url.hostname.endsWith('.supabase.co')) {
    throw new SetupValidationError(
      'Only hosted *.supabase.co project URLs are supported',
    );
  }

  if (key.startsWith('sb_secret_')) {
    throw new SetupValidationError(
      'Never enter a Supabase secret key in the client setup',
    );
  }

  if (key.startsWith('sb_publishable_')) {
    if (key.length < 30 || key.length > 512) {
      throw new SetupValidationError('Supabase publishable key is invalid');
    }
  } else {
    const payload = decodeLegacyAnonPayload(key);
    if (!payload || payload.role !== 'anon') {
      throw new SetupValidationError(
        'Use a publishable key or the legacy anon key',
      );
    }

    const projectRef = url.hostname.split('.')[0];
    if (typeof payload.ref === 'string' && payload.ref !== projectRef) {
      throw new SetupValidationError(
        'The Supabase URL and anon key belong to different projects',
      );
    }
  }

  return {
    supabaseUrl: url.origin,
    supabasePublishableKey: key,
  };
}

export async function verifySupabaseConnection(
  config: ValidatedSupabaseConfig,
): Promise<void> {
  let response: Response;
  try {
    response = await fetch(`${config.supabaseUrl}/auth/v1/settings`, {
      headers: {
        apikey: config.supabasePublishableKey,
      },
      signal: AbortSignal.timeout(8_000),
    });
  } catch {
    throw new SetupValidationError(
      'Could not connect to the Supabase project',
    );
  }

  if (!response.ok) {
    throw new SetupValidationError(
      'Supabase rejected the project URL or publishable key',
    );
  }
}
