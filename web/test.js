// Runs every sample game for 1500 frames of button mashing, then every nasty program. node web/test.js
const fs = require('fs'), path = require('path'), Arcade = require('./arcade.js');
(async () => {
  const a = await Arcade.boot(fs.readFileSync(path.join(__dirname, 'arcade.wasm')));
  const dir = path.join(__dirname, '../gamemaker/games'); let bad = 0;
  for (const f of fs.readdirSync(dir).sort()) {
    let e, lit, lean = false;
    for (;;) {  // Like the suit: if a game does not fit next to Wi-Fi, switch Wi-Fi off (more spare heap) and try again.
      let held = 0; lit = 0; e = a.load(fs.readFileSync(path.join(dir, f), 'utf8'), lean ? 28672 : 8192);
      for (let i = 0; !e && i < 1500; i++) { if (i % 9 == 0) held = Math.random() < .3 ? 0 : 1 << (Math.random() * 6 | 0); e = a.frame(held); if (i % 100 == 0) lit += a.pixels.reduce((n, p) => n + (p ? 1 : 0), 0); }
      if (e == 'not enough memory' && !lean) { lean = true; continue; } break;
    }
    const s = a.stats(); if (e || !lit) bad++;
    console.log((e ? 'FAIL ' : 'ok   ') + f.padEnd(22), 'peak', s.peak, 'spill', s.spill, 'worst', s.worst, lean ? '(Wi-Fi off)' : '', e);
  }
  a.menu(0); let m = 0; for (let t = 0; t < 3000; t += 40) m = a.step(t == 400 ? 16 : 0, t);
  console.log('menu -> A gives mode', m, '(1 = maze)');
  // Nasty programs. Each must either run harmlessly or stop with an error message. None may crash the engine.
  const hd = path.join(__dirname, '../test/hostile');
  for (const f of fs.readdirSync(hd).sort()) {
    let e = a.load(fs.readFileSync(path.join(hd, f), 'latin1'), 8192); for (let i = 0; !e && i < 300; i++) e = a.frame(i % 5 ? 0 : 16);
    console.log('hostile', f.padEnd(20), '->', e || 'ran harmlessly');
  }
  let e = a.load(fs.readFileSync(path.join(dir, '00_example.lua'), 'utf8'), 8192); for (let i = 0; !e && i < 100; i++) e = a.frame(0);
  console.log('still healthy afterwards:', e || 'yes'); if (e) bad++;
  process.exit(bad ? 1 : 0);
})();
