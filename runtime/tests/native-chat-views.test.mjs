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
import { ANCHORS, LIMITS } from '../bridge/dsh-go-bridge/lib/native/limits.js';
import { checkManifest, parseManifest } from '../bridge/dsh-go-bridge/lib/native/manifest.js';

const contribute = (id, extra = {}) => ({ id, anchor: 'message.after', ...extra });

const manifestOf = (items) => ({ name: 'views', version: '1.0.0', dshGo: { v: 1, contributes: { 'chat.views': items } } });

async function fixture(t) {
  const dir = mkdtempSync(join(tmpdir(), 'native-chat-views-'));
  writeFileSync(join(dir, 'package.json'), JSON.stringify({
    name: 'views-fixture', version: '1.0.0',
    dshGo: { v: 1, contributes: { 'chat.views': [contribute('pr', {
      title: { zh: 'PR 状态', en: 'PR status' }, icon: 'code',
      hint: { role: 'assistant', tools: ['github_pr'] },
    })] } },
  }));
  writeFileSync(join(dir, 'index.js'), '');
  const entry = { options: { name: pathToFileURL(join(dir, 'index.js')).href }, parent: { tree: { ctx: { baseUrl: pathToFileURL(`${dir}/`).href } } }, fiber: { uid: 1 } };
  const core = new NativeCore({ get: name => name === 'loader' ? { entries: () => [entry] } : undefined }, LIMITS, 'test');
  const routes = createNativeRoutes(core);
  const service = Object.assign(Object.create(core.service), { ctx: { fiber: { entry }, effect: fn => fn() } });
  const disposers = [];
  disposers.push(service.chatView('pr', {
    view: (scope) => scope.messageId === 'none' ? null : { v: 2, type: 'text', text: `PR card ${scope.messageId ?? ''}` },
    data: (scope, emit) => { emit({ title: scope.messageId ?? null }); return () => {}; },
    actions: {
      open: (scope, event) => ({
        toast: JSON.stringify({ action: event.action, value: event.value }),
        link: `https://github.com/a/b/pull/${scope.turnId}`,
      }),
    },
  }));
  const server = createServer((req, res) => routes.handle(req, res, new URL(req.url, 'http://local').pathname, new URL(req.url, 'http://local')));
  server.on('upgrade', (req, socket, head) => routes.upgrade(req, socket, head));
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}`;
  t.after(async () => {
    for (const dispose of disposers) dispose?.();
    routes.dispose();
    core.dispose();
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    rmSync(dir, { recursive: true, force: true });
  });
  return { base, core };
}

test('chat.views parses the five fixed anchors and hydrates title, icon and hint', () => {
  assert.deepEqual(ANCHORS, ['message.after', 'message.before', 'turn.after', 'composer.above', 'chat.overlay']);
  const parsed = parseManifest(manifestOf([
    contribute('good', { title: { zh: 'PR 状态', en: 'PR status' }, icon: 'code', hint: { role: 'assistant', tools: ['github_pr'] } }),
  ]), '.');
  assert.equal(parsed.items['chat.views'].length, 1);
  assert.equal(parsed.items['chat.views'][0].anchor, 'message.after');
  assert.deepEqual(parsed.items['chat.views'][0].hint, { role: 'assistant', tools: ['github_pr'] });
});

test('an invalid or missing anchor is an invalid-field error and drops only that entry', () => {
  const parsed = parseManifest(manifestOf([
    contribute('ok', { anchor: 'turn.after' }),
    contribute('bad', { anchor: 'somewhere.else' }),
    { id: 'missing' },
  ]), '.');
  assert.deepEqual(parsed.items['chat.views'].map(x => x.id), ['ok']);
  const codes = parsed.issues.map(i => `${i.code}@${i.path}`);
  assert.ok(codes.includes('invalid-field@/dshGo/contributes/chat.views/1/anchor'));
  assert.ok(codes.includes('invalid-field@/dshGo/contributes/chat.views/2/anchor'));
});

test('hint warns on unknown keys and drops only an invalid hint', () => {
  const hintOf = (hint) => parseManifest(manifestOf([contribute('v', { hint })]), '.');
  const unknown = hintOf({ role: 'user', extra: 1 });
  assert.deepEqual(unknown.items['chat.views'][0].hint, { role: 'user' });
  assert.ok(unknown.issues.some(i => i.code === 'unknown-field' && i.path.endsWith('/hint/extra')));
  for (const bad of [
    'nope', { role: 'system' }, { tools: 'github_pr' },
    { tools: ['x'.repeat(65)] }, { tools: Array.from({ length: 9 }, (_, i) => `t${i}`) },
  ]) {
    const r = hintOf(bad);
    assert.equal(r.items['chat.views'][0].hint, undefined, JSON.stringify(bad));
    assert.ok(r.issues.some(i => i.code === 'invalid-field' && i.path.includes('/hint')), JSON.stringify(bad));
  }
});

test('ready needs a chatView registration, live needs data, and titles are cut to 16', () => {
  const m = manifestOf([contribute('long', { title: 'x'.repeat(20), anchor: 'composer.above' })]);
  const none = checkManifest(m, '.', { handlers: [], chatViews: [] });
  assert.equal(none.plugin.contributes['chat.views'][0].ready, false);
  assert.equal(none.plugin.contributes['chat.views'][0].live, false);
  assert.ok(none.issues.some(i => i.code === 'no-handler'));
  const reg = checkManifest(m, '.', { handlers: [], chatViews: ['long'] });
  assert.equal(reg.plugin.contributes['chat.views'][0].ready, true);
  assert.equal(reg.plugin.contributes['chat.views'][0].live, false);
  assert.equal(reg.plugin.contributes['chat.views'][0].title, 'x'.repeat(16));
  assert.ok(reg.issues.some(i => i.code === 'too-long'));
  const live = checkManifest(m, '.', { handlers: [], chatViews: ['long'], dataChatViews: ['long'] });
  assert.equal(live.plugin.contributes['chat.views'][0].live, true);
});

test('a plugin gets at most four chat views', () => {
  const items = Array.from({ length: 6 }, (_, i) => contribute(`v${i}`));
  const r = checkManifest(manifestOf(items), '.', { handlers: [], chatViews: [] });
  assert.equal(r.plugin.contributes['chat.views'].length, 4);
  assert.ok(r.issues.some(i => i.code === 'too-many'));
});

test('view and invoke keep the chat scope, anchor, hint, ready/live and actions end to end', async t => {
  const { base } = await fixture(t);
  const row = (await (await fetch(`${base}/dsh-go/v1/contributions?v=1`)).json()).plugins[0];
  assert.deepEqual(row.contributes['chat.views'], [{
    id: 'pr', anchor: 'message.after', title: 'PR status', icon: 'code',
    hint: { role: 'assistant', tools: ['github_pr'] }, ready: true, live: true,
  }]);

  const read = await fetch(`${base}/dsh-go/v1/views/views-fixture/pr?sessionId=s&turnId=3&messageId=a9`);
  assert.equal(read.status, 200, JSON.stringify(await read.clone().json()));
  const body = await read.json();
  assert.equal(body.view.text, 'PR card a9');
  assert.equal(body.data.title, 'a9');
  assert.equal(body.live, true);
  assert.equal(body.anchor, 'message.after');
  assert.deepEqual(body.hint, { role: 'assistant', tools: ['github_pr'] });
  assert.equal(body.title, 'PR status');

  const invoke = await fetch(`${base}/dsh-go/v1/invoke`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ v: 1, pkg: 'views-fixture', id: 'pr', surface: 'chat.views', action: 'open', value: { n: 1 }, scope: { sessionId: 's', turnId: '3', messageId: 'a9' } }),
  });
  assert.equal(invoke.status, 200, JSON.stringify(await invoke.clone().json()));
  const effects = (await invoke.json()).effects;
  assert.ok(effects.some(e => e.type === 'link' && e.url === 'https://github.com/a/b/pull/3'));
  const toast = effects.find(e => e.type === 'toast');
  assert.deepEqual(JSON.parse(toast.text), { action: 'open', value: { n: 1 } });
});

test('a null view answers 200 with view:null, no data and no feed', async t => {
  const { base, core } = await fixture(t);
  const read = await fetch(`${base}/dsh-go/v1/views/views-fixture/pr?sessionId=s&turnId=3&messageId=none`);
  assert.equal(read.status, 200, JSON.stringify(await read.clone().json()));
  const body = await read.json();
  assert.equal(body.view, null);
  assert.equal(body.live, false);
  assert.equal(body.data, null);
  assert.equal(body.rev, null);
  assert.deepEqual(body.stats, { bytes: 0, nodes: 0, depth: 0 });
  assert.equal(body.anchor, 'message.after');
  assert.equal(core.feeds.size, 0);
});

test('a chat view stream accepts a scoped id and publishes data', async t => {
  const { base } = await fixture(t);
  const ws = new WebSocket(`${base.replace('http', 'ws')}/dsh-go/v1/stream`);
  t.after(() => ws.close());
  await once(ws, 'open');
  const received = await new Promise((resolve, reject) => {
    const messages = [];
    const timer = setTimeout(() => reject(new Error(`no chat view data frame: ${JSON.stringify(messages)}`)), 2000);
    const done = (value) => { clearTimeout(timer); resolve(value); };
    ws.addEventListener('message', event => {
      const message = JSON.parse(event.data);
      messages.push(message);
      if (message.t === 'data' && message.sub === 'one' && message.data?.title === 'a9') return done(message);
      if (message.t === 'end' || message.t === 'error') {
        clearTimeout(timer);
        reject(new Error(JSON.stringify(message)));
      }
    });
    ws.send(JSON.stringify({ t: 'hello', v: [1] }));
    ws.send(JSON.stringify({ t: 'sub', sub: 'one', pkg: 'views-fixture', id: 'pr', scope: { sessionId: 's', turnId: '3', messageId: 'a9' } }));
  });
  assert.equal(received.t, 'data');
  assert.equal(received.data.title, 'a9');
});

test('a panel view must still return an object: null remains invalid-view', async t => {
  const dir = mkdtempSync(join(tmpdir(), 'native-panel-null-'));
  writeFileSync(join(dir, 'package.json'), JSON.stringify({
    name: 'panel-null', version: '1.0.0',
    dshGo: { v: 1, contributes: { panels: [{ id: 'p', title: 'P' }] } },
  }));
  writeFileSync(join(dir, 'index.js'), '');
  const entry = { options: { name: pathToFileURL(join(dir, 'index.js')).href }, parent: { tree: { ctx: { baseUrl: pathToFileURL(`${dir}/`).href } } }, fiber: { uid: 1 } };
  const core = new NativeCore({ get: name => name === 'loader' ? { entries: () => [entry] } : undefined }, LIMITS, 'test');
  const routes = createNativeRoutes(core);
  const service = Object.assign(Object.create(core.service), { ctx: { fiber: { entry }, effect: fn => fn() } });
  const dispose = service.panel('p', { view: () => null });
  const server = createServer((req, res) => routes.handle(req, res, new URL(req.url, 'http://local').pathname, new URL(req.url, 'http://local')));
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(async () => {
    dispose(); routes.dispose(); core.dispose();
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    rmSync(dir, { recursive: true, force: true });
  });
  const read = await fetch(`http://127.0.0.1:${server.address().port}/dsh-go/v1/views/panel-null/p`);
  assert.equal(read.status, 500);
  assert.equal((await read.json()).error.code, 'invalid-view');
});
