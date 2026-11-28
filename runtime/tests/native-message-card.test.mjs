import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { NativeCore } from '../bridge/dsh-go-bridge/lib/native/core.js';
import { createNativeRoutes } from '../bridge/dsh-go-bridge/lib/native/routes.js';
import { LIMITS } from '../bridge/dsh-go-bridge/lib/native/limits.js';
import { checkManifest } from '../bridge/dsh-go-bridge/lib/native/manifest.js';

async function fixture(t) {
  const dir = mkdtempSync(join(tmpdir(), 'native-message-card-'));
  writeFileSync(join(dir, 'package.json'), JSON.stringify({ name: 'card-fixture', version: '1.0.0', dshGo: { v: 1, contributes: { 'message.card': [{ id: 'pr' }] } } }));
  writeFileSync(join(dir, 'index.js'), '');
  const entry = { options: { name: pathToFileURL(join(dir, 'index.js')).href }, parent: { tree: { ctx: { baseUrl: pathToFileURL(`${dir}/`).href } } }, fiber: { uid: 1 } };
  const core = new NativeCore({ get: name => name === 'loader' ? { entries: () => [entry] } : undefined }, LIMITS, 'test');
  const routes = createNativeRoutes(core);
  const service = Object.assign(Object.create(core.service), { ctx: { fiber: { entry }, effect: fn => fn() } });
  service.messageCard('pr', {
    view: { type: 'text', text: 'PR card' },
    data: (scope, emit) => { emit({ title: scope.messageId }); return () => {}; },
    actions: { open: scope => ({ link: `https://github.com/a/b/pull/${scope.turnId}` }) },
  });
  const server = createServer((req, res) => routes.handle(req, res, new URL(req.url, 'http://local').pathname, new URL(req.url, 'http://local')));
  server.on('upgrade', (req, socket, head) => routes.upgrade(req, socket, head));
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}`;
  const sockets = new Set();
  server.on('connection', socket => {
    sockets.add(socket);
    socket.on('close', () => sockets.delete(socket));
  });
  t.after(async () => {
    routes.dispose();
    core.dispose();
    for (const socket of sockets) socket.destroy();
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    rmSync(dir, { recursive: true, force: true });
  });
  return { base, core };
}

test('message.card is an optional contribution with its own registration', () => {
  const manifest = { name: 'cards', version: '1.0.0', dshGo: { v: 1, contributes: { 'message.card': [{ id: 'pr' }] } } };
  assert.deepEqual(checkManifest(manifest, '.', { handlers: [], cards: [] }).plugin.contributes['message.card'], [{ id: 'pr', ready: false }]);
  assert.deepEqual(checkManifest(manifest, '.', { handlers: [], cards: ['pr'] }).plugin.contributes['message.card'], [{ id: 'pr', ready: true }]);
});

test('view and invoke keep the card scope and action end to end', async t => {
  const { base } = await fixture(t);
  const read = await fetch(`${base}/dsh-go/v1/views/card-fixture/pr?sessionId=s&turnId=3&messageId=a9`);
  assert.equal(read.status, 200, JSON.stringify(await read.clone().json()));
  const body = await read.json();
  assert.equal(body.view.text, 'PR card');
  assert.equal(body.data.title, 'a9');
  assert.equal(body.live, true);
  const invoke = await fetch(`${base}/dsh-go/v1/invoke`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ v: 1, pkg: 'card-fixture', id: 'pr', surface: 'message.card', action: 'open', scope: { sessionId: 's', turnId: '3', messageId: 'a9' } }),
  });
  assert.equal(invoke.status, 200, JSON.stringify(await invoke.clone().json()));
  assert.deepEqual((await invoke.json()).effects, [{ type: 'link', url: 'https://github.com/a/b/pull/3' }]);
});

test('a card stream accepts a fully scoped message and publishes data', async t => {
  const { base } = await fixture(t);
  const ws = new WebSocket(`${base.replace('http', 'ws')}/dsh-go/v1/stream`);
  t.after(() => ws.close());
  await once(ws, 'open');
  const messages = [];
  ws.addEventListener('message', event => messages.push(JSON.parse(event.data)));
  ws.send(JSON.stringify({ t: 'hello', v: [1] }));
  ws.send(JSON.stringify({ t: 'sub', sub: 'one', pkg: 'card-fixture', id: 'pr', scope: { sessionId: 's', turnId: '3', messageId: 'a9' } }));
  await new Promise(resolve => setTimeout(resolve, 20));
  ws.close();
  assert.ok(messages.some(message => message.t === 'data' && message.sub === 'one' && message.data.title === 'a9'));
});
