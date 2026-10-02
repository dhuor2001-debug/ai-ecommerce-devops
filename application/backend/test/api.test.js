const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const createApp = require('../src/app');

delete process.env.DATABASE_URL;
const createStore = require('../src/db');

let server, base;
before(async () => {
  process.env.LOG_LEVEL = 'error';
  server = createApp(createStore()).listen(0);
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

const j = (path, opts) => fetch(base + path, opts).then(async (r) => ({ status: r.status, body: await r.json().catch(() => null), res: r }));

test('GET /health returns ok', async () => {
  const r = await j('/health');
  assert.equal(r.status, 200);
  assert.equal(r.body.status, 'ok');
});

test('GET /ready returns ready', async () => {
  const r = await j('/ready');
  assert.equal(r.status, 200);
});

test('GET /api/products lists products', async () => {
  const r = await j('/api/products');
  assert.equal(r.status, 200);
  assert.ok(r.body.length >= 4);
});

test('GET /api/products/:id 404 for unknown', async () => {
  assert.equal((await j('/api/products/9999')).status, 404);
});

test('POST /api/orders creates an order and reduces stock', async () => {
  const before = (await j('/api/products/3')).body.stock;
  const r = await j('/api/orders', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ productId: 3, quantity: 2 }) });
  assert.equal(r.status, 201);
  assert.equal(r.body.total, 69);
  assert.equal((await j('/api/products/3')).body.stock, before - 2);
});

test('POST /api/orders rejects invalid input', async () => {
  const r = await j('/api/orders', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ productId: 'x' }) });
  assert.equal(r.status, 400);
});

test('POST /api/orders rejects insufficient stock', async () => {
  const r = await j('/api/orders', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ productId: 4, quantity: 100 }) });
  assert.equal(r.status, 409);
});

test('GET /metrics exposes Prometheus metrics', async () => {
  const res = await fetch(base + '/metrics');
  const text = await res.text();
  assert.equal(res.status, 200);
  assert.match(text, /http_request_duration_seconds/);
  assert.match(text, /orders_created_total/);
});
