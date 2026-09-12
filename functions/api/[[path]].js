const HTTP_ROUTES = new Set([
  'GET /auth/status', 'GET /presence/online-count',
  'GET /auth/web/meta', 'GET /auth/web/me', 'POST /auth/web/signup',
  'POST /auth/web/login', 'POST /auth/web/logout',
  'GET /auth/web/preferences', 'PUT /auth/web/preferences',
  'GET /auth/web/world', 'PUT /auth/web/world',
  'POST /auth/web/world/teleport-ack',
  'PATCH /auth/web/party/battle-state', 'GET /auth/web/profile',
  'GET /auth/web/party', 'GET /auth/web/inventory', 'GET /auth/web/guilds',
  'GET /auth/web/transit', 'GET /auth/web/starter/options', 'POST /auth/web/starter',
  'GET /auth/web/ai-sparring/statistics', 'GET /auth/web/ai-sparring/history',
  'DELETE /auth/web/ai-sparring/history', 'GET /battle/pvp/training/ai/teams',
  'GET /battle/pvp/training/ai/live', 'POST /battle/pvp/training/ai/battles',
  'POST /battle/wild-encounter', 'GET /battle/wild/resume',
  'POST /battle/trainer', 'GET /battle/trainer/resume',
  'POST /battle/pvp/rooms', 'GET /pokemon/stats',
  'POST /auth/email-verification/confirm',
  'GET /auth/web/boxes', 'GET /auth/web/wallet', 'PUT /auth/web/party',
  'POST /auth/web/party/heal', 'POST /auth/web/party/swap', 'POST /auth/web/party/set-slot',
  'POST /auth/web/pokemon/storage/move',
  'POST /auth/web/wallet/rewards/wild-battle', 'POST /auth/web/wallet/rewards/trainer-battle',
  'POST /auth/web/mail',
  'POST /auth/web/respawn',
]);

const HTTP_PREFIXES = [
  ['GET', '/game/pokedex/'], ['GET', '/game/items/'], ['GET', '/game/skills'],
  ['GET', '/game/donator-store'], ['POST', '/game/donator-store/'],
  ['GET', '/battle/pvp/training/ai/live/'],
  ['GET', '/battle/pvp/training/ai/teams/'],
  ['GET', '/battle/pvp/rooms/'], ['POST', '/battle/pvp/rooms/'],
  ['GET', '/trainers/'], ['GET', '/npcs/'], ['GET', '/overworld-pokemon/'],
  ['GET', '/dialogues/'], ['GET', '/encounters/'],
  ['GET', '/auth/web/world/story'], ['POST', '/auth/web/world/story'],
  ['GET', '/auth/web/world/activity'], ['PUT', '/auth/web/world/activity'],
  ['GET', '/auth/web/world/encounter-modifiers'],
  ['POST', '/auth/web/npc-rewards/'],
  ['POST', '/auth/web/npc-quest-item-turn-ins/'],
  ['GET', '/auth/web/mail'],
  ['GET', '/auth/web/socials'], ['POST', '/auth/web/socials'],
  ['PUT', '/auth/web/socials'], ['DELETE', '/auth/web/socials'],
  ['POST', '/auth/web/wild-battles/'], ['POST', '/auth/web/transit/'],
  ['GET', '/game/replays'], ['POST', '/game/replays'],
  ['PATCH', '/game/replays'], ['DELETE', '/game/replays'],
  ['GET', '/auth/web/world/transitions/'], ['POST', '/auth/web/world/transitions/'],
  ['GET', '/auth/web/world/areas/'],
];

const AI_BATTLE_ROUTE = /^\/battle\/[A-Za-z0-9-]{1,128}\/(?:state|lead|choice|choice-and-resolve|npc\/(?:lead|choice)|pass-turn|pokemon-info|damage-calc|calcdex\/v1\/(?:snapshot|open|matchup|smart-matchup|inferred-matchup|set-suggestions))$/;
const WEBSOCKETS = new Set(['/ws/chat', '/ws/world-presence', '/ws/pvp-battle']);
const GAMEPLAY_ROUTES = [
  ['GET', /^\/auth\/web\/boxes\/\d+$/], ['PATCH', /^\/auth\/web\/boxes\/\d+$/],
  ['DELETE', /^\/auth\/web\/(?:pokemon|party)\/\d+$/],
  ['POST', /^\/auth\/web\/pokemon\/\d+\/(?:nickname|held-item|evolution|evs\/allocate|items\/use|moves\/(?:learn|delete|reorder))$/],
  ['DELETE', /^\/auth\/web\/pokemon\/\d+\/held-item$/],
  ['PATCH', /^\/auth\/web\/pokemon\/\d+\/ball$/],
  ['GET', /^\/auth\/web\/pokemon\/\d+\/moves\/mentor$/],
  ['POST', /^\/auth\/web\/inventory\/items\/[a-z0-9-]+\/(?:use|discard)$/],
  ['GET', /^\/auth\/web\/markets\/[a-z0-9_-]+$/],
  ['POST', /^\/auth\/web\/markets\/[a-z0-9_-]+\/purchase$/],
  ['POST', /^\/auth\/web\/markets\/standard\/sell$/],
  ['GET', /^\/auth\/web\/trainers\/[a-zA-Z0-9_-]+\/progress$/],
  ['POST', /^\/auth\/web\/trainers\/[a-zA-Z0-9_-]+\/rematch$/],
  ['POST', /^\/auth\/web\/mail\/\d+\/read$/],
  ['DELETE', /^\/auth\/web\/mail\/\d+$/],
];

export function isAllowedApiRoute(method, path) {
  const normalizedMethod = method.toUpperCase();
  if (HTTP_ROUTES.has(`${normalizedMethod} ${path}`)) return true;
  if (GAMEPLAY_ROUTES.some(([verb, pattern]) => verb === normalizedMethod && pattern.test(path))) return true;
  if (normalizedMethod === 'GET' && WEBSOCKETS.has(path)) return true;
  if (AI_BATTLE_ROUTE.test(path) && ['GET', 'POST'].includes(normalizedMethod)) return true;
  return HTTP_PREFIXES.some(([allowedMethod, prefix]) => {
    if (normalizedMethod !== allowedMethod) return false;
    return prefix.endsWith('/') ? path.startsWith(prefix) : path === prefix || path.startsWith(`${prefix}/`);
  });
}

function apiOrigin(value, requestOrigin) {
  const parsed = new URL(value || '');
  if (parsed.protocol !== 'https:' || parsed.username || parsed.password || parsed.pathname !== '/' || parsed.search || parsed.hash) {
    throw new Error('API_ORIGIN must be an HTTPS origin');
  }
  if (parsed.origin === requestOrigin) throw new Error('API_ORIGIN must not point back to this Pages site');
  return parsed.origin;
}

export async function onRequest(context) {
  const requestUrl = new URL(context.request.url);
  const backendPath = requestUrl.pathname.slice('/api'.length) || '/';
  if (!isAllowedApiRoute(context.request.method, backendPath)) {
    return Response.json({ detail: { code: 'web_route_not_allowed' } }, {
      status: 403,
      headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' },
    });
  }
  let origin;
  try {
    origin = apiOrigin(context.env.API_ORIGIN, requestUrl.origin);
  } catch (_) {
    return Response.json({ detail: { code: 'web_gateway_unavailable' } }, {
      status: 503,
      headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' },
    });
  }
  const contentLength = Number(context.request.headers.get('content-length') || 0);
  const largeBattlePayload = backendPath.startsWith('/battle/') || ['/auth/web/party', '/auth/web/party/battle-state'].includes(backendPath);
  const maximumBytes = largeBattlePayload ? 128 * 1024 : 16 * 1024;
  if (contentLength > maximumBytes) {
    return Response.json({ detail: { code: 'request_too_large' } }, {
      status: 413,
      headers: { 'Cache-Control': 'no-store' },
    });
  }
  const target = new URL(backendPath + requestUrl.search, origin);
  if ((context.request.headers.get('upgrade') || '').toLowerCase() === 'websocket') {
    const websocketHeaders = new Headers(context.request.headers);
    websocketHeaders.delete('cookie');
    websocketHeaders.set('x-pokeaether-client-platform', 'web');
    return fetch(new Request(target, { method: context.request.method, headers: websocketHeaders }));
  }
  const headers = new Headers();
  for (const name of ['authorization', 'content-type', 'accept', 'accept-language', 'x-pokeaether-client-build']) {
    const value = context.request.headers.get(name);
    if (value) headers.set(name, value);
  }
  headers.set('x-pokeaether-client-platform', 'web');
  let body;
  if (!['GET', 'HEAD'].includes(context.request.method)) {
    body = await context.request.arrayBuffer();
    if (body.byteLength > maximumBytes) {
      return Response.json({ detail: { code: 'request_too_large' } }, {
        status: 413, headers: { 'Cache-Control': 'no-store' },
      });
    }
  }
  const upstreamRequest = new Request(target, {
    method: context.request.method,
    headers,
    body,
  });
  const result = await fetch(upstreamRequest, { redirect: 'manual' });
  if (result.status >= 300 && result.status < 400) {
    return Response.json({ detail: { code: 'unexpected_upstream_redirect' } }, {
      status: 502, headers: { 'Cache-Control': 'no-store' },
    });
  }
  const responseHeaders = new Headers({
    'Cache-Control': result.headers.get('cache-control') || 'no-store',
    'X-Content-Type-Options': 'nosniff',
  });
  for (const name of ['content-type', 'retry-after']) {
    const value = result.headers.get(name);
    if (value) responseHeaders.set(name, value);
  }
  return new Response(result.body, { status: result.status, headers: responseHeaders });
}
