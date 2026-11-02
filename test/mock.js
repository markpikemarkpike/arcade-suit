// A pretend suit: serves the real page and runs uploads through the real engine (web/arcade.wasm).
const http = require('http'), fs = require('fs'), path = require('path'), Arcade = require('../web/arcade.js');
let st = { state: 'idle', error: '', frames: 0, heap: 50000, minheap: 40000, block: 30000, lua: 0, spill: 0, worst: 0, pad: 1, net: 'hotspot', version: 'mock' }, log = [], eng;
module.exports = { log, st, async start(port) {
  eng = await Arcade.boot(fs.readFileSync(path.join(__dirname, '../web/arcade.wasm')));
  return new Promise(r => { const s = http.createServer((q, a) => {
    const chunks = []; q.on('data', c => chunks.push(c)); q.on('end', () => { const body = Buffer.concat(chunks); log.push(q.method + ' ' + q.url);
      if (q.url == '/') { a.writeHead(200, { 'content-type': 'text/html' }); return a.end(fs.readFileSync(path.join(__dirname, '../gamemaker/page.html'))); }
      if (q.url == '/status') { a.writeHead(200, { 'content-type': 'application/json' }); return a.end(JSON.stringify(st)); }
      if (q.url == '/screen') { a.writeHead(200, { 'content-type': 'application/octet-stream' }); const p = eng.pixels; return a.end(Buffer.from(p.buffer.slice(p.byteOffset, p.byteOffset + 4096))); }
      if (q.url == '/busy') { st.state = 'busy'; st.error = ''; return a.end('ok'); }
      if (q.url == '/idle') { st.state = 'idle'; return a.end('ok'); }
      if (q.url == '/code') { a.writeHead(404); return a.end(''); }
      if (q.url == '/scan') { a.writeHead(200, { 'content-type': 'application/json' }); return a.end(JSON.stringify(['Sam’s iPhone', 'Home "5G"'])); }
      if (q.url == '/wifi') { log.push('wifi ' + body.toString()); return a.end('ok'); }
      if (q.url == '/game') {
        const t = body.toString('latin1'), i = t.indexOf('\r\n\r\n') + 4, b = t.slice(0, t.indexOf('\r\n')), j = t.lastIndexOf('\r\n' + b);
        let e = eng.load(Buffer.from(t.slice(i, j), 'latin1').toString('utf8'), 8192);
        if (e) { log.push('engine: load: ' + e); st.state = 'error'; st.error = e; a.writeHead(400); return a.end(e); }
        for (let f = 0; !e && f < 150; f++) e = eng.frame(f % 11 == 0 ? 16 : f % 7 == 0 ? 2 : 0);
        log.push('engine: ' + (e || 'ok'));
        st.state = e ? 'error' : 'playing'; st.error = e; return a.end('ok');
      }
      a.writeHead(404); a.end(); }); });
    s.listen(port, () => r(s)); });
} };
