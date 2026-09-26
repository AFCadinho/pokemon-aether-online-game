const RELEASE_OBJECT_PATH = /^[a-f0-9]{40}-[0-9]+-[0-9]+\/[A-Za-z0-9._/-]{1,512}$/;

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

function assetOrigin(value, requestOrigin) {
  const parsed = new URL(value || '');
  if (parsed.protocol !== 'https:' || parsed.username || parsed.password
      || parsed.pathname !== '/' || parsed.search || parsed.hash
      || parsed.origin === requestOrigin) {
    throw new Error('ASSET_BASE_URL must be a separate HTTPS origin');
  }
  return parsed.origin;
}

export async function onRequest(context) {
  if (!['GET', 'HEAD'].includes(context.request.method)) return errorResponse(405);
  const requestUrl = new URL(context.request.url);
  let objectPath;
  try {
    objectPath = decodeURIComponent(requestUrl.pathname.slice('/web/releases/'.length));
  } catch (_) {
    return errorResponse(404);
  }
  const pathParts = objectPath.split('/');
  if (pathParts.some(part => !part || part === '.' || part === '..')
      || !RELEASE_OBJECT_PATH.test(objectPath)) return errorResponse(404);

  let origin;
  try {
    origin = assetOrigin(context.env.ASSET_BASE_URL, requestUrl.origin);
  } catch (_) {
    return errorResponse(503);
  }

  const headers = new Headers();
  for (const name of ['range', 'if-range', 'if-none-match', 'if-modified-since']) {
    const value = context.request.headers.get(name);
    if (value) headers.set(name, value);
  }
  const upstream = await fetch(new Request(`${origin}/web/releases/${objectPath}`, {
    method: context.request.method,
    headers,
    redirect: 'manual',
  }));
  if (![200, 206, 304].includes(upstream.status)) {
    return errorResponse(upstream.status === 404 ? 404 : 502);
  }

  const responseHeaders = new Headers({
    'Cache-Control': upstream.headers.get('cache-control') || 'public, max-age=31536000, immutable',
    'Cross-Origin-Resource-Policy': 'same-origin',
    'X-Content-Type-Options': 'nosniff',
  });
  for (const name of ['content-type', 'content-range', 'accept-ranges', 'etag', 'last-modified']) {
    const value = upstream.headers.get(name);
    if (value) responseHeaders.set(name, value);
  }
  return new Response(context.request.method === 'HEAD' || upstream.status === 304 ? null : upstream.body, {
    status: upstream.status,
    headers: responseHeaders,
  });
}
