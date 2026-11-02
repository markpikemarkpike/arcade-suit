// The same game code that runs on the M5Stack, compiled to WebAssembly so it can run in a browser tab.
// games.h (menu, Maze, Blocks) and luagame.h (the Lua sandbox) are included unchanged.
#include "../arcade_suit/luagame.h"
#define EXPORT(n) extern "C" __attribute__((export_name(#n)))

static Arcade arcade;
static LuaGame lua;
static char src[7000];

EXPORT(src_ptr)  char* src_ptr() { return src; }
EXPORT(src_max)  int src_max() { return sizeof src; }
EXPORT(pixels)   uint32_t* pixels() { return &arcade.s.px[0][0]; }
EXPORT(error)    const char* error() { return lua.err; }

// Menu, Maze and Blocks. Returns the mode: 0 menu, 1 maze, 2 blocks, 3 score screen, 4 magic.
EXPORT(arcade_step) int arcade_step(int held, uint32_t now) { arcade.update((uint8_t)held, now); return arcade.mode; }
EXPORT(arcade_menu) void arcade_menu(uint32_t now) { lua.close(); arcade.mode = Arcade::MENU; arcade.prev = 0xFF; arcade.idleSince = now; }

// Magic mode. spare = how many bytes of ordinary heap to pretend are free once the 20 KB pool is full.
EXPORT(game_load) int game_load(int len, uint32_t seed, int spare) {
  LuaGame::HEAP_BUDGET = spare;
  lua.reserve();
  arcade.s.clear();
  return lua.load(src, len, &arcade.s, seed) ? 1 : 0;
}
EXPORT(game_step) int game_step(int held) { return lua.step((uint8_t)held) ? 1 : 0; }
EXPORT(game_stop) void game_stop() { lua.close(); }
EXPORT(game_stat) long game_stat(int i) {
  switch (i) { case 0: return lua.used; case 1: return lua.peak; case 2: return lua.spillPeak; case 3: return lua.worst; case 4: return lua.frame; }
  return 0;
}
