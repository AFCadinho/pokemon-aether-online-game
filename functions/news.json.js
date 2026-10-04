// Forum news lives in the shared updates bucket, independent of browser assets.
const NEWS_URL = 'https://updates.pokeaether.com/data/news.json';

export async function onRequestGet() {
  const result = await fetch(NEWS_URL, {
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
