function assetOrigin(value) {
  const parsed = new URL(value || '');
  if (parsed.protocol !== 'https:' || parsed.username || parsed.password || parsed.pathname !== '/' || parsed.search || parsed.hash) {
    throw new Error('ASSET_BASE_URL must be an HTTPS origin');
  }
  return parsed.origin;
}

export async function onRequestGet(context) {
  let origin;
  try {
    origin = assetOrigin(context.env.ASSET_BASE_URL);
  } catch (_) {
    return Response.json({ items: [] }, { status: 503, headers: { 'Cache-Control': 'no-store' } });
  }
  const result = await fetch(`${origin}/data/news.json`, {
    headers: { Accept: 'application/json' }, redirect: 'manual',
  });
  if (result.status !== 200) {
    return Response.json({ items: [] }, { status: 502, headers: { 'Cache-Control': 'no-store' } });
  }
  const body = await result.arrayBuffer();
  if (body.byteLength > 512 * 1024) {
    return Response.json({ items: [] }, { status: 502, headers: { 'Cache-Control': 'no-store' } });
  }
  let text;
  try {
    text = new TextDecoder('utf-8', { fatal: true }).decode(body);
    const parsed = JSON.parse(text);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error('invalid news');
  } catch (_) {
    return Response.json({ items: [] }, { status: 502, headers: { 'Cache-Control': 'no-store' } });
  }
  return new Response(text, {
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'public, max-age=300',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}
