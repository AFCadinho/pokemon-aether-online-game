const ROUTE_PREFIX = '/pokemon-assets/gen5/';
const SPRITE_PATH = /^pokemon-gen5-(?:front|back|shiny-front|shiny-back)-[a-f0-9]{12}\/[a-z0-9-]{1,96}\/(?:animation\.json|sheet\.png)$/;

function assetOrigin(value, requestOrigin) {
  const parsed = new URL(value || '');
  if (parsed.protocol !== 'https:' || parsed.username || parsed.password || parsed.pathname !== '/' || parsed.search || parsed.hash) {
    throw new Error('ASSET_BASE_URL must be an HTTPS origin');
  }
  if (parsed.origin === requestOrigin) throw new Error('ASSET_BASE_URL must not point back to this Pages site');
  return parsed.origin;
}

function errorResponse(status) {
  return new Response(null, {
    status,
    headers: {
      'Cache-Control': 'no-store',
      'Cross-Origin-Resource-Policy': 'same-origin',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}

export async function onRequest(context) {
  if (!['GET', 'HEAD'].includes(context.request.method)) return errorResponse(405);
  const requestUrl = new URL(context.request.url);
  if (!requestUrl.pathname.startsWith(ROUTE_PREFIX)) return errorResponse(404);
  const spritePath = requestUrl.pathname.slice(ROUTE_PREFIX.length);
  if (!SPRITE_PATH.test(spritePath)) return errorResponse(404);

  let origin;
  try {
    origin = assetOrigin(context.env.ASSET_BASE_URL, requestUrl.origin);
  } catch (_) {
    return errorResponse(503);
  }

  const headers = new Headers();
  const range = context.request.headers.get('range');
  if (range) headers.set('range', range);
  const upstream = await fetch(new Request(`${origin}/web/assets/${spritePath}`, {
    method: context.request.method,
    headers,
    redirect: 'manual',
  }));
  if (![200, 206].includes(upstream.status)) return errorResponse(upstream.status === 404 ? 404 : 502);

  const responseHeaders = new Headers({
    'Cache-Control': upstream.headers.get('cache-control') || 'public, max-age=31536000, immutable',
    'Cross-Origin-Resource-Policy': 'same-origin',
    'X-Content-Type-Options': 'nosniff',
  });
  for (const name of ['content-type', 'content-range', 'accept-ranges', 'etag', 'last-modified']) {
    const value = upstream.headers.get(name);
    if (value) responseHeaders.set(name, value);
  }
  return new Response(context.request.method === 'HEAD' ? null : upstream.body, {
    status: upstream.status,
    headers: responseHeaders,
  });
}
