const createStore = require('./db');
const createApp = require('./app');
const logger = require('./logger');

const port = Number(process.env.PORT || 3000);
const store = createStore();

async function start() {
  // Retry DB init so the container survives starting before Postgres is ready.
  for (let attempt = 1; attempt <= 10; attempt++) {
    try {
      await store.init();
      break;
    } catch (e) {
      logger.warn('database not ready, retrying', { attempt, error: e.message });
      if (attempt === 10) { logger.error('database connection timeout', { error: e.message }); process.exit(1); }
      await new Promise((r) => setTimeout(r, 2000));
    }
  }
  const server = createApp(store).listen(port, () => logger.info('server started', { port, store: store.kind }));
  const shutdown = (sig) => { logger.info('shutting down', { signal: sig }); server.close(() => process.exit(0)); };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}
start();
