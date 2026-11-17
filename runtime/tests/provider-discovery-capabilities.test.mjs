// What a listing's per-model capability metadata becomes on the wire: vision
// and reasoning advertised by OpenRouter-shaped gateways reach the app as
// inputModalities and reasoningEfforts, and a silent listing stays silent.
// Real pinned LlmRuntime and pi-ai plugin, loopback HTTP only.
// DSH_PREFIX=<private patched prefix> node --test runtime/tests/provider-discovery-capabilities.test.mjs
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import test from 'node:test';

if (!process.env.DSH_PREFIX) throw Error('Set DSH_PREFIX to the pinned test prefix');
const base = join(resolve(process.env.DSH_PREFIX), 'node_modules/@deepseek-ai');
const load = (pkg, file = 'lib/index.js') => import(pathToFileURL(join(base, pkg, file)));
const { LlmRuntime } = await load('dsh-llm');
const { apply } = await load('dsh-llm-pi-ai');

const LISTING = {
  data: [
    {
      id: 'gateway-vision',
      name: 'Gateway Vision',
      context_length: 131072,
      top_provider: { max_completion_tokens: 65536 },
      architecture: { input_modalities: ['text', 'image'] },
      supported_parameters: ['temperature', 'reasoning', 'reasoning_effort'],
    },
    {
      id: 'gateway-flat',
      input_modalities: ['text'],
      supported_parameters: ['include_reasoning'],
    },
    { id: 'gateway-plain' },
    { id: 'gateway-noisy', architecture: { input_modalities: ['text', 'audio', 'image'] },
      supported_parameters: ['reasoning_effort', 'logprobs'] },
  ],
};

async function fixture(t) {
  const server = createServer((request, response) => {
    if (request.url.startsWith('/v1/models')) {
      response.writeHead(200, { 'content-type': 'application/json' });
      response.end(JSON.stringify(LISTING));
    } else {
      response.writeHead(404).end();
    }
  });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); return new Promise(resolve => server.close(resolve)); });
  const service = Object.create(LlmRuntime.prototype);
  service.discoveries = new Map();
  const ctx = {
    fiber: { entry: { options: { id: 'llm-pi-ai' } } },
    inject() {},
    on() { return () => {}; },
    get(name) { return name === 'credentials' ? { resolve: async () => ({ value: 'fixture-key' }) } : undefined; },
    waterfall(_name, _request, value) { return value; },
    logger: { warn() {}, error(error) { throw error; } },
    llm: {
      registerConfigurableProviders() { return { replace() {} }; },
      registerModelDiscovery(namespace, discover) { service.discoveries.set(namespace, discover); },
      registerAdapter() { return { replace() {} }; },
    },
  };
  apply(ctx, { providers: { get: () => ({}) } });
  const discover = service.discoveries.get('llm-pi-ai');
  assert(discover, 'the pi-ai plugin registers model discovery');
  return { baseURL: `http://127.0.0.1:${server.address().port}/v1`, discover };
}

test('advertised modalities and reasoning reach the discovery payload', async t => {
  const { baseURL, discover } = await fixture(t);
  const models = await discover({ baseURL, api: 'openai-completions', apiKey: 'fixture-key' });
  assert.deepEqual(models, [
    {
      id: 'gateway-vision',
      name: 'Gateway Vision',
      contextWindow: 131072,
      maxTokens: 65536,
      inputModalities: ['text', 'image'],
      reasoningEfforts: ['low', 'medium', 'high'],
    },
    { id: 'gateway-flat', name: 'gateway-flat', inputModalities: ['text'],
      reasoningEfforts: ['low', 'medium', 'high'] },
    { id: 'gateway-plain', name: 'gateway-plain' },
    { id: 'gateway-noisy', name: 'gateway-noisy', inputModalities: ['text', 'image'],
      reasoningEfforts: ['low', 'medium', 'high'] },
  ]);
});
