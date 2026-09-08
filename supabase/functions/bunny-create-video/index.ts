import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

import { getCorsHeaders } from '../_shared/cors.ts';

const bunnyVideoApiBase = 'https://video.bunnycdn.com';
const bunnyTusUploadUrl = `${bunnyVideoApiBase}/tusupload`;
const uploadAuthorizationLifetimeSeconds = 24 * 60 * 60;

type CreateVideoRequest = {
  title?: unknown;
  collectionId?: unknown;
  thumbnailTime?: unknown;
};

type BunnyVideo = {
  guid?: unknown;
};

function jsonResponse(req: Request, body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...getCorsHeaders(req), 'Content-Type': 'application/json' },
  });
}

function optionalString(value: unknown): string | null {
  if (value == null) return null;
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function normalizePullZone(value: string): string | null {
  try {
    const url = new URL(
      value.includes('://') ? value.trim() : `https://${value.trim()}`,
    );
    if (url.protocol !== 'https:' || !url.hostname || url.pathname !== '/') {
      return null;
    }
    return url.hostname;
  } catch (_) {
    return null;
  }
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
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
    const bunnyApiKey = Deno.env.get('BUNNY_STREAM_API_KEY')?.trim();
    const bunnyLibraryId = Deno.env.get('BUNNY_STREAM_LIBRARY_ID')?.trim();
    const configuredPullZone = Deno.env.get('BUNNY_STREAM_PULL_ZONE')?.trim();

    if (!supabaseUrl || !serviceRoleKey) {
      console.error('Missing required Supabase Edge Function secrets');
      return jsonResponse(req, { error: 'Server configuration is incomplete' }, 500);
    }

    if (!bunnyApiKey || !bunnyLibraryId || !configuredPullZone) {
      console.error('Missing one or more Bunny Stream secrets');
      return jsonResponse(req, { error: 'Bunny Stream is not configured' }, 500);
    }

    if (!/^\d+$/.test(bunnyLibraryId)) {
      console.error('BUNNY_STREAM_LIBRARY_ID is not numeric');
      return jsonResponse(req, { error: 'Bunny Stream configuration is invalid' }, 500);
    }

    const pullZone = normalizePullZone(configuredPullZone);
    if (!pullZone) {
      console.error('BUNNY_STREAM_PULL_ZONE is not a valid HTTPS hostname');
      return jsonResponse(req, { error: 'Bunny Stream configuration is invalid' }, 500);
    }

    const authorization = req.headers.get('Authorization');
    const bearerMatch = authorization?.match(/^Bearer\s+(.+)$/i);
    const token = bearerMatch?.[1]?.trim();
    if (!token) {
      return jsonResponse(req, { error: 'Missing authorization token' }, 401);
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user },
      error: authError,
    } = await supabaseAdmin.auth.getUser(token);

    if (authError || !user) {
      return jsonResponse(req, { error: 'Unauthorized' }, 401);
    }

    const { data: adminProfile, error: adminError } = await supabaseAdmin
      .from('user_profiles')
      .select('id')
      .eq('id', user.id)
      .eq('is_admin', true)
      .maybeSingle();

    if (adminError) {
      console.error('Unable to verify administrator access:', adminError.message);
      return jsonResponse(req, { error: 'Unable to verify administrator access' }, 500);
    }
    if (!adminProfile) {
      return jsonResponse(req, { error: 'Administrator access required' }, 403);
    }

    let body: CreateVideoRequest;
    try {
      body = await req.json() as CreateVideoRequest;
    } catch (_) {
      return jsonResponse(req, { error: 'Request body must be valid JSON' }, 400);
    }

    const title = optionalString(body.title);
    if (!title) {
      return jsonResponse(req, { error: 'title is required' }, 400);
    }
    if (title.length > 200) {
      return jsonResponse(req, { error: 'title must be 200 characters or fewer' }, 400);
    }

    const collectionId = optionalString(body.collectionId);
    let thumbnailTime: number | null = null;
    if (body.thumbnailTime != null) {
      if (
        typeof body.thumbnailTime !== 'number' ||
        !Number.isSafeInteger(body.thumbnailTime) ||
        body.thumbnailTime < 0
      ) {
        return jsonResponse(
          req,
          { error: 'thumbnailTime must be a non-negative integer in milliseconds' },
          400,
        );
      }
      thumbnailTime = body.thumbnailTime;
    }

    const bunnyResponse = await fetch(
      `${bunnyVideoApiBase}/library/${bunnyLibraryId}/videos`,
      {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          AccessKey: bunnyApiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          title,
          ...(collectionId ? { collectionId } : {}),
          ...(thumbnailTime != null ? { thumbnailTime } : {}),
        }),
      },
    );

    const bunnyPayload = await bunnyResponse.json().catch(() => null) as
      | BunnyVideo
      | null;

    if (!bunnyResponse.ok) {
      console.error(
        `Bunny create-video request failed with status ${bunnyResponse.status}`,
      );
      return jsonResponse(
        req,
        {
          error: 'Bunny Stream could not create the video',
          providerStatus: bunnyResponse.status,
        },
        502,
      );
    }

    const videoId = optionalString(bunnyPayload?.guid);
    if (!videoId) {
      console.error('Bunny create-video response did not contain a video GUID');
      return jsonResponse(req, { error: 'Bunny Stream returned an invalid response' }, 502);
    }

    const expirationTime = Math.floor(Date.now() / 1000) +
      uploadAuthorizationLifetimeSeconds;
    const signature = await sha256Hex(
      `${bunnyLibraryId}${bunnyApiKey}${expirationTime}${videoId}`,
    );

    return jsonResponse(
      req,
      {
        videoId,
        libraryId: bunnyLibraryId,
        uploadUrl: bunnyTusUploadUrl,
        playbackUrl: `https://${pullZone}/${videoId}/playlist.m3u8`,
        embedUrl:
          `https://iframe.mediadelivery.net/embed/${bunnyLibraryId}/${videoId}`,
        signature,
        expirationTime,
      },
      201,
    );
  } catch (error) {
    console.error(
      'Unexpected bunny-create-video error:',
      error instanceof Error ? error.message : String(error),
    );
    return jsonResponse(req, { error: 'Unable to create Bunny video' }, 500);
  }
});
