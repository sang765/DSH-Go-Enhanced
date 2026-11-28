import assert from 'node:assert/strict'
import { test } from 'node:test'
import { createTestHost } from '../lib/testing.js'
import { checkView } from '../lib/view-check.js'

const pkg = (contributes) => ({
  name: 'local-chat-view',
  version: '1.0.0',
  dshGo: { v: 1, title: 'Chat view', contributes },
})

test('chat.views manifest: anchors, hint, ready and live', () => {
  const host = createTestHost({
    dir: '/nonexistent',
    pkg: pkg({
      'chat.views': [
        { id: 'pr', anchor: 'message.after', title: 'PR', hint: { role: 'assistant', tools: ['github_pr'] } },
        { id: 'turn', anchor: 'turn.after' },
      ],
    }),
  })
  host.ctx.inject(['dshGo'], (ctx) => {
    ctx.dshGo.chatView('pr', {
      view: (scope) => scope.messageId === 'm1' ? { type: 'text', text: 'hello' } : null,
      data: () => () => {},
    })
  })
  const row = host.contributions()
  assert.equal(row.contributes['chat.views'].length, 2)
  assert.equal(row.contributes['chat.views'][0].anchor, 'message.after')
  assert.deepEqual(row.contributes['chat.views'][0].hint, { role: 'assistant', tools: ['github_pr'] })
  assert.equal(row.contributes['chat.views'][0].ready, true)
  assert.equal(row.contributes['chat.views'][0].live, true)
  assert.equal(row.contributes['chat.views'][1].ready, false)
})

test('an invalid anchor is dropped and a bad hint does not drop the view', () => {
  const host = createTestHost({
    dir: '/nonexistent',
    pkg: pkg({ 'chat.views': [{ id: 'bad', anchor: 'somewhere' }, { id: 'ok', anchor: 'turn.after', hint: { role: 'nobody' } }] }),
  })
  const row = host.contributions()
  assert.deepEqual(row.contributes['chat.views'].map((v) => v.id), ['ok'])
  assert.ok(row.issues.some((i) => i.path.includes('chat.views') && i.code === 'invalid-field'))
})

test('a null view draws nothing; a live view feeds data', async () => {
  const host = createTestHost({ dir: '/nonexistent', pkg: pkg({ 'chat.views': [{ id: 'pr', anchor: 'message.after' }] }) })
  host.ctx.inject(['dshGo'], (ctx) => {
    ctx.dshGo.chatView('pr', {
      view: (scope) => scope.messageId === 'm1' ? { type: 'stack', children: [{ type: 'text', text: { $: 'data.state' } }] } : null,
      data: (scope, emit) => { emit({ state: 'open' }); return () => {} },
    })
  })
  assert.equal((await host.view('pr', { messageId: 'm1' })).view.type, 'stack')
  assert.equal((await host.view('pr', { messageId: 'm2' })).view, null)
  const feed = host.subscribe('pr', { sessionId: 's1', messageId: 'm1' })
  assert.equal(feed.data.state, 'open')
  feed.stop()
})

test('a chat view function returning undefined is a no-view, like the bridge', async () => {
  const host = createTestHost({ dir: '/nonexistent', pkg: pkg({ 'chat.views': [{ id: 'pr', anchor: 'message.after' }] }) })
  host.ctx.inject(['dshGo'], (ctx) => {
    ctx.dshGo.chatView('pr', { view: () => undefined })
  })
  assert.equal((await host.view('pr', { messageId: 'm1' })).view, null)
})

test('chat.views invoke uses actions then falls back to on(id)', async () => {
  const host = createTestHost({ dir: '/nonexistent', pkg: pkg({ 'chat.views': [{ id: 'pr', anchor: 'message.after' }] }) })
  host.ctx.inject(['dshGo'], (ctx) => {
    ctx.dshGo.chatView('pr', { view: { type: 'text', text: 'x' }, actions: { refresh: () => ({ toast: 'from action' }) } })
    ctx.dshGo.on('pr', () => ({ toast: 'from on' }))
  })
  assert.equal((await host.invoke('pr', { surface: 'chat.views', action: 'refresh' })).effects[0].text, 'from action')
  assert.equal((await host.invoke('pr', { surface: 'chat.views' })).effects[0].text, 'from on')
})

test('chat views use the panel budget, which the app renderer also uses', () => {
  const result = checkView(JSON.stringify({ type: 'stack', children: [{ type: 'text', text: 'ok' }] }), { budget: 'panel', lang: 'en' })
  assert.equal(result.fatal, false)
  assert.equal(result.budget, 'panel')
})
