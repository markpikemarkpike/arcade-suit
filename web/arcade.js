// Loads arcade.wasm (the costume's own game code) and gives it a small JavaScript face.
//   const a = await Arcade.boot(bytes)      bytes = the contents of arcade.wasm
//   a.menu(now)  a.step(buttons, now)       menu, Maze and Blocks; returns the mode number
//   a.load(luaText, spareBytes)             returns '' or the error text
//   a.frame(buttons)                        one 1/25 s frame of a Lua game; returns '' or the error text
//   a.pixels                                Uint32Array(1024), 0xRRGGBB, row by row
// Buttons are bits: 1 left, 2 right, 4 up, 8 down, 16 A, 32 B.
(function (root) {
  async function boot(bytes) {
    // The C library asks for files and clocks at start-up. There are none: 8 means "no such file handle".
    const quiet = new Proxy({}, { get: (_, name) => name === 'proc_exit' ? () => { throw new Error('exit'); } : name === 'fd_prestat_get' ? () => 8 : () => 0 });
    const { instance } = await WebAssembly.instantiate(bytes, { wasi_snapshot_preview1: quiet });
    const x = instance.exports;
    if (x._initialize) x._initialize();
    const text = (p) => { const m = new Uint8Array(x.memory.buffer); let s = ''; while (m[p]) s += String.fromCharCode(m[p++]); return s; };
    return {
      MAX: x.src_max(),
      get pixels() { return new Uint32Array(x.memory.buffer, x.pixels(), 1024); },
      menu: (now) => x.arcade_menu(now >>> 0),
      step: (held, now) => x.arcade_step(held, now >>> 0),
      load(code, spare) {
        const b = new TextEncoder().encode(code);
        if (b.length > x.src_max()) return 'the program is too long (' + b.length + ' of ' + x.src_max() + ' characters)';
        new Uint8Array(x.memory.buffer, x.src_ptr(), b.length).set(b);
        return x.game_load(b.length, (Math.random() * 4e9) >>> 0, spare == null ? 8192 : spare) ? '' : text(x.error()) || 'it would not start';
      },
      frame: (held) => x.game_step(held) ? '' : text(x.error()) || 'it stopped',
      stop: () => x.game_stop(),
      stats: () => ({ used: x.game_stat(0), peak: x.game_stat(1), spill: x.game_stat(2), worst: x.game_stat(3), frames: x.game_stat(4) }),
    };
  }
  root.Arcade = { boot };
  if (typeof module !== 'undefined') module.exports = root.Arcade;
})(typeof self !== 'undefined' ? self : globalThis);
