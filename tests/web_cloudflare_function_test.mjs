import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { isAllowedApiRoute, onRequest } from '../functions/api/[[path]].js';
import { onRequestGet as getNews } from '../functions/news.json.js';
import { onRequest as getBattleSprite } from '../functions/pokemon-assets/battle/[[path]].js';
import { onRequest as getGen5Sprite } from '../functions/pokemon-assets/gen5/[[path]].js';
import { onRequest as getWebReleaseObject } from '../functions/web/releases/[[path]].js';

const releaseRoutes = JSON.parse(readFileSync(new URL('./fixtures/web_release_routes.json', import.meta.url)));
for (const [method, path] of releaseRoutes.allowed) assert.equal(isAllowedApiRoute(method, path), true, `${method} ${path}`);
for (const [method, path] of releaseRoutes.denied) assert.equal(isAllowedApiRoute(method, path), false, `${method} ${path}`);

let matrixUpstreamCalls = 0;
globalThis.fetch = async () => {
  matrixUpstreamCalls++;
  return Response.json({ ok: true });
};
for (const [method, path] of releaseRoutes.allowed) {
  const response = await onRequest({
    request: new Request('https://play.example.test/api' + path, { method }),
    env: { API_ORIGIN: 'https://api.example.test' },
  });
  assert.equal(response.status, 200, `${method} ${path}`);
}
const acceptedMatrixCalls = matrixUpstreamCalls;
for (const [method, path] of releaseRoutes.denied) {
  const response = await onRequest({
    request: new Request('https://play.example.test/api' + path, { method }),
    env: { API_ORIGIN: 'https://api.example.test' },
  });
  assert.equal(response.status, 403, `${method} ${path}`);
}
assert.equal(matrixUpstreamCalls, acceptedMatrixCalls, 'Denied browser routes never reach the gateway');

assert.equal(isAllowedApiRoute('POST', '/auth/web/login'), true);
assert.equal(isAllowedApiRoute('GET', '/auth/web/world/transitions/test/access'), true);
assert.equal(isAllowedApiRoute('PUT', '/auth/web/world'), true);
assert.equal(isAllowedApiRoute('POST', '/auth/web/world/teleport-ack'), true);
assert.equal(isAllowedApiRoute('GET', '/battle/pvp/training/ai/teams/catalog-team'), true);
assert.equal(isAllowedApiRoute('GET', '/ws/training-live'), true);
assert.equal(isAllowedApiRoute('POST', '/battle/pvp/matches/test-match/start-battle'), true);
assert.equal(isAllowedApiRoute('GET', '/battle/pvp/matches/test-match/spectate'), true);
assert.equal(isAllowedApiRoute('GET', '/battle/pvp/matches/test-match/start-battle'), false);
assert.equal(isAllowedApiRoute('POST', '/battle/pvp/matches/test-match/settle'), false);
assert.equal(isAllowedApiRoute('POST', '/battle/test-id/choice-and-resolve'), true);
assert.equal(isAllowedApiRoute('POST', '/auth/web/npc-rewards/test-reward/claim'), true);
assert.equal(isAllowedApiRoute('POST', '/auth/web/npc-quest-item-turn-ins/test-turn-in/claim'), true);
assert.equal(isAllowedApiRoute('GET', '/auth/web/world/story-escape'), false);
assert.equal(isAllowedApiRoute('GET', '/game/guilds/me'), true);
assert.equal(isAllowedApiRoute('GET', '/game/guilds/me/bank'), true);
assert.equal(isAllowedApiRoute('PUT', '/game/guilds/me/members/7/bank-permissions'), true);
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
const exportedTeam = await onRequest({
  request: new Request('https://play.example.test/api/team/export', {
    method: 'POST', body: 'x'.repeat(20000),
  }),
  env: { API_ORIGIN: 'https://api.example.test' },
});
assert.equal(exportedTeam.status, 200);
assert.equal(forwarded.url, 'https://api.example.test/team/export');
const weeklyBoss = await onRequest({
  request: new Request('https://play.example.test/api/battle/weekly-boss', {
    method: 'POST', headers: { authorization: 'Bearer test-only' }, body: 'x'.repeat(20000),
  }),
  env: { API_ORIGIN: 'https://api.example.test' },
});
assert.equal(weeklyBoss.status, 200);
assert.equal(forwarded.url, 'https://api.example.test/battle/weekly-boss');
assert.equal(forwarded.headers.get('authorization'), 'Bearer test-only');
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

const tradeSocket = await onRequest({
  request: new Request('https://play.example.test/api/ws/trade?token=test-only&clientPlatform=web', {
    headers: { upgrade: 'websocket', cookie: 'private=1', 'x-pokeaether-client-platform': 'windows' },
  }),
  env: { API_ORIGIN: 'https://api.example.test' },
});
assert.equal(tradeSocket.status, 200);
assert.equal(forwarded.url, 'https://api.example.test/ws/trade?token=test-only&clientPlatform=web');
assert.equal(forwarded.headers.get('upgrade'), 'websocket');
assert.equal(forwarded.headers.get('cookie'), null);
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
  forwarded = request;
  return new Response(new Uint8Array([0x00, 0x61, 0x73, 0x6d]), {
    status: 206,
    headers: {
      'content-type': 'application/wasm',
      'content-range': 'bytes 0-3/64',
      'accept-ranges': 'bytes',
      'cache-control': 'public, max-age=31536000, immutable',
    },
  });
};
const releaseObject = await getWebReleaseObject({
  request: new Request('https://rc.example.test/web/releases/0123456789abcdef0123456789abcdef01234567-123-1/index.wasm', {
    headers: { range: 'bytes=0-3', cookie: 'must-not-forward' },
  }),
  env: { ASSET_BASE_URL: 'https://assets.example.test' },
});
assert.equal(releaseObject.status, 206);
assert.equal(forwarded.url, 'https://assets.example.test/web/releases/0123456789abcdef0123456789abcdef01234567-123-1/index.wasm');
assert.equal(forwarded.headers.get('range'), 'bytes=0-3');
assert.equal(forwarded.headers.get('cookie'), null);
assert.equal(releaseObject.headers.get('content-range'), 'bytes 0-3/64');
assert.equal(releaseObject.headers.get('cross-origin-resource-policy'), 'same-origin');
assert.equal((await releaseObject.arrayBuffer()).byteLength, 4);
const deniedReleaseTraversal = await getWebReleaseObject({
  request: new Request('https://rc.example.test/web/releases/0123456789abcdef0123456789abcdef01234567-123-1/%2e%2e/manifest-web.json'),
  env: { ASSET_BASE_URL: 'https://assets.example.test' },
});
assert.equal(deniedReleaseTraversal.status, 404);
const deniedReleaseMethod = await getWebReleaseObject({
  request: new Request('https://rc.example.test/web/releases/0123456789abcdef0123456789abcdef01234567-123-1/index.wasm', { method: 'POST' }),
  env: { ASSET_BASE_URL: 'https://assets.example.test' },
});
assert.equal(deniedReleaseMethod.status, 405);

globalThis.fetch = async request => {
  forwarded = request;
  return new Response(null, { headers: { 'Content-Type': 'audio/ogg' } });
};
for (const file of ['Kanto Wild Battle.ogg', "Johto's Battle.ogg"]) {
  const audio = await getWebReleaseObject({
    request: new Request('https://play.example.test/web/releases/0123456789abcdef0123456789abcdef01234567-123-1/browser-audio/music/' + encodeURIComponent(file), { method: 'HEAD' }),
    env: { ASSET_BASE_URL: 'https://assets.example.test' },
  });
  assert.equal(audio.status, 200, file);
  assert.equal(decodeURIComponent(new URL(forwarded.url).pathname), '/web/releases/0123456789abcdef0123456789abcdef01234567-123-1/browser-audio/music/' + file);
}

globalThis.fetch = async request => {
  assert.equal(request, 'https://updates.pokeaether.com/data/news.json');
  return Response.json({ articles: [{ title: 'Release', externalLink: 'https://forums.pokeaether.com/t/release/31' }] });
};
const news = await getNews({ env: { ASSET_BASE_URL: 'https://assets.example.test' } });
assert.equal(news.status, 200);
assert.equal(news.headers.get('cache-control'), 'public, max-age=300');
assert.equal((await news.json()).articles[0].title, 'Release');
const newsWithoutBrowserAssets = await getNews({ env: {} });
assert.equal(newsWithoutBrowserAssets.status, 200);
assert.equal((await newsWithoutBrowserAssets.json()).articles[0].externalLink, 'https://forums.pokeaether.com/t/release/31');

globalThis.fetch = async () => new Response('', { status: 404 });
const unavailableNews = await getNews({ env: {} });
assert.equal(unavailableNews.status, 502);
assert.equal(unavailableNews.headers.get('cache-control'), 'no-store');

globalThis.fetch = async () => new Response(new Uint8Array([0xff]), { status: 200 });
const invalidNews = await getNews({ env: { ASSET_BASE_URL: 'https://assets.example.test' } });
assert.equal(invalidNews.status, 502);
console.log('web_cloudflare_function_test: PASS');
