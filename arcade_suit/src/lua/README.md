# Lua 5.4.6, trimmed

This is Lua 5.4.6 from https://www.lua.org, Copyright (C) 1994-2023 Lua.org, PUC-Rio, under the MIT license.
The full notice is at the end of `lua.h`.

What was changed to fit an ESP32 that is also running Bluetooth and Wi-Fi:

- `luaconf.h`: `LUA_32BITS 1` (32-bit integers and floats), `LUAI_MAXSTACK 6000`.
- `llimits.h`: `LUAI_MAXCCALLS 32`.
- `lobject.c`: whole floats print as `3`, not `3.0`, so scores look right.
- `lbaselib.c`, `lmathlib.c`, `lstrlib.c`, `ltablib.c`: a small accessor at the end of each (`lg_baselib` and friends) so `luagame.h` can look functions up on first use instead of loading every library up front.
- Left out: `liolib`, `loslib`, `loadlib`, `lcorolib`, `ldblib`, `lutf8lib`, `linit`, `lua.c`, `luac.c`.
