import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { isAllowedApiRoute, onRequest } from '../functions/api/[[path]].js';
import { onRequestGet as getNews } from '../functions/news.json.js';

const releaseRoutes = JSON.parse(readFileSync(new URL('./fixtures/web_release_routes.json', import.meta.url)));
for (const [method, path] of releaseRoutes.allowed) assert.equal(isAllowedApiRoute(method, path), true, `${method} ${path}`);
for (const [method, path] of releaseRoutes.denied) assert.equal(isAllowedApiRoute(method, path), false, `${method} ${path}`);

assert.equal(isAllowedApiRoute('POST', '/auth/web/login'), true);
assert.equal(isAllowedApiRoute('GET', '/auth/web/world/transitions/test/access'), true);
assert.equal(isAllowedApiRoute('PUT', '/auth/web/world'), true);
assert.equal(isAllowedApiRoute('GET', '/battle/pvp/training/ai/teams/catalog-team'), true);
assert.equal(isAllowedApiRoute('POST', '/battle/test-id/choice-and-resolve'), true);
assert.equal(isAllowedApiRoute('POST', '/auth/web/npc-rewards/test-reward/claim'), true);
assert.equal(isAllowedApiRoute('POST', '/auth/web/npc-quest-item-turn-ins/test-turn-in/claim'), true);
assert.equal(isAllowedApiRoute('GET', '/auth/web/world/story-escape'), false);
assert.equal(isAllowedApiRoute('GET', '/game/guilds-escape'), false);
assert.equal(isAllowedApiRoute('POST', '/pvp/queues/ranked/join'), false);
assert.equal(isAllowedApiRoute('GET', '/internal/authority'), false);

const denied = await onRequest({
  request: new Request('https://play.example.test/api/internal/authority'),
  env: { API_ORIGIN: 'https://api.example.test' },
});
assert.equal(denied.status, 403);

const unavailable = await onRequest({
  request: new Request('https://play.example.test/api/auth/status'),
  env: { API_ORIGIN: 'http://api.example.test' },
});
assert.equal(unavailable.status, 503);

const oversized = await onRequest({
  request: new Request('https://play.example.test/api/auth/web/login', {
    method: 'POST', headers: { 'content-length': '20000' }, body: 'x',
  }),
  env: { API_ORIGIN: 'https://api.example.test' },
});
assert.equal(oversized.status, 413);

let forwarded;
globalThis.fetch = async request => {
  forwarded = request;
  return Response.json({ ok: true }, { headers: { 'Set-Cookie': 'must-not-cross=1' } });
};
const proxied = await onRequest({
  request: new Request('https://play.example.test/api/auth/web/login', {
    method: 'POST',
    headers: {
      authorization: 'Bearer test-only', cookie: 'private=1', origin: 'https://attacker.test',
      'content-type': 'application/json', 'x-pokeaether-client-platform': 'windows',
    },
    body: '{}',
  }),
  env: { API_ORIGIN: 'https://api.example.test' },
});
assert.equal(proxied.status, 200);
assert.equal(forwarded.url, 'https://api.example.test/auth/web/login');
assert.equal(forwarded.headers.get('cookie'), null);
assert.equal(forwarded.headers.get('origin'), null);
assert.equal(forwarded.headers.get('x-pokeaether-client-platform'), 'web');
assert.equal(proxied.headers.get('set-cookie'), null);

globalThis.fetch = async request => {
  assert.equal(request, 'https://assets.example.test/data/news.json');
  return Response.json({ items: [{ title: 'Release' }] });
};
const news = await getNews({ env: { ASSET_BASE_URL: 'https://assets.example.test' } });
assert.equal(news.status, 200);
assert.equal(news.headers.get('cache-control'), 'public, max-age=300');
assert.equal((await news.json()).items[0].title, 'Release');

globalThis.fetch = async () => new Response(new Uint8Array([0xff]), { status: 200 });
const invalidNews = await getNews({ env: { ASSET_BASE_URL: 'https://assets.example.test' } });
assert.equal(invalidNews.status, 502);
console.log('web_cloudflare_function_test: PASS');
