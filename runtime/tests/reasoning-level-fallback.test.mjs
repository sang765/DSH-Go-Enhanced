// Saved reasoning levels outlive models: the engine must fall back to the
// model's own default instead of failing the request. Source-level checks, no
// live Host and no provider traffic.
// DSH_PREFIX=/path/to/patched/prefix node --test runtime/tests/reasoning-level-fallback.test.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import test from 'node:test';

const prefix = process.env.DSH_TEST_PREFIX ?? process.env.DSH_PREFIX;
const options = { skip: !prefix && 'prepared DSH prefix required' };
const read = rel => readFileSync(join(resolve(prefix), rel), 'utf8');

function slice(text, start, end) {
  const a = text.indexOf(start);
  const b = text.indexOf(end, a + start.length);
  assert(a >= 0 && b > a, `patched source not found: ${start}`);
  return text.slice(a, b);
}

const llm = 'node_modules/@deepseek-ai/dsh-llm/lib/index.js';
const deepseek = 'node_modules/@deepseek-ai/dsh-llm-deepseek/lib/index.js';
const piai = 'node_modules/@deepseek-ai/dsh-llm-pi-ai/lib/index.js';

function central() {
  const src = slice(read(llm),
    '\t\t/**\n\t\t* Resolve request controls against one already-bound exact model result.',
    '\n\t\t/**\n\t\t* Resolve one call under its current adapter');
  return Function(`return ({${src}}).resolveCallWithInfo;`)();
}

function piAiHelpers() {
  const src = slice(read(piai),
    'function resolveSupportedReasoningLevel(model, effort, fallback) {',
    '\n/**\n* Selectable reasoning efforts for one model');
  return Function('getSupportedThinkingLevels',
    `${src}; return { resolveReasoningLevel, describableReasoningLevel };`)(
    model => model.supported);
}

function deepSeekEffort(options, defaults) {
  const src = slice(read(deepseek),
    "\t// The route default names this model's effort; a stale saved level falls back to it.",
    '\n\tconst system = [options.system, historySystem]');
  return Function('options', 'connection', `${src}; return effort;`)(options, { defaults });
}

test('central call resolution falls back to a level the model offers', options, () => {
  const resolve = central();
  const info = { reasoning: { efforts: [{ id: 'off' }, { id: 'low' }, { id: 'high' }], defaultEffort: 'high' } };
  assert.equal(resolve({ provider: 'p', model: 'm', reasoningEffort: 'max' }, info).config.reasoningEffort, 'high');
  assert.equal(resolve({ provider: 'p', model: 'm' }, info).config.reasoningEffort, 'high');
  assert.equal(resolve({ provider: 'p', model: 'm', reasoningEffort: 'low' }, info).config.reasoningEffort, 'low');

  const noDefault = { reasoning: { efforts: [{ id: 'off' }, { id: 'medium' }] } };
  assert.equal(resolve({ provider: 'p', model: 'm', reasoningEffort: 'max' }, noDefault).config.reasoningEffort, 'medium');
  assert.equal('reasoningEffort' in resolve({ provider: 'p', model: 'm' }, noDefault).config, false);

  const noThinking = { reasoning: void 0 };
  assert.equal('reasoningEffort' in resolve({ provider: 'p', model: 'm', reasoningEffort: 'high' }, noThinking).config, false);
  assert.deepEqual(resolve({ provider: 'p', model: 'm' }, { reasoning: { efforts: [], defaultEffort: 'high' } }).config, { provider: 'p', model: 'm' });
});

test('pi-ai derives levels from the model and uses the route default when stale', options, () => {
  const { resolveReasoningLevel, describableReasoningLevel } = piAiHelpers();
  const model = { supported: ['off', 'low', 'medium', 'high'] };
  assert.equal(resolveReasoningLevel(model, 'medium', 'high'), 'medium');
  assert.equal(resolveReasoningLevel(model, 'xhigh', 'high'), 'high');
  assert.equal(resolveReasoningLevel(model, void 0, 'high'), 'high');
  assert.equal(resolveReasoningLevel(model, 'medium', 'xhigh'), 'medium');
  assert.equal(resolveReasoningLevel({ supported: ['off', 'low'] }, 'max', 'xhigh'), 'low');
  assert.equal(resolveReasoningLevel({ supported: ['off'] }, 'max', 'high'), void 0);
  assert.equal(resolveReasoningLevel({ supported: ['off', 'low'] }, void 0, void 0), void 0);
  assert.equal(describableReasoningLevel(model, 'high'), 'high');
  assert.equal(describableReasoningLevel(model, 'max'), 'low');
});

test('DeepSeek falls back to the route default and keeps thinking disabled off', options, () => {
  assert.equal(deepSeekEffort({ reasoningEffort: 'max' }, { thinking: 'enabled', reasoningEffort: 'high' }), 'max');
  assert.equal(deepSeekEffort({ reasoningEffort: 'medium' }, { thinking: 'enabled', reasoningEffort: 'high' }), 'high');
  assert.equal(deepSeekEffort({}, { thinking: 'enabled' }), 'high');
  assert.equal(deepSeekEffort({ reasoningEffort: 'medium' }, { thinking: 'disabled', reasoningEffort: 'high' }), 'off');
});

test('the patched request paths no longer throw UNSUPPORTED_REASONING_EFFORT', options, () => {
  for (const rel of [llm, deepseek, piai]) {
    assert(!read(rel).includes('"UNSUPPORTED_REASONING_EFFORT"'), `${rel} still rejects a stale level`);
  }
});
