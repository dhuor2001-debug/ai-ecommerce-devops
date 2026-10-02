// Structured JSON logs to stdout so Docker/Kubernetes/Filebeat can ship them to ELK.
const LEVELS = { debug: 10, info: 20, warn: 30, error: 40 };
const threshold = LEVELS[process.env.LOG_LEVEL || 'info'] ?? 20;

function log(level, message, extra = {}) {
  if (LEVELS[level] < threshold) return;
  process.stdout.write(
    JSON.stringify({
      '@timestamp': new Date().toISOString(),
      level,
      service: 'ecommerce-backend',
      version: process.env.APP_VERSION || 'dev',
      message,
      ...extra,
    }) + '\n'
  );
}

module.exports = {
  debug: (m, e) => log('debug', m, e),
  info: (m, e) => log('info', m, e),
  warn: (m, e) => log('warn', m, e),
  error: (m, e) => log('error', m, e),
};
