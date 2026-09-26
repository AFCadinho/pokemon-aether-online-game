import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { isAllowedApiRoute, onRequest } from '../functions/api/[[path]].js';
import { onRequestGet as getNews } from '../functions/news.json.js';
import { onRequest as getBattleSprite } from '../functions/pokemon-assets/battle/[[path]].js';
import { onRequest as getGen5Sprite } from '../functions/pokemon-assets/gen5/[[path]].js';

const releaseRoutes = JSON.parse(readFileSync(new URL('./fixtures/web_release_routes.json', import.meta.url)));
for (const [method, path] of releaseRoutes.allowed) assert.equal(isAllowedApiRoute(method, path), true, `${method} ${path}`);
for (const [method, path] of releaseRoutes.denied) assert.equal(isAllowedApiRoute(method, path), false, `${method} ${path}`);

assert.equal(isAllowedApiRoute('POST', '/auth/web/login'), true);
assert.equal(isAllowedApiRoute('GET', '/auth/web/world/transitions/test/access'), true);
assert.equal(isAllowedApiRoute('PUT', '/auth/web/world'), true);
assert.equal(isAllowedApiRoute('POST', '/auth/web/world/teleport-ack'), true);
assert.equal(isAllowedApiRoute('GET', '/battle/pvp/training/ai/teams/catalog-team'), true);
assert.equal(isAllowedApiRoute('POST', '/battle/pvp/matches/test-match/start-battle'), true);
assert.equal(isAllowedApiRoute('GET', '/battle/pvp/matches/test-match/spectate'), true);
assert.equal(isAllowedApiRoute('GET', '/battle/pvp/matches/test-match/start-battle'), false);
assert.equal(isAllowedApiRoute('POST', '/battle/pvp/matches/test-match/settle'), false);
assert.equal(isAllowedApiRoute('POST', '/battle/test-id/choice-and-resolve'), true);
assert.equal(isAllowedApiRoute('POST', '/auth/web/npc-rewards/test-reward/claim'), true);
assert.equal(isAllowedApiRoute('POST', '/auth/web/npc-quest-item-turn-ins/test-turn-in/claim'), true);
assert.equal(isAllowedApiRoute('GET', '/auth/web/world/story-escape'), false);
assert.equal(isAllowedApiRoute('GET', '/game/guilds/me'), true);
assert.equal(isAllowedApiRoute('GET', '/game/guilds/me/bank'), false);
assert.equal(isAllowedApiRoute('PUT', '/game/guilds/me/members/7/bank-permissions'), false);
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
const rankedStart = await onRequest({
  request: new Request('https://play.example.test/api/battle/pvp/matches/test-match/start-battle', {
    method: 'POST', headers: { authorization: 'Bearer test-only' }, body: '{}',
  }),
  env: { API_ORIGIN: 'https://api.example.test' },
});
assert.equal(rankedStart.status, 200);
assert.equal(forwarded.url, 'https://api.example.test/battle/pvp/matches/test-match/start-battle');
assert.equal(forwarded.headers.get('authorization'), 'Bearer test-only');
assert.equal(forwarded.headers.get('x-pokeaether-client-platform'), 'web');

globalThis.fetch = async request => {
  forwarded = request;
  return new Response(new Uint8Array([0x89, 0x50, 0x4e, 0x47]), {
    headers: {
      'content-type': 'image/png',
      'cache-control': 'public, max-age=31536000, immutable',
      etag: 'test-only-etag',
    },
  });
};
const sprite = await getGen5Sprite({
  request: new Request('https://play.example.test/pokemon-assets/gen5/pokemon-gen5-front-895716cf7862/pidgey/sheet.png'),
  env: { ASSET_BASE_URL: 'https://assets.example.test' },
});
assert.equal(sprite.status, 200);
assert.equal(forwarded.url, 'https://assets.example.test/web/assets/pokemon-gen5-front-895716cf7862/pidgey/sheet.png');
assert.equal(sprite.headers.get('content-type'), 'image/png');
assert.equal(sprite.headers.get('cross-origin-resource-policy'), 'same-origin');
assert.equal(sprite.headers.get('cache-control'), 'public, max-age=31536000, immutable');
const deniedSpritePath = await getGen5Sprite({
  request: new Request('https://play.example.test/pokemon-assets/gen5/other/private.txt'),
  env: { ASSET_BASE_URL: 'https://assets.example.test' },
});
assert.equal(deniedSpritePath.status, 404);
const deniedSpriteMethod = await getGen5Sprite({
  request: new Request('https://play.example.test/pokemon-assets/gen5/pokemon-gen5-front-895716cf7862/pidgey/sheet.png', { method: 'POST' }),
  env: { ASSET_BASE_URL: 'https://assets.example.test' },
});
assert.equal(deniedSpriteMethod.status, 405);

const battleSprite = await getBattleSprite({
  request: new Request('https://play.example.test/pokemon-assets/battle/pokemon-front-scale1-128-402b7a6cee88/pidgey/sheet.png'),
  env: { ASSET_BASE_URL: 'https://assets.example.test' },
});
assert.equal(battleSprite.status, 200);
assert.equal(forwarded.url, 'https://assets.example.test/web/assets/pokemon-front-scale1-128-402b7a6cee88/pidgey/sheet.png');
assert.equal(battleSprite.headers.get('content-type'), 'image/png');
const deniedBattleSpritePath = await getBattleSprite({
  request: new Request('https://play.example.test/pokemon-assets/battle/pokemon-gen5-front-895716cf7862/pidgey/sheet.png'),
  env: { ASSET_BASE_URL: 'https://assets.example.test' },
});
assert.equal(deniedBattleSpritePath.status, 404);

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
