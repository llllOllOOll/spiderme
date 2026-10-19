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
  // The server sends "board:" + one character per cell first ('-' for an
  // empty one), then every "x,y,color" anybody paints.
  let socket = null;
  function send(msg) {
    if (socket && socket.readyState === WebSocket.OPEN) socket.send(msg);
  }
  function drawAll(cells) {
    for (let i = 0; i < cells.length && i < SIZE * SIZE; i++) {
      const ch = cells[i];
      if (ch === '-') { ctx.fillStyle = EMPTY; ctx.fillRect(i % SIZE, Math.floor(i / SIZE), 1, 1); }
      else paint(i % SIZE, Math.floor(i / SIZE), Number(ch));
    }
  }
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
      if (c >= 0 && c < COLORS.length) paint(x, y, c);
    });
    socket.addEventListener('close', () => setTimeout(connect, 1000));
  }
  connect();

  window.pixels = { paint, select, SIZE, COLORS };
})();
