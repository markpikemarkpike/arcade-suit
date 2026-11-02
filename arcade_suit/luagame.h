// Arcade Suit: a tiny sandboxed Lua game engine for the 32x32 screen.
// No hardware code lives here, so the same file runs on the M5Stack and in the desktop simulator.
#pragma once
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
extern "C" {
#include "src/lua/lua.h"
#include "src/lua/lauxlib.h"
#include "src/lua/lualib.h"
const luaL_Reg* lg_baselib(void);
const luaL_Reg* lg_mathlib(void);
const luaL_Reg* lg_strlib(void);
const luaL_Reg* lg_tablib(void);
}
#include "games.h"
#include "arena.h"
#ifdef ARDUINO
#include "esp_heap_caps.h"
#endif

static const uint32_t LG_PALETTE[16] = {
    0x000000, 0x00008C, 0x6E006E, 0x006E1E, 0x823C00, 0x3C3C3C, 0x969696, 0xFFFFFF,
    0xFF001E, 0xFF6E00, 0xFFDC00, 0x00FF28, 0x0078FF, 0x6E5ADC, 0xFF50AA, 0xFFAA6E};

// 3x5 font, 15 bits per glyph, top row first, for ASCII 32..90.
static const uint16_t LG_FONT[59] = {
    0x0000, 0x2482, 0x5A00, 0x5F7D, 0x3CF2, 0x52A5, 0x2AAB, 0x2400, 0x1491, 0x4494, 0x55D5, 0x05D0, 0x0014, 0x01C0, 0x0002, 0x12A4,
    0x7B6F, 0x2C97, 0x73E7, 0x73CF, 0x5BC9, 0x79CF, 0x79EF, 0x7249, 0x7BEF, 0x7BCF, 0x0410, 0x0414, 0x1511, 0x0E38, 0x4454, 0x72C2,
    0x7B67, 0x2BED, 0x6BAE, 0x3923, 0x6B6E, 0x79A7, 0x79A4, 0x396B, 0x5BED, 0x7497, 0x126A, 0x5BAD, 0x4927, 0x5FED, 0x6B6D, 0x2B6A,
    0x6BA4, 0x2B73, 0x6BAD, 0x388E, 0x7492, 0x5B6F, 0x5B6A, 0x5BFD, 0x5AAD, 0x5A92, 0x72A7};

class LuaGame {
 public:
  // Lua's memory: first a fixed pool with no per-block overhead, then, if that fills up, the ordinary heap,
  // as long as enough heap stays free for Wi-Fi and Bluetooth. Lua collects garbage and retries before giving up.
  static const size_t POOL_BYTES = 20 * 1024;
  static const size_t MEM_CAP = 48 * 1024;
  static const size_t HEAP_FLOOR = 12 * 1024;
#ifndef ARDUINO
  static inline long HEAP_BUDGET = 8 * 1024;  // Simulator only: how much spare heap to pretend there is.
  long heapReal = 0;
#endif
  static const long FRAME_BUDGET = 300000;   // VM instructions allowed per _update + _draw.
  static const long LOAD_BUDGET = 2000000;   // VM instructions allowed while loading and in _init.
  static const int FPS = 25;

  lua_State* L = nullptr;
  Screen* s = nullptr;
  uint8_t* pool = nullptr;  // Taken from the heap once, early, while one big piece is still easy to get. Never given back.
  Arena arena;
  size_t used = 0, peak = 0, spill = 0, spillPeak = 0;  // spill = bytes that did not fit in the pool.
  long spent = 0, budget = 0, worst = 0;
  uint8_t held = 0, pressed = 0;
  uint32_t frame = 0, seed = 1;
  int camx = 0, camy = 0;
  char err[120] = "";
  const char* code = nullptr;
  size_t codeLen = 0;
  int ref[3] = {LUA_NOREF, LUA_NOREF, LUA_NOREF};

  bool running() const { return L != nullptr; }
  bool reserve() {
    if (!pool) pool = (uint8_t*)malloc(POOL_BYTES);
    return pool != nullptr;
  }

  void close() {
    if (L) lua_close(L);
    L = nullptr;
    used = 0;
    spill = 0;
  }

  // Compiles the script, runs it and calls _init. Returns false and fills err on any problem.
  bool load(const char* src, size_t len, Screen* screen, uint32_t rndSeed) {
    close();
    s = screen; err[0] = 0; peak = 0; worst = 0; frame = 0; held = pressed = 0; camx = camy = 0;
    seed = rndSeed ? rndSeed : 1;
    code = src; codeLen = len;
    ref[0] = ref[1] = ref[2] = LUA_NOREF;
    if (!reserve()) { snprintf(err, sizeof(err), "not enough memory to start"); return false; }
    arena.init(pool, POOL_BYTES);
    spillPeak = 0;
    L = lua_newstate(alloc, this);
    if (!L) { snprintf(err, sizeof(err), "not enough memory to start"); return false; }
    *(LuaGame**)lua_getextraspace(L) = this;
    lua_sethook(L, hook, LUA_MASKCOUNT, 200);
    lua_gc(L, LUA_GCINC, 130, 300, 0);  // Collect early and often: memory is tighter than time.
    spent = 0; budget = LOAD_BUDGET;
    lua_pushcfunction(L, boot);  // Everything that can run out of memory happens inside a protected call.
    if (lua_pcall(L, 0, 0, 0)) return fail();
    code = nullptr;
    return true;
  }

  // One frame. Returns false and fills err if the game broke.
  bool step(uint8_t buttons) {
    if (!L) return false;
    pressed = buttons & ~held;
    held = buttons;
    spent = 0; budget = FRAME_BUDGET;
    camx = camy = 0;
    if (!call(1) || !call(2)) return false;
    if (spent > worst) worst = spent;
    frame++;
    return true;
  }

 private:
  static LuaGame* self(lua_State* L) { return *(LuaGame**)lua_getextraspace(L); }

  void* heapTake(size_t n) {
#ifdef ARDUINO
    if (heap_caps_get_free_size(MALLOC_CAP_8BIT) < n + HEAP_FLOOR) return nullptr;
#else
    if (heapReal + (long)n + 16 > HEAP_BUDGET) return nullptr;
    heapReal += n + 16;
#endif
    void* q = malloc(n);
    if (q) { spill += n; if (spill > spillPeak) spillPeak = spill; }
    return q;
  }
  void heapGive(void* p, size_t o) {
    free(p);
    spill -= o;
#ifndef ARDUINO
    heapReal -= o + 16;
#endif
  }
  void* take(size_t n) {
    void* q = arena.alloc(n);
    return q ? q : heapTake(n);
  }
  void give(void* p, size_t o) {
    if (arena.owns(p)) arena.release(p, o); else heapGive(p, o);
  }
  static void* alloc(void* ud, void* p, size_t o, size_t n) {
    LuaGame* g = (LuaGame*)ud;
    if (!p) o = 0;
    if (n == 0) {
      if (p) g->give(p, o);
      g->used -= o;
      return nullptr;
    }
    if (n > o && g->used - o + n > MEM_CAP) return nullptr;
    void* q = nullptr;
    if (!p) q = g->take(n);
    else if (o == n) q = p;
    else {
      if (g->arena.owns(p)) q = g->arena.resize(p, o, n);
      if (!q) {
        q = g->take(n);
        if (q) { memcpy(q, p, o < n ? o : n); g->give(p, o); }
        else if (n < o) {  // Shrinking must never fail. Only heap blocks get here, and keeping the bigger block is harmless.
          q = p;
          g->spill -= o - n;
#ifndef ARDUINO
          g->heapReal -= o - n;
#endif
        }
      }
    }
    if (!q) return nullptr;
    g->used = g->used - o + n;
    if (g->used > g->peak) g->peak = g->used;
    return q;
  }
  static void hook(lua_State* L, lua_Debug*) {
    LuaGame* g = self(L);
    g->spent += 200;
    if (g->spent > g->budget) luaL_error(L, "too slow: a loop runs too long");
  }
  bool fail() {
    const char* m = lua_type(L, -1) == LUA_TSTRING ? lua_tostring(L, -1) : nullptr;
    snprintf(err, sizeof(err), "%s", m ? m : "unknown error");
    close();
    return false;
  }
  bool call(int k) {
    if (ref[k] == LUA_NOREF) return true;
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref[k]);
    if (lua_pcall(L, 0, 0, 0)) return fail();
    return true;
  }
  // Library functions are not copied into tables at start-up. A table only gets a function the first time a game
  // asks for it. An empty game then needs about half the memory.
  static const luaL_Reg* api() {
    static const luaL_Reg API[] = {
        {"cls", l_cls}, {"pset", l_pset}, {"pget", l_pget}, {"rect", l_rect}, {"rectfill", l_rectfill}, {"line", l_line},
        {"circ", l_circ}, {"circfill", l_circfill}, {"print", l_print}, {"spr", l_spr}, {"camera", l_camera},
        {"btn", l_btn}, {"btnp", l_btnp}, {"rnd", l_rnd}, {"flr", l_flr}, {"ceil", l_ceil}, {"abs", l_abs},
        {"min", l_min}, {"max", l_max}, {"mid", l_mid}, {"sgn", l_sgn}, {"sqrt", l_sqrt}, {"sin", l_sin}, {"cos", l_cos},
        {"time", l_time}, {"t", l_time}, {"rgb", l_rgb}, {"hsv", l_hsv}, {"sfx", l_nop}, {"music", l_nop},
        {"add", l_add}, {"del", l_del}, {"deli", l_deli}, {"count", l_count}, {"all", l_all}, {"foreach", l_foreach},
        {nullptr, nullptr}};
    return API;
  }
  static lua_CFunction find(const luaL_Reg* r, const char* k) {
    for (; r->name; r++) if (r->func && !strcmp(r->name, k)) return r->func;
    return nullptr;
  }
  enum { LIB_GLOBAL, LIB_MATH, LIB_STRING, LIB_TABLE };
  static int lazyIndex(lua_State* L) {  // __index(table, key)
    if (lua_type(L, 2) != LUA_TSTRING) return 0;
    const char* k = lua_tostring(L, 2);
    lua_CFunction f = nullptr;
    switch ((int)lua_tointeger(L, lua_upvalueindex(1))) {
      case LIB_GLOBAL: {
        static const char* const DENY[] = {"dofile", "loadfile", "load", "pcall", "xpcall", "collectgarbage", "print", "warn"};
        f = find(api(), k);
        if (!f && !strcmp(k, "tostr")) f = find(lg_baselib(), "tostring");
        if (!f && !strcmp(k, "tonum")) f = find(lg_baselib(), "tonumber");
        if (!f && !strcmp(k, "sub")) f = find(lg_strlib(), "sub");
        if (!f) {
          for (const char* d : DENY) if (!strcmp(d, k)) return 0;
          f = find(lg_baselib(), k);
        }
        break;
      }
      case LIB_MATH:
        if (!strcmp(k, "random")) f = l_random;
        else if (!strcmp(k, "randomseed")) f = l_nop;
        else if (!strcmp(k, "pi")) { lua_pushnumber(L, (lua_Number)3.14159265358979f); goto keep; }
        else if (!strcmp(k, "huge")) { lua_pushnumber(L, (lua_Number)HUGE_VALF); goto keep; }
        else if (!strcmp(k, "maxinteger")) { lua_pushinteger(L, LUA_MAXINTEGER); goto keep; }
        else if (!strcmp(k, "mininteger")) { lua_pushinteger(L, LUA_MININTEGER); goto keep; }
        else f = find(lg_mathlib(), k);
        break;
      case LIB_STRING: f = find(lg_strlib(), k); break;
      case LIB_TABLE: f = find(lg_tablib(), k); break;
    }
    if (!f) return 0;
    lua_pushcfunction(L, f);
  keep:
    lua_pushvalue(L, 2);
    lua_pushvalue(L, -2);
    lua_rawset(L, 1);  // Remember it, so the next use is as fast as normal.
    return 1;
  }
  static void makeLazy(lua_State* L, int lib) {  // Gives the table on top of the stack a metatable that finds functions on demand.
    lua_createtable(L, 0, 1);
    lua_pushinteger(L, lib);
    lua_pushcclosure(L, lazyIndex, 1);
    lua_setfield(L, -2, "__index");
    lua_setmetatable(L, -2);
  }
  static int boot(lua_State* L) {
    LuaGame* g = self(L);
    lua_pushglobaltable(L);
    makeLazy(L, LIB_GLOBAL);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "_G");
    static const char* const LIBS[3] = {"math", "string", "table"};
    for (int i = 0; i < 3; i++) {
      lua_createtable(L, 0, 0);
      makeLazy(L, LIB_MATH + i);
      if (i == 1) {  // Lets games write s:sub(1, 2) and ("x"):rep(3).
        lua_pushliteral(L, "");
        lua_createtable(L, 0, 1);
        lua_pushvalue(L, -3);
        lua_setfield(L, -2, "__index");
        lua_setmetatable(L, -2);
        lua_pop(L, 1);
      }
      lua_setfield(L, -2, LIBS[i]);
    }
    lua_pop(L, 1);
    if (luaL_loadbufferx(L, g->code, g->codeLen, "=line", "t")) return lua_error(L);
    lua_call(L, 0, 0);
    static const char* const CB[3] = {"_init", "_update", "_draw"};
    for (int k = 0; k < 3; k++) {
      int ty = lua_getglobal(L, CB[k]);
      if (ty != LUA_TFUNCTION && k == 1) { lua_pop(L, 1); ty = lua_getglobal(L, "_update60"); }
      if (ty == LUA_TFUNCTION) g->ref[k] = luaL_ref(L, LUA_REGISTRYINDEX); else lua_pop(L, 1);
    }
    if (g->ref[2] == LUA_NOREF) return luaL_error(L, "the game needs a function _draw()");
    if (g->ref[0] != LUA_NOREF) { lua_rawgeti(L, LUA_REGISTRYINDEX, g->ref[0]); lua_call(L, 0, 0); }
    return 0;
  }

  // ---- list helpers (PICO-8 style) ----
  static int l_add(lua_State* L) {  // add(t, v [, i])
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_Integer n = (lua_Integer)lua_rawlen(L, 1), at = lua_isnoneornil(L, 3) ? n + 1 : (lua_Integer)num(L, 3);
    if (at < 1) at = 1;
    if (at > n + 1) at = n + 1;
    for (lua_Integer j = n; j >= at; j--) { lua_rawgeti(L, 1, j); lua_rawseti(L, 1, j + 1); }
    lua_pushvalue(L, 2);
    lua_rawseti(L, 1, at);
    lua_pushvalue(L, 2);
    return 1;
  }
  static void removeAt(lua_State* L, lua_Integer i, lua_Integer n) {  // Leaves the removed value on the stack.
    lua_rawgeti(L, 1, i);
    for (lua_Integer j = i; j < n; j++) { lua_rawgeti(L, 1, j + 1); lua_rawseti(L, 1, j); }
    lua_pushnil(L);
    lua_rawseti(L, 1, n);
  }
  static int l_del(lua_State* L) {  // del(t, v)
    if (!lua_istable(L, 1)) return 0;
    lua_settop(L, 2);
    lua_Integer n = (lua_Integer)lua_rawlen(L, 1);
    for (lua_Integer i = 1; i <= n; i++) {
      lua_rawgeti(L, 1, i);
      bool same = lua_rawequal(L, -1, 2);
      lua_pop(L, 1);
      if (same) { removeAt(L, i, n); return 1; }
    }
    return 0;
  }
  static int l_deli(lua_State* L) {  // deli(t [, i])
    if (!lua_istable(L, 1)) return 0;
    lua_Integer n = (lua_Integer)lua_rawlen(L, 1), i = lua_isnoneornil(L, 2) ? n : (lua_Integer)num(L, 2);
    if (i < 1 || i > n) return 0;
    removeAt(L, i, n);
    return 1;
  }
  static int l_count(lua_State* L) { lua_pushinteger(L, lua_istable(L, 1) ? (lua_Integer)lua_rawlen(L, 1) : 0); return 1; }
  static int allNext(lua_State* L) {  // upvalues: table, index, previous value
    lua_Integer i = lua_tointeger(L, lua_upvalueindex(2));
    lua_rawgeti(L, lua_upvalueindex(1), i);
    if (i == 0 || lua_rawequal(L, -1, lua_upvalueindex(3))) i++;  // Still there: move on. Gone: the next item slid into this slot.
    lua_pop(L, 1);
    lua_rawgeti(L, lua_upvalueindex(1), i);
    lua_pushinteger(L, i);
    lua_replace(L, lua_upvalueindex(2));
    lua_pushvalue(L, -1);
    lua_replace(L, lua_upvalueindex(3));
    lua_pushvalue(L, -1);
    return 2;  // Twice, so both "for v in all(t)" and "for _,v in all(t)" work.
  }
  static int l_all(lua_State* L) {
    if (!lua_istable(L, 1)) { lua_pushcfunction(L, l_nop); return 1; }
    lua_pushvalue(L, 1);
    lua_pushinteger(L, 0);
    lua_pushnil(L);
    lua_pushcclosure(L, allNext, 3);
    return 1;
  }
  static int l_foreach(lua_State* L) {  // foreach(t, f)
    if (!lua_istable(L, 1)) return 0;
    luaL_checktype(L, 2, LUA_TFUNCTION);
    int guard = 0;
    for (lua_Integer i = 1; i <= (lua_Integer)lua_rawlen(L, 1) && guard < 5000; guard++) {
      lua_rawgeti(L, 1, i);
      lua_pushvalue(L, 2);
      lua_pushvalue(L, -2);
      lua_call(L, 1, 0);
      lua_rawgeti(L, 1, i);
      if (lua_rawequal(L, -1, -2)) i++;
      lua_pop(L, 2);
    }
    return 0;
  }
  static int l_random(lua_State* L) {  // math.random(), math.random(m), math.random(m, n)
    LuaGame* g = self(L);
    g->seed ^= g->seed << 13; g->seed ^= g->seed >> 17; g->seed ^= g->seed << 5;
    if (lua_isnoneornil(L, 1)) { lua_pushnumber(L, (g->seed >> 8) * (1.0f / 16777216.0f)); return 1; }
    lua_Integer lo = 1, hi = (lua_Integer)num(L, 1);
    if (!lua_isnoneornil(L, 2)) { lo = hi; hi = (lua_Integer)num(L, 2); }
    luaL_argcheck(L, lo <= hi, 1, "interval is empty");
    lua_pushinteger(L, lo + (lua_Integer)(g->seed % (uint32_t)(hi - lo + 1)));
    return 1;
  }

  // ---- helpers ----
  static int num(lua_State* L, int i) {
    lua_Number v = luaL_checknumber(L, i);
    if (!(v > -30000 && v < 30000)) return v > 0 ? 30000 : -30000;  // Also catches NaN.
    return (int)floorf(v);
  }
  static int optnum(lua_State* L, int i, int d) { return lua_isnoneornil(L, i) ? d : num(L, i); }
  static uint32_t colour(lua_State* L, int i, int d) {
    if (lua_isnoneornil(L, i)) return LG_PALETTE[d];
    lua_Number v = luaL_checknumber(L, i);
    if (!(v > -1e6f && v < 4e7f)) return 0;
    if (v >= 16777216.0f) return ((uint32_t)lua_tointeger(L, i)) & 0xFFFFFF;
    return LG_PALETTE[((int)floorf(v)) & 15];
  }
  void dot(int x, int y, uint32_t c) { s->set(x - camx, y - camy, c); }
  void hline(int x0, int x1, int y, uint32_t c) {
    y -= camy; x0 -= camx; x1 -= camx;
    if (y < 0 || y > 31) return;
    if (x0 > x1) { int t = x0; x0 = x1; x1 = t; }
    if (x0 < 0) x0 = 0;
    if (x1 > 31) x1 = 31;
    for (int x = x0; x <= x1; x++) s->px[y][x] = c;
  }
  void vline(int x, int y0, int y1, uint32_t c) {
    x -= camx; y0 -= camy; y1 -= camy;
    if (x < 0 || x > 31) return;
    if (y0 > y1) { int t = y0; y0 = y1; y1 = t; }
    if (y0 < 0) y0 = 0;
    if (y1 > 31) y1 = 31;
    for (int y = y0; y <= y1; y++) s->px[y][x] = c;
  }

  // ---- drawing ----
  static int l_nop(lua_State*) { return 0; }
  static int l_cls(lua_State* L) { self(L)->s->clear(colour(L, 1, 0)); return 0; }
  static int l_camera(lua_State* L) { LuaGame* g = self(L); g->camx = optnum(L, 1, 0); g->camy = optnum(L, 2, 0); return 0; }
  static int l_pset(lua_State* L) { self(L)->dot(num(L, 1), num(L, 2), colour(L, 3, 7)); return 0; }
  static int l_pget(lua_State* L) {
    LuaGame* g = self(L);
    int x = num(L, 1) - g->camx, y = num(L, 2) - g->camy;
    if (x < 0 || y < 0 || x > 31 || y > 31) { lua_pushinteger(L, 0); return 1; }
    uint32_t c = g->s->px[y][x];
    for (int i = 0; i < 16; i++) if (LG_PALETTE[i] == c) { lua_pushinteger(L, i); return 1; }
    lua_pushinteger(L, (lua_Integer)(0x1000000 | c));
    return 1;
  }
  static int l_rect(lua_State* L) {
    LuaGame* g = self(L);
    int x0 = num(L, 1), y0 = num(L, 2), x1 = num(L, 3), y1 = num(L, 4);
    uint32_t c = colour(L, 5, 7);
    g->hline(x0, x1, y0, c); g->hline(x0, x1, y1, c); g->vline(x0, y0, y1, c); g->vline(x1, y0, y1, c);
    return 0;
  }
  static int l_rectfill(lua_State* L) {
    LuaGame* g = self(L);
    int x0 = num(L, 1), y0 = num(L, 2), x1 = num(L, 3), y1 = num(L, 4);
    uint32_t c = colour(L, 5, 7);
    if (y0 > y1) { int t = y0; y0 = y1; y1 = t; }
    if (y0 < g->camy) y0 = g->camy;
    if (y1 > g->camy + 31) y1 = g->camy + 31;
    for (int y = y0; y <= y1; y++) g->hline(x0, x1, y, c);
    return 0;
  }
  static int l_line(lua_State* L) {
    LuaGame* g = self(L);
    int x0 = num(L, 1), y0 = num(L, 2), x1 = num(L, 3), y1 = num(L, 4);
    uint32_t c = colour(L, 5, 7);
    int dx = abs(x1 - x0), dy = -abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1, e = dx + dy;
    for (int n = 0; n < 400; n++) {
      g->dot(x0, y0, c);
      if (x0 == x1 && y0 == y1) break;
      int e2 = 2 * e;
      if (e2 >= dy) { e += dy; x0 += sx; }
      if (e2 <= dx) { e += dx; y0 += sy; }
    }
    return 0;
  }
  static int circle(lua_State* L, bool fill) {
    LuaGame* g = self(L);
    int cx = num(L, 1), cy = num(L, 2), r = optnum(L, 3, 4);
    uint32_t c = colour(L, 4, 7);
    if (r < 0) return 0;
    if (r > 64) r = 64;
    int x = r, y = 0, e = 1 - r;
    while (x >= y) {
      if (fill) {
        g->hline(cx - x, cx + x, cy + y, c); g->hline(cx - x, cx + x, cy - y, c);
        g->hline(cx - y, cx + y, cy + x, c); g->hline(cx - y, cx + y, cy - x, c);
      } else {
        g->dot(cx + x, cy + y, c); g->dot(cx - x, cy + y, c); g->dot(cx + x, cy - y, c); g->dot(cx - x, cy - y, c);
        g->dot(cx + y, cy + x, c); g->dot(cx - y, cy + x, c); g->dot(cx + y, cy - x, c); g->dot(cx - y, cy - x, c);
      }
      y++;
      if (e < 0) e += 2 * y + 1; else { x--; e += 2 * (y - x) + 1; }
    }
    return 0;
  }
  static int l_circ(lua_State* L) { return circle(L, false); }
  static int l_circfill(lua_State* L) { return circle(L, true); }
  static int l_print(lua_State* L) {
    LuaGame* g = self(L);
    lua_settop(L, 5);
    int k5 = optnum(L, 5, 1), sc = k5 < 1 ? 1 : k5 > 6 ? 6 : k5;
    char tmp[24];
    const char* str;
    size_t len;
    if (lua_type(L, 1) == LUA_TNUMBER) {
      lua_Number v = lua_tonumber(L, 1);
      if (v == floorf(v) && fabsf(v) < 1e9f) snprintf(tmp, sizeof(tmp), "%ld", (long)v); else snprintf(tmp, sizeof(tmp), "%.1f", (double)v);
      str = tmp; len = strlen(tmp);
    } else {
      str = luaL_tolstring(L, 1, &len);
    }
    int x = optnum(L, 2, 0), y = optnum(L, 3, 0), x0 = x;
    uint32_t c = colour(L, 4, 7);
    if (len > 200) len = 200;
    for (size_t k = 0; k < len; k++) {
      int ch = (unsigned char)str[k];
      if (ch == '\n') { x = x0; y += 6 * sc; continue; }
      if (ch >= 'a' && ch <= 'z') ch -= 32;
      if (ch < 32 || ch > 90) ch = '?';
      uint16_t f = LG_FONT[ch - 32];
      if (x > g->camx - 4 * sc && x < g->camx + 32)
        for (int j = 0; j < 5; j++) for (int i = 0; i < 3; i++) if (f & (1 << (14 - (j * 3 + i))))
          for (int b = 0; b < sc; b++) g->hline(x + i * sc, x + i * sc + sc - 1, y + j * sc + b, c);
      x += 4 * sc;
    }
    lua_pushinteger(L, x);
    return 1;
  }
  // spr(rows, x, y, flip): rows is a table of strings. Each character is one pixel: 0-9 a-f = colour, anything else = see-through.
  static int l_spr(lua_State* L) {
    LuaGame* g = self(L);
    luaL_argcheck(L, lua_istable(L, 1), 1, "spr needs a table of strings, like {\".8.\",\"888\"}");
    int x = num(L, 2), y = num(L, 3);
    bool flip = lua_toboolean(L, 4);
    int n = (int)lua_rawlen(L, 1);
    if (n > 32) n = 32;
    for (int j = 0; j < n; j++) {
      lua_rawgeti(L, 1, j + 1);
      size_t w;
      const char* row = lua_tolstring(L, -1, &w);
      if (row) {
        if (w > 32) w = 32;
        for (size_t i = 0; i < w; i++) {
          int ch = row[i], v = -1;
          if (ch >= '0' && ch <= '9') v = ch - '0';
          else if (ch >= 'a' && ch <= 'f') v = ch - 'a' + 10;
          else if (ch >= 'A' && ch <= 'F') v = ch - 'A' + 10;
          if (v >= 0) g->dot(x + (flip ? (int)(w - 1 - i) : (int)i), y + j, LG_PALETTE[v]);
        }
      }
      lua_pop(L, 1);
    }
    return 0;
  }
  static int l_rgb(lua_State* L) {
    int r = num(L, 1), gg = num(L, 2), b = num(L, 3);
    r = r < 0 ? 0 : r > 255 ? 255 : r; gg = gg < 0 ? 0 : gg > 255 ? 255 : gg; b = b < 0 ? 0 : b > 255 ? 255 : b;
    lua_pushinteger(L, (lua_Integer)(0x1000000 | (r << 16) | (gg << 8) | b));
    return 1;
  }
  // hsv(h, s, v): all 0..1, hue wraps around.
  static int l_hsv(lua_State* L) {
    float h = luaL_checknumber(L, 1), sa = luaL_optnumber(L, 2, 1), v = luaL_optnumber(L, 3, 1);
    if (!(h > -1e6f && h < 1e6f)) h = 0;
    h -= floorf(h);
    sa = sa < 0 ? 0 : sa > 1 ? 1 : sa; v = v < 0 ? 0 : v > 1 ? 1 : v;
    float f = h * 6; int i = (int)f; f -= i;
    float p = v * (1 - sa), q = v * (1 - sa * f), t = v * (1 - sa * (1 - f)), r, gg, b;
    switch (i % 6) {
      case 0: r = v; gg = t; b = p; break;
      case 1: r = q; gg = v; b = p; break;
      case 2: r = p; gg = v; b = t; break;
      case 3: r = p; gg = q; b = v; break;
      case 4: r = t; gg = p; b = v; break;
      default: r = v; gg = p; b = q; break;
    }
    lua_pushinteger(L, (lua_Integer)(0x1000000 | ((int)(r * 255) << 16) | ((int)(gg * 255) << 8) | (int)(b * 255)));
    return 1;
  }

  // ---- input, maths, time ----
  static int button(lua_State* L, uint8_t bits) {
    int i = optnum(L, 1, -1);
    lua_pushboolean(L, i >= 0 && i <= 5 ? (bits >> i) & 1 : (i == -1 && bits));
    return 1;
  }
  static int l_btn(lua_State* L) { return button(L, self(L)->held); }
  static int l_btnp(lua_State* L) { return button(L, self(L)->pressed); }
  static int l_rnd(lua_State* L) {
    LuaGame* g = self(L);
    g->seed ^= g->seed << 13; g->seed ^= g->seed >> 17; g->seed ^= g->seed << 5;
    float u = (g->seed >> 8) * (1.0f / 16777216.0f);
    if (lua_istable(L, 1)) {
      int n = (int)lua_rawlen(L, 1);
      if (!n) { lua_pushnil(L); return 1; }
      lua_rawgeti(L, 1, 1 + (int)(u * n));
      return 1;
    }
    lua_pushnumber(L, u * luaL_optnumber(L, 1, 1));
    return 1;
  }
  static void pushint(lua_State* L, float v) {
    if (v > -2e9f && v < 2e9f) lua_pushinteger(L, (lua_Integer)v); else lua_pushnumber(L, v);
  }
  static int l_flr(lua_State* L) { pushint(L, floorf(luaL_checknumber(L, 1))); return 1; }
  static int l_ceil(lua_State* L) { pushint(L, ceilf(luaL_checknumber(L, 1))); return 1; }
  static int l_abs(lua_State* L) {
    if (lua_isinteger(L, 1)) { lua_Integer v = lua_tointeger(L, 1); lua_pushinteger(L, v < 0 ? -v : v); }
    else lua_pushnumber(L, fabsf(luaL_checknumber(L, 1)));
    return 1;
  }
  static int pick(lua_State* L, int op) {
    int n = lua_gettop(L), best = 1;
    luaL_checknumber(L, 1);
    for (int i = 2; i <= n; i++) {
      luaL_checknumber(L, i);
      if (op < 0 ? lua_compare(L, i, best, LUA_OPLT) : lua_compare(L, best, i, LUA_OPLT)) best = i;
    }
    lua_pushvalue(L, best);
    return 1;
  }
  static int l_min(lua_State* L) { return pick(L, -1); }
  static int l_max(lua_State* L) { return pick(L, 1); }
  static int l_mid(lua_State* L) {
    lua_Number a = luaL_checknumber(L, 1), b = luaL_checknumber(L, 2), c = luaL_checknumber(L, 3);
    int k = (a <= b) ? (b <= c ? 2 : (a <= c ? 3 : 1)) : (a <= c ? 1 : (b <= c ? 3 : 2));
    lua_pushvalue(L, k);
    return 1;
  }
  static int l_sgn(lua_State* L) { lua_pushinteger(L, luaL_checknumber(L, 1) < 0 ? -1 : 1); return 1; }
  static int l_sqrt(lua_State* L) { lua_Number v = luaL_checknumber(L, 1); lua_pushnumber(L, v > 0 ? sqrtf(v) : 0); return 1; }
  static int l_sin(lua_State* L) { lua_pushnumber(L, sinf(luaL_checknumber(L, 1))); return 1; }
  static int l_cos(lua_State* L) { lua_pushnumber(L, cosf(luaL_checknumber(L, 1))); return 1; }
  static int l_time(lua_State* L) { lua_pushnumber(L, self(L)->frame / (float)FPS); return 1; }
};
