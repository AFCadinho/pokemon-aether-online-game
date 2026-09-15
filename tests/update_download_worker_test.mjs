import assert from 'node:assert/strict';
import test from 'node:test';
import worker from '../infrastructure/updates/worker.mjs';

const build = `0.3.78-${'a'.repeat(40)}-123-1`;
function environment(kind, platform, change = {}) {
  const key = kind === 'game' ? `game/game-${build}-${platform}.zip` : `launcher/${build}/PokeAetherLauncher-${platform}.zip`;
  const entry = { url: `https://updates.pokeaether.com/${key}`, sizeBytes: 123, ...change };
  return { UPDATES: {
    get: async name => {
      assert.equal(name, `manifest-${platform}.json`);
      return { size: 4000, json: async () => ({ [kind]: entry }) };
    },
    head: async name => {
      assert.equal(name, key);
      return { size: 123 };
    },
  } };
}

for (const host of ['updates.pokeaether.com', 'updates.pokemonaetheronline.com']) {
  for (const kind of ['game', 'launcher']) {
    for (const platform of ['windows', 'linux', 'macos']) {
      test(`${host} ${kind} ${platform} redirects GET and HEAD to the manifest archive`, async () => {
        const filename = kind === 'game' ? 'PokeAether' : 'PokeAetherLauncher';
        for (const method of ['GET', 'HEAD']) {
          const response = await worker.fetch(new Request(`https://${host}/${kind}/latest/${filename}-${platform}.zip`, { method }), environment(kind, platform));
          assert.equal(response.status, 302);
          assert.equal(new URL(response.headers.get('Location')).host, host);
          assert.equal(response.headers.get('Cache-Control'), 'no-store');
          assert.ok(response.headers.get('Location').includes(build));
        }
      });
    }
  }
}
test('rejects unrelated paths, hosts and write methods without reading R2', async () => {
  for (const url of ['https://evil.example/game/latest/PokeAether-windows.zip', 'https://updates.pokeaether.com/manifest.json', 'https://updates.pokeaether.com/game/latest/PokeAetherLauncher-windows.zip']) {
    assert.equal((await worker.fetch(new Request(url), {})).status, 404);
  }
  assert.equal((await worker.fetch(new Request('https://updates.pokeaether.com/game/latest/PokeAether-windows.zip', { method: 'POST' }), {})).status, 405);
});
test('fails closed on foreign URLs, aliases, absent archives and invalid manifests', async () => {
  const request = new Request('https://updates.pokeaether.com/game/latest/PokeAether-windows.zip');
  for (const url of ['https://evil.example/game/game-current-windows.zip', 'https://updates.pokeaether.com/game/latest/PokeAether-windows.zip', 'https://updates.pokeaether.com/game/game-current-linux.zip']) {
    assert.equal((await worker.fetch(request, environment('game', 'windows', { url }))).status, 503);
  }
  assert.equal((await worker.fetch(request, environment('game', 'windows', { sizeBytes: 999 }))).status, 503);
  assert.equal((await worker.fetch(request, { UPDATES: { get: async () => null } })).status, 503);
  assert.equal((await worker.fetch(request, { UPDATES: { get: async () => { throw Error('R2 failure'); } } })).status, 503);
});
