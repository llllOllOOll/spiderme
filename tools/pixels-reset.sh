#!/usr/bin/env bash
# Clears the Pixels board (pixels.spiderme.org) for everyone, without a
# restart: reads PIXELS_RESET_TOKEN from the server (deploy.sh made it) and
# sends "reset:<token>" on the board's socket. The token is never printed.
# Needs Node 22 or newer (its WebSocket).
set -euo pipefail

SERVER="${SERVER:-seven@spiderme.org}"
URL="${URL:-wss://pixels.spiderme.org/ws}"

ssh -o BatchMode=yes "$SERVER" "grep '^PIXELS_RESET_TOKEN=' ~/.config/spiderme-deploy/spiderme-pixels.env | cut -d= -f2-" |
    URL="$URL" node -e '
let token = "";
process.stdin.on("data", d => token += d);
process.stdin.on("end", () => {
  token = token.trim();
  if (!token) { console.error("no PIXELS_RESET_TOKEN on the server: deploy pixels first"); process.exit(1); }
  const ws = new WebSocket(process.env.URL);
  let snapshots = 0;
  ws.onopen = () => ws.send("reset:" + token);
  ws.onmessage = e => {
    const msg = String(e.data);
    if (!msg.startsWith("board:")) return;
    // The first snapshot is the board on joining; the second is the reset.
    if (++snapshots === 2 || !/[0-7]/.test(msg.slice(6, 6 + 48 * 48))) {
      console.log("board cleared");
      ws.close();
      process.exit(0);
    }
  };
  ws.onerror = () => { console.error("could not reach " + process.env.URL); process.exit(1); };
  setTimeout(() => { console.error("no answer: is the token right?"); process.exit(1); }, 8000);
});
'
