# Third-party notices

This repo's own files are MIT (see `LICENSE`). These parts belong to other people.

## In the repo as source

| What | Where | License |
|---|---|---|
| Lua 5.4.6, trimmed and lightly changed | `arcade_suit/src/lua/` | MIT. Copyright (C) 1994-2023 Lua.org, PUC-Rio. Full text at the end of `lua.h`. Changes are listed in that folder's README. |
| A patch to the ESP32 Arduino core's WebServer library | `patches/` | LGPL-2.1-or-later. Copyright (c) 2015 Ivan Grokhotkov. See `patches/README.md`. |

## Inside `web/arcade.wasm`

That file is built by `web/build.sh` with the Zig toolchain. Besides this repo's code it contains:

| What | License |
|---|---|
| Lua 5.4.6 | MIT, as above |
| wasi-libc, including parts of musl, dlmalloc and cloudlibc | Apache-2.0 WITH LLVM-exception, MIT, CC0 and BSD-2-Clause. https://github.com/WebAssembly/wasi-libc |
| Zig's compiler runtime | MIT. https://github.com/ziglang/zig |

## Downloaded when you build the firmware. Not in this repo.

| What | License |
|---|---|
| Bluepad32 | Apache-2.0 |
| BTstack, which Bluepad32 links | Free for open source projects, commercial otherwise. See https://github.com/ricardoquesada/bluepad32#license |
| Arduino core for the ESP32 | LGPL-2.1-or-later, on top of ESP-IDF (Apache-2.0) |
| FastLED, M5Unified, M5GFX | MIT |

If you hand a compiled firmware file to someone else, those licenses apply to you. That is why there is no firmware binary here.
