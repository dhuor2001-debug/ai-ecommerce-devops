const express = require('express');
const client = require('prom-client');
const logger = require('./logger');

module.exports = function createApp(store) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '10kb' }));

  // ---- Prometheus metrics ----
  const register = new client.Registry();
  client.collectDefaultMetrics({ register });
  const httpDuration = new client.Histogram({
    name: 'http_request_duration_seconds',
    help: 'HTTP request latency',
    labelNames: ['method', 'route', 'status'],
    buckets: [0.005, 0.01, 0.05, 0.1, 0.3, 0.5, 1, 2, 5],
    registers: [register],
  });
  const ordersTotal = new client.Counter({ name: 'orders_created_total', help: 'Orders created', registers: [register] });

  app.use((req, res, next) => {
    const end = httpDuration.startTimer();
    res.on('finish', () => {
      const route = req.route ? req.baseUrl + req.route.path : 'unmatched';
      end({ method: req.method, route, status: res.statusCode });
      if (req.path !== '/health' && req.path !== '/metrics') {
        logger.info('request', { method: req.method, path: req.path, status: res.statusCode });
      }
    });
    next();
  });

  // ---- Health ----
  app.get('/health', (req, res) => res.json({ status: 'ok', version: process.env.APP_VERSION || 'dev' }));
  app.get('/ready', async (req, res) => {
    try {
      await store.ping();
      res.json({ status: 'ready', store: store.kind });
    } catch (e) {
      logger.error('database connection timeout', { error: e.message });
      res.status(503).json({ status: 'not_ready', error: 'database_unavailable' });
    }
  });
  app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  });

  // ---- API ----
  const wrap = (fn) => (req, res) => fn(req, res).catch((e) => {
    logger.error('unhandled error', { error: e.message, path: req.path });
    res.status(500).json({ error: 'internal_error' });
  });

  app.get('/api/products', wrap(async (req, res) => res.json(await store.listProducts())));

  app.get('/api/products/:id', wrap(async (req, res) => {
    const p = await store.getProduct(Number(req.params.id));
    if (!p) return res.status(404).json({ error: 'product_not_found' });
    res.json(p);
  }));

  app.post('/api/orders', wrap(async (req, res) => {
    const productId = Number(req.body?.productId);
    const quantity = Number(req.body?.quantity ?? 1);
    if (!Number.isInteger(productId) || !Number.isInteger(quantity) || quantity < 1 || quantity > 100) {
      return res.status(400).json({ error: 'invalid_input' });
    }
    const result = await store.createOrder(productId, quantity);
    if (result.error === 'product_not_found') return res.status(404).json(result);
    if (result.error) return res.status(409).json(result);
    ordersTotal.inc();
    logger.info('order created', { orderId: result.order.id, total: result.order.total });
    res.status(201).json(result.order);
  }));

  app.get('/api/orders', wrap(async (req, res) => res.json(await store.listOrders())));

  app.use((req, res) => res.status(404).json({ error: 'not_found' }));
  return app;
};
