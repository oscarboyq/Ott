const defaultAllowedHeaders = [
  'authorization',
  'apikey',
  'content-type',
  'x-client-info',
  'x-requested-with',
];

export function getCorsHeaders(req?: Request): Record<string, string> {
  const origin = req?.headers.get('origin') ?? '*';
  const requestedHeaders = req?.headers.get('access-control-request-headers');

  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': requestedHeaders ?? defaultAllowedHeaders.join(', '),
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin, Access-Control-Request-Headers',
  };
}

export const corsHeaders = getCorsHeaders();
