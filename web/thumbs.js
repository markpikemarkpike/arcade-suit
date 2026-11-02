// Prints {name: PNG data URL} for the named sample games, each photographed after 90 frames. Used by gamemaker/build_page.py.
const fs = require('fs'), path = require('path'), zlib = require('zlib'), Arcade = require('./arcade.js');
const lift = v => v ? Math.round(255 * Math.pow(v / 255, .6)) : 0;
function crc(b) { let c, n = ~0; for (const x of b) { c = (n ^ x) & 255; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; n = (n >>> 8) ^ c; } return ~n >>> 0; }
function chunk(t, d) { const l = Buffer.alloc(4), c = Buffer.alloc(4), b = Buffer.concat([Buffer.from(t), d]); l.writeUInt32BE(d.length); c.writeUInt32BE(crc(b)); return Buffer.concat([l, b, c]); }
function png(px) {
  const raw = Buffer.alloc(32 * 97); for (let y = 0; y < 32; y++) for (let x = 0; x < 32; x++) { const p = px[y * 32 + x], o = y * 97 + 1 + x * 3; raw[o] = lift(p >> 16 & 255); raw[o + 1] = lift(p >> 8 & 255); raw[o + 2] = lift(p & 255); }
  const h = Buffer.alloc(13); h.writeUInt32BE(32, 0); h.writeUInt32BE(32, 4); h[8] = 8; h[9] = 2;
  return 'data:image/png;base64,' + Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', h), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]).toString('base64');
}
(async () => {
  const a = await Arcade.boot(fs.readFileSync(path.join(__dirname, 'arcade.wasm'))), out = {};
  for (const n of process.argv.slice(2)) {
    if (a.load(fs.readFileSync(path.join(__dirname, '../gamemaker/games', n + '.lua'), 'utf8'), 28672)) continue;
    for (let i = 0; i < 90; i++) a.frame(i == 5 || i % 14 == 0 ? 16 : 0);
    out[n] = png(a.pixels);
  }
  console.log(JSON.stringify(out));
})();
