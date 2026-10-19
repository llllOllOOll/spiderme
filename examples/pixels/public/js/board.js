// Pixels: the board on a 48x48 canvas, painted with the selected color.
(function () {
  'use strict';

  const SIZE = 48;
  const COLORS = ['#ff004d', '#ffa300', '#ffec27', '#00e436', '#29adff', '#83769c', '#ff77a8', '#fff1e8'];
  const EMPTY = '#1a1c2c';

  const canvas = document.getElementById('board');
  const ctx = canvas.getContext('2d');
  const palette = document.querySelectorAll('[data-palette] [data-color]');
  let color = 0;

  ctx.fillStyle = EMPTY;
  ctx.fillRect(0, 0, SIZE, SIZE);

  function paint(x, y, c) {
    ctx.fillStyle = COLORS[c];
    ctx.fillRect(x, y, 1, 1);
  }

  function select(c) {
    color = c;
    palette.forEach(b => {
      const on = Number(b.dataset.color) === c;
      b.classList.toggle('ring-4', on);
      b.classList.toggle('ring-white', on);
      b.classList.toggle('scale-110', on);
      b.setAttribute('aria-checked', on ? 'true' : 'false');
    });
  }
  palette.forEach(b => {
    b.setAttribute('role', 'radio');
    b.addEventListener('click', () => select(Number(b.dataset.color)));
  });
  select(0);

  // The cell under the pointer, or null outside the board.
  function cell(e) {
    const r = canvas.getBoundingClientRect();
    const x = Math.floor((e.clientX - r.left) / r.width * SIZE);
    const y = Math.floor((e.clientY - r.top) / r.height * SIZE);
    return x >= 0 && y >= 0 && x < SIZE && y < SIZE ? { x, y } : null;
  }

  let drawing = false;
  let last = '';
  function stroke(e) {
    const p = cell(e);
    if (!p || p.x + ',' + p.y === last) return;
    last = p.x + ',' + p.y;
    paint(p.x, p.y, color);
    painted(p.x, p.y);
    send(p.x + ',' + p.y + ',' + color);
  }
  canvas.addEventListener('pointerdown', e => {
    drawing = true;
    last = '';
    canvas.setPointerCapture(e.pointerId);
    stroke(e);
  });
  canvas.addEventListener('pointermove', e => { if (drawing) stroke(e); });
  canvas.addEventListener('pointerup', () => { drawing = false; });
  canvas.addEventListener('pointercancel', () => { drawing = false; });

  // ── Real time: everyone paints the same board ─────────────────────
  // The server sends "board:" first: one character per cell ('-' for an
  // empty one), then one per cell with the time it has left, in steps of
  // 15 seconds. Then every "x,y,color" anybody paints. A pixel lasts 15
  // minutes; each browser clears it when its time is up.
  const LIFETIME_MS = 15 * 60 * 1000;
  const STEP_MS = 15 * 1000;
  const expires = new Array(SIZE * SIZE).fill(0);

  let socket = null;
  function send(msg) {
    if (socket && socket.readyState === WebSocket.OPEN) socket.send(msg);
  }
  function clear(i) {
    expires[i] = 0;
    ctx.fillStyle = EMPTY;
    ctx.fillRect(i % SIZE, Math.floor(i / SIZE), 1, 1);
  }
  function drawAll(board) {
    const now = Date.now();
    for (let i = 0; i < SIZE * SIZE; i++) {
      const ch = board[i];
      if (ch === undefined || ch === '-') { clear(i); continue; }
      paint(i % SIZE, Math.floor(i / SIZE), Number(ch));
      const steps = board.charCodeAt(SIZE * SIZE + i) - 48;
      expires[i] = now + (steps > 0 ? steps : 60) * STEP_MS;
    }
  }
  function painted(x, y) {
    expires[y * SIZE + x] = Date.now() + LIFETIME_MS;
  }
  setInterval(() => {
    const now = Date.now();
    for (let i = 0; i < expires.length; i++) {
      if (expires[i] && expires[i] <= now) clear(i);
    }
  }, 1000);
  const count = document.querySelector('[data-online-count]');
  const label = document.querySelector('[data-online-label]');
  function showOnline(n) {
    if (String(n) === count.textContent) return;
    count.textContent = n;
    label.textContent = n === 1 ? 'person painting now' : 'people painting now';
    count.classList.add('scale-150', 'text-success');
    setTimeout(() => count.classList.remove('scale-150', 'text-success'), 300);
  }

  function connect() {
    socket = new WebSocket((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/ws');
    socket.addEventListener('message', e => {
      const msg = String(e.data);
      if (msg.startsWith('board:')) { drawAll(msg.slice(6)); return; }
      if (msg.startsWith('online:')) { showOnline(Number(msg.slice(7))); return; }
      const [x, y, c] = msg.split(',').map(Number);
      if (c >= 0 && c < COLORS.length) { paint(x, y, c); painted(x, y); }
    });
    socket.addEventListener('close', () => setTimeout(connect, 1000));
  }
  connect();

  window.pixels = { paint, select, SIZE, COLORS };
})();
