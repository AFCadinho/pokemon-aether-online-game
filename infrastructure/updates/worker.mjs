const origins = new Set(['https://updates.pokeaether.com', 'https://updates.pokemonaetheronline.com']);

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const match = /^\/(game|launcher)\/latest\/(PokeAether|PokeAetherLauncher)-(windows|linux|macos)\.zip$/.exec(url.pathname);
    if (!origins.has(url.origin) || !match || (match[1] === 'launcher') !== (match[2] === 'PokeAetherLauncher')) {
      return new Response('Not found', { status: 404 });
    }
    if (!['GET', 'HEAD'].includes(request.method)) {
      return new Response('Method not allowed', { status: 405, headers: { Allow: 'GET, HEAD' } });
    }
    try {
      const object = await env.UPDATES.get(`manifest-${match[3]}.json`);
      if (!object || object.size > 100_000) throw new Error('Missing manifest');
      const manifest = await object.json();
      const entry = manifest[match[1]];
      const target = new URL(entry.url);
      const pattern = match[1] === 'game'
        ? new RegExp(`^/game/game-[^/]+-${match[3]}\\.zip$`)
        : new RegExp(`^/launcher/[0-9][0-9A-Za-z.+_-]+/PokeAetherLauncher-${match[3]}\\.zip$`);
      if (!origins.has(target.origin) || target.search || target.hash || !pattern.test(target.pathname)) throw new Error('Invalid target');
      const key = decodeURIComponent(target.pathname.slice(1));
      if (key.split('/').some(part => ['.', '..', ''].includes(part)) || key.includes('\\')) throw new Error('Invalid key');
      const archive = await env.UPDATES.head(key);
      if (!archive || !Number.isSafeInteger(entry.sizeBytes) || archive.size !== entry.sizeBytes) throw new Error('Missing archive');
      // Keep the original hostname, including links on the previous domain.
      const location = new URL(target.pathname, url.origin).href;
      return new Response(null, { status: 302, headers: { Location: location, 'Cache-Control': 'no-store' } });
    } catch {
      return new Response('Download temporarily unavailable', { status: 503, headers: { 'Cache-Control': 'no-store', 'Retry-After': '60' } });
    }
  },
};
