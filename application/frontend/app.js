const grid = document.getElementById('products');
const msg = document.getElementById('message');

async function load() {
  try {
    const [products, health] = await Promise.all([
      fetch('/api/products').then((r) => r.json()),
      fetch('/health').then((r) => r.json()),
    ]);
    document.getElementById('version').textContent = 'v' + health.version;
    grid.innerHTML = '';
    for (const p of products) {
      const el = document.createElement('div');
      el.className = 'card';
      const h = document.createElement('h3'); h.textContent = p.name;
      const pr = document.createElement('div'); pr.className = 'price'; pr.textContent = '$' + Number(p.price).toFixed(2);
      const st = document.createElement('div'); st.textContent = p.stock + ' in stock';
      const b = document.createElement('button'); b.textContent = 'Buy 1'; b.disabled = p.stock < 1;
      b.addEventListener('click', () => buy(p.id));
      el.append(h, pr, st, b);
      grid.appendChild(el);
    }
  } catch (e) {
    grid.textContent = 'Could not load products.';
  }
}

async function buy(productId) {
  const r = await fetch('/api/orders', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ productId, quantity: 1 }) });
  const body = await r.json();
  msg.textContent = r.ok ? `Order #${body.id} placed — total $${body.total}` : `Order failed: ${body.error}`;
  load();
}
load();
