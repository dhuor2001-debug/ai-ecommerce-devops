// Data layer. Uses PostgreSQL when DATABASE_URL is set; otherwise an in-memory store
// so the app (and tests) run with zero dependencies.
const { Pool } = require('pg');
const logger = require('./logger');

const SEED = [
  { id: 1, name: 'Wireless Headphones', price: 79.99, stock: 25 },
  { id: 2, name: 'Mechanical Keyboard', price: 109.0, stock: 12 },
  { id: 3, name: 'USB-C Hub', price: 34.5, stock: 40 },
  { id: 4, name: '27" Monitor', price: 229.0, stock: 8 },
];

function memoryStore() {
  const products = SEED.map((p) => ({ ...p }));
  const orders = [];
  return {
    kind: 'memory',
    async init() {},
    async ping() { return true; },
    async listProducts() { return products; },
    async getProduct(id) { return products.find((p) => p.id === id) || null; },
    async createOrder(productId, quantity) {
      const p = products.find((x) => x.id === productId);
      if (!p) return { error: 'product_not_found' };
      if (p.stock < quantity) return { error: 'insufficient_stock' };
      p.stock -= quantity;
      const order = { id: orders.length + 1, productId, quantity, total: +(p.price * quantity).toFixed(2), createdAt: new Date().toISOString() };
      orders.push(order);
      return { order };
    },
    async listOrders() { return orders; },
  };
}

function postgresStore(url) {
  const pool = new Pool({ connectionString: url, connectionTimeoutMillis: 3000 });
  pool.on('error', (err) => logger.error('database connection error', { error: err.message }));
  return {
    kind: 'postgres',
    async init() {
      await pool.query(`CREATE TABLE IF NOT EXISTS products (id SERIAL PRIMARY KEY, name TEXT NOT NULL, price NUMERIC(10,2) NOT NULL, stock INT NOT NULL)`);
      await pool.query(`CREATE TABLE IF NOT EXISTS orders (id SERIAL PRIMARY KEY, product_id INT REFERENCES products(id), quantity INT NOT NULL, total NUMERIC(10,2) NOT NULL, created_at TIMESTAMPTZ DEFAULT now())`);
      const { rows } = await pool.query('SELECT count(*)::int AS n FROM products');
      if (rows[0].n === 0) {
        for (const p of SEED) {
          await pool.query('INSERT INTO products (id, name, price, stock) VALUES ($1,$2,$3,$4)', [p.id, p.name, p.price, p.stock]);
        }
        await pool.query("SELECT setval('products_id_seq', (SELECT max(id) FROM products))");
      }
    },
    async ping() { await pool.query('SELECT 1'); return true; },
    async listProducts() {
      const { rows } = await pool.query('SELECT id, name, price::float, stock FROM products ORDER BY id');
      return rows;
    },
    async getProduct(id) {
      const { rows } = await pool.query('SELECT id, name, price::float, stock FROM products WHERE id=$1', [id]);
      return rows[0] || null;
    },
    async createOrder(productId, quantity) {
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        const { rows } = await client.query('SELECT id, price::float, stock FROM products WHERE id=$1 FOR UPDATE', [productId]);
        if (!rows[0]) { await client.query('ROLLBACK'); return { error: 'product_not_found' }; }
        if (rows[0].stock < quantity) { await client.query('ROLLBACK'); return { error: 'insufficient_stock' }; }
        await client.query('UPDATE products SET stock = stock - $1 WHERE id=$2', [quantity, productId]);
        const total = +(rows[0].price * quantity).toFixed(2);
        const ins = await client.query('INSERT INTO orders (product_id, quantity, total) VALUES ($1,$2,$3) RETURNING id, created_at', [productId, quantity, total]);
        await client.query('COMMIT');
        return { order: { id: ins.rows[0].id, productId, quantity, total, createdAt: ins.rows[0].created_at } };
      } catch (e) {
        await client.query('ROLLBACK');
        throw e;
      } finally {
        client.release();
      }
    },
    async listOrders() {
      const { rows } = await pool.query('SELECT id, product_id AS "productId", quantity, total::float, created_at AS "createdAt" FROM orders ORDER BY id DESC LIMIT 100');
      return rows;
    },
  };
}

module.exports = function createStore() {
  return process.env.DATABASE_URL ? postgresStore(process.env.DATABASE_URL) : memoryStore();
};
