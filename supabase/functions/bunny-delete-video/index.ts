import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

import { getCorsHeaders } from '../_shared/cors.ts';

const bunnyVideoApiBase = 'https://video.bunnycdn.com';

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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      status: 200,
      headers: getCorsHeaders(req),
    });
  }

  if (req.method !== 'POST' && req.method !== 'DELETE') {
    return jsonResponse(req, { error: 'Method not allowed' }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const bunnyApiKey = Deno.env.get('BUNNY_STREAM_API_KEY')?.trim();
    const bunnyLibraryId = Deno.env.get('BUNNY_STREAM_LIBRARY_ID')?.trim();

    if (!supabaseUrl || !serviceRoleKey) {
      console.error('Missing required Supabase Edge Function secrets');
      return jsonResponse(req, { error: 'Server configuration is incomplete' }, 500);
    }

    if (!bunnyApiKey || !bunnyLibraryId) {
      console.error('Missing one or more Bunny Stream secrets');
      return jsonResponse(req, { error: 'Bunny Stream is not configured' }, 500);
    }

    if (!/^\d+$/.test(bunnyLibraryId)) {
      console.error('BUNNY_STREAM_LIBRARY_ID is not numeric');
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

    if (adminError || !adminProfile) {
      return jsonResponse(req, { error: 'Forbidden: admin access required' }, 403);
    }

    const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    const videoId = optionalString(body.videoId);

    if (!videoId) {
      return jsonResponse(req, { error: 'Missing videoId' }, 400);
    }

    const bunnyResponse = await fetch(
      `${bunnyVideoApiBase}/library/${bunnyLibraryId}/videos/${videoId}`,
      {
        method: 'DELETE',
        headers: {
          AccessKey: bunnyApiKey,
          Accept: 'application/json',
        },
      },
    );

    // 200: deleted, 404: already deleted/not found on Bunny
    if (!bunnyResponse.ok && bunnyResponse.status !== 404) {
      const errorText = await bunnyResponse.text();
      console.error(`Bunny delete video failed: ${bunnyResponse.status} ${errorText}`);
      return jsonResponse(
        req,
        { error: `Bunny Stream deletion failed: ${bunnyResponse.status}` },
        502,
      );
    }

    return jsonResponse(req, {
      success: true,
      message: 'Video deleted from Bunny Stream',
      videoId,
    });
  } catch (error) {
    console.error('Unexpected error in bunny-delete-video:', error);
    return jsonResponse(
      req,
      { error: error instanceof Error ? error.message : 'Internal server error' },
      500,
    );
  }
});
