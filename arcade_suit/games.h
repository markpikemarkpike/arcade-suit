// Arcade Suit: game logic for a 32x32 screen. No hardware code lives here,
// so the same file runs on the M5Stack Basic and in the desktop simulator.
#pragma once
#include <stdint.h>
#include <string.h>

enum : uint8_t { BTN_LEFT = 1, BTN_RIGHT = 2, BTN_UP = 4, BTN_DOWN = 8, BTN_A = 16, BTN_B = 32 };

inline uint32_t rgb(uint8_t r, uint8_t g, uint8_t b) { return ((uint32_t)r << 16) | ((uint32_t)g << 8) | b; }

class Random {
 public:
  uint32_t s = 12345;
  void seed(uint32_t v) { s = v ? v : 1; }
  uint32_t next() { s ^= s << 13; s ^= s >> 17; s ^= s << 5; return s; }
  int upTo(int n) { return next() % n; }
};

struct Screen {
  uint32_t px[32][32];
  void clear(uint32_t c = 0) { for (auto& row : px) for (auto& p : row) p = c; }
  void set(int x, int y, uint32_t c) { if (x >= 0 && y >= 0 && x < 32 && y < 32) px[y][x] = c; }
  void rect(int x, int y, int w, int h, uint32_t c) { for (int j = 0; j < h; j++) for (int i = 0; i < w; i++) set(x + i, y + j, c); }
  void digit(int x, int y, int d, uint32_t c) {
    static const uint16_t F[10] = {0x7B6F, 0x2C97, 0x73E7, 0x73CF, 0x5BC9, 0x79CF, 0x79EF, 0x7249, 0x7BEF, 0x7BCF};
    for (int j = 0; j < 5; j++) for (int i = 0; i < 3; i++)
      if (F[d] & (1 << (14 - (j * 3 + i)))) set(x + i, y + j, c);
  }
  void number(int cx, int y, long n, uint32_t c) {
    char t[9]; int k = 0;
    if (n <= 0) t[k++] = 0;
    while (n > 0 && k < 7) { t[k++] = n % 10; n /= 10; }
    int x = cx - (k * 4 - 1) / 2;
    for (int i = k - 1; i >= 0; i--) { digit(x, y, t[i], c); x += 4; }
  }
};

// ---------------------------------------------------------------- Maze game
class Maze {
 public:
  bool wall[31][32];
  uint8_t dot[31][32];
  int px, py, dx, dy, wx, wy, lives, left, tick;
  long score;
  int brave;
  bool over, won;
  struct Spook { int x, y, dx, dy; } g[3];
  Random* r;

  void carve(int x, int y) {
    static const int8_t D[4][2] = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
    wall[y][x] = false;
    int o[4] = {0, 1, 2, 3};
    for (int i = 3; i > 0; i--) { int j = r->upTo(i + 1); int t = o[i]; o[i] = o[j]; o[j] = t; }
    for (int i = 0; i < 4; i++) {
      int a = D[o[i]][0], b = D[o[i]][1], n = x + 2 * a, m = y + 2 * b;
      if (n >= 1 && n <= 15 && m >= 1 && m <= 29 && wall[m][n]) { wall[y + b][x + a] = false; carve(n, m); }
    }
  }
  bool open(int x, int y) const { return x >= 0 && y >= 0 && x < 32 && y < 31 && !wall[y][x]; }
  void place() {
    px = 15; py = 15; dx = dy = wx = wy = 0; brave = 0;
    g[0] = {1, 15, 0, 1}; g[1] = {30, 15, 0, 1}; g[2] = {15, 1, 0, 1};
  }
  void start(Random* rnd) {
    r = rnd;
    memset(wall, 1, sizeof(wall));
    carve(1, 1);
    for (int y = 1; y < 30; y++) for (int x = 1; x < 16; x++)
      if (((x + y) & 1) && wall[y][x] && r->upTo(10) < 3) wall[y][x] = false;
    for (int y = 0; y < 31; y++) for (int x = 0; x < 16; x++) wall[y][31 - x] = wall[y][x];
    left = 0;
    for (int y = 0; y < 31; y++) for (int x = 0; x < 32; x++) { dot[y][x] = wall[y][x] ? 0 : 1; }
    dot[1][1] = dot[1][30] = dot[29][1] = dot[29][30] = 2;
    dot[15][15] = 0;
    for (auto& row : dot) for (uint8_t d : row) if (d) left++;
    score = 0; lives = 3; tick = 0; over = won = false;
    place();
  }
  void input(uint8_t held) {
    if (held & BTN_LEFT) { wx = -1; wy = 0; }
    else if (held & BTN_RIGHT) { wx = 1; wy = 0; }
    else if (held & BTN_UP) { wx = 0; wy = -1; }
    else if (held & BTN_DOWN) { wx = 0; wy = 1; }
  }
  void hit() {
    for (auto& q : g) if (q.x == px && q.y == py) {
      if (brave) { score += 50; q = {15, 1, 0, 1}; }
      else { if (--lives <= 0) over = true; else place(); return; }
    }
  }
  void moveSpook(Spook& q) {
    static const int8_t D[4][2] = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
    int8_t c[4]; int n = 0, back = -1;
    for (int i = 0; i < 4; i++) if (open(q.x + D[i][0], q.y + D[i][1])) {
      if (D[i][0] == -q.dx && D[i][1] == -q.dy) back = i; else c[n++] = i;
    }
    if (!n) { if (back < 0) return; c[n++] = back; }
    int p = c[r->upTo(n)];
    if (!brave && r->upTo(100) < 55) {
      int best = 9999;
      for (int i = 0; i < n; i++) {
        int k = c[i], d = abs2(q.x + D[k][0] - px) + abs2(q.y + D[k][1] - py);
        if (d < best) { best = d; p = k; }
      }
    }
    q.dx = D[p][0]; q.dy = D[p][1]; q.x += q.dx; q.y += q.dy;
  }
  static int abs2(int v) { return v < 0 ? -v : v; }
  void step() {
    if (over || won) return;
    tick++;
    if ((wx || wy) && open(px + wx, py + wy)) { dx = wx; dy = wy; }
    if (open(px + dx, py + dy)) { px += dx; py += dy; }
    uint8_t v = dot[py][px];
    if (v) { score += v == 2 ? 20 : 1; if (v == 2) brave = 45; dot[py][px] = 0; left--; }
    hit();
    if (over) return;
    if (left <= 0) { won = true; return; }
    if (brave) brave--;
    bool skip = brave ? tick % 2 == 0 : tick % 4 == 0;
    if (!skip) for (auto& q : g) moveSpook(q);
    hit();
  }
  void draw(Screen& s) const {
    s.clear();
    for (int y = 0; y < 31; y++) for (int x = 0; x < 32; x++) {
      if (wall[y][x]) s.px[y][x] = rgb(95, 30, 175);
      else if (dot[y][x] == 1) s.px[y][x] = rgb(15, 80, 70);
      else if (dot[y][x] == 2) s.px[y][x] = tick % 6 < 3 ? rgb(60, 255, 90) : rgb(230, 255, 230);
    }
    for (int i = 0; i < lives * 2; i++) s.px[31][i] = rgb(255, 120, 0);
    static const uint32_t C[3] = {0xF4F4FF, 0xC4FFDC, 0xE2C8FF};  // Three pale spooks.
    for (int i = 0; i < 3; i++) s.set(g[i].x, g[i].y, brave ? (tick % 4 < 2 ? rgb(70, 70, 85) : rgb(18, 18, 24)) : C[i]);
    s.set(px, py, rgb(255, 120, 0));  // You are the pumpkin.
  }
};

// ------------------------------------------------------------------- Blocks
class Blocks {
 public:
  static const int W = 10, H = 15;
  uint32_t b[H][W];
  struct Piece { int8_t c[4][2]; uint32_t color; int x, y; } p, nx;
  int lines; long score; bool over;
  Random* r;

  void make(Piece& q) {
    static const int8_t S[7][4][2] = {
      {{0,1},{1,1},{2,1},{3,1}}, {{1,0},{2,0},{1,1},{2,1}}, {{1,0},{0,1},{1,1},{2,1}},
      {{1,0},{2,0},{0,1},{1,1}}, {{0,0},{1,0},{1,1},{2,1}}, {{0,0},{0,1},{1,1},{2,1}}, {{2,0},{0,1},{1,1},{2,1}}};
    static const uint32_t C[7] = {0xFF5FA2, 0x7CFF4F, 0xFF8C1A, 0x4FD8FF, 0xFFE14F, 0xC9A0FF, 0xF4F4FF};  // Candy colours.
    int k = r->upTo(7);
    memcpy(q.c, S[k], sizeof(q.c)); q.color = C[k]; q.x = 3; q.y = 0;
  }
  bool fit(const int8_t c[4][2], int x, int y) const {
    for (int i = 0; i < 4; i++) {
      int u = c[i][0] + x, v = c[i][1] + y;
      if (u < 0 || u >= W || v >= H) return false;
      if (v >= 0 && b[v][u]) return false;
    }
    return true;
  }
  void start(Random* rnd) { r = rnd; memset(b, 0, sizeof(b)); lines = 0; score = 0; over = false; make(p); make(nx); }
  void lock() {
    for (auto& c : p.c) { int v = c[1] + p.y; if (v >= 0) b[v][c[0] + p.x] = p.color; }
    int n = 0;
    for (int y = H - 1; y >= 0; y--) {
      bool full = true;
      for (int x = 0; x < W; x++) if (!b[y][x]) full = false;
      if (full) {
        for (int j = y; j > 0; j--) memcpy(b[j], b[j - 1], sizeof(b[0]));
        memset(b[0], 0, sizeof(b[0])); n++; y++;
      }
    }
    static const int P[5] = {0, 100, 300, 500, 800};
    lines += n; score += P[n];
    p = nx; make(nx);
    if (!fit(p.c, p.x, p.y)) over = true;
  }
  int fallMs() const { int t = 600 - lines * 25; return t < 160 ? 160 : t; }
  void fall() { if (over) return; if (fit(p.c, p.x, p.y + 1)) p.y++; else lock(); }
  void move(int d) { if (!over && fit(p.c, p.x + d, p.y)) p.x += d; }
  void rotate() {
    if (over) return;
    int m = 0;
    for (auto& c : p.c) { if (c[0] > m) m = c[0]; if (c[1] > m) m = c[1]; }
    int8_t n[4][2];
    for (int i = 0; i < 4; i++) { n[i][0] = m - p.c[i][1]; n[i][1] = p.c[i][0]; }
    static const int8_t K[5] = {0, -1, 1, -2, 2};
    for (int k : K) if (fit(n, p.x + k, p.y)) { memcpy(p.c, n, sizeof(n)); p.x += k; return; }
  }
  void drop() { if (over) return; while (fit(p.c, p.x, p.y + 1)) { p.y++; score += 2; } lock(); }
  static void cell(Screen& s, int x, int y, uint32_t c) { s.rect(1 + x * 2, 1 + y * 2, 2, 2, c); }
  void draw(Screen& s) const {
    s.clear();
    s.rect(0, 0, 1, 32, rgb(90, 90, 90)); s.rect(21, 0, 1, 32, rgb(90, 90, 90)); s.rect(0, 31, 22, 1, rgb(90, 90, 90));
    for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) if (b[y][x]) cell(s, x, y, b[y][x]);
    for (auto& c : p.c) if (c[1] + p.y >= 0) cell(s, c[0] + p.x, c[1] + p.y, p.color);
    for (auto& c : nx.c) s.rect(23 + c[0] * 2, 3 + c[1] * 2, 2, 2, nx.color);
    for (int i = 0; i < lines && i < 20; i++) s.set(26, 29 - i, rgb(40, 220, 80));
  }
};

// ------------------------------------------- Menu and everything around it
class Arcade {
 public:
  enum Mode { MENU, MAZE, BLOCKS, DONE, MAGIC } mode = MENU;  // MAGIC is run by the main sketch.
  int choice = 0;
  uint32_t last = 0, idleSince = 0, stepAt = 0, fallAt = 0, rptAt = 0, doneAt = 0;
  uint8_t prev = 0;
  Maze maze; Blocks tet; Random rnd;
  Screen s;
  long best[2] = {0, 0};
  long lastScore = 0;

  void update(uint8_t held, uint32_t now) {
    uint8_t press = held & ~prev;
    prev = held;
    if (held) idleSince = now;
    rnd.next();
    switch (mode) {
      case MENU:
        if (press & BTN_LEFT) choice = (choice + 2) % 3;
        if (press & BTN_RIGHT) choice = (choice + 1) % 3;
        if (press & (BTN_A | BTN_B)) {
          begin(now);
        }
        drawMenu(now);
        break;
      case MAZE:
        maze.input(held);
        if ((int32_t)(now - stepAt) >= 0) { stepAt = now + 140; maze.step(); }
        maze.draw(s);
        if (maze.over || maze.won) finish(maze.score, 0, now);
        break;
      case BLOCKS:
        if (press & BTN_LEFT) { tet.move(-1); rptAt = now + 220; }
        if (press & BTN_RIGHT) { tet.move(1); rptAt = now + 220; }
        if ((held & (BTN_LEFT | BTN_RIGHT)) && (int32_t)(now - rptAt) >= 0) { tet.move(held & BTN_LEFT ? -1 : 1); rptAt = now + 90; }
        if (press & (BTN_UP | BTN_A)) tet.rotate();
        if (press & BTN_B) tet.drop();
        if ((held & BTN_DOWN) && (int32_t)(now - fallAt) >= 0) { tet.fall(); fallAt = now + 60; }
        if ((int32_t)(now - fallAt) >= 0) { tet.fall(); fallAt = now + tet.fallMs(); }
        tet.draw(s);
        if (tet.over) finish(tet.score, 1, now);
        break;
      case DONE:
        s.clear();
        s.rect(0, 0, 32, 2, rgb(239, 159, 39)); s.rect(0, 30, 32, 2, rgb(239, 159, 39));
        s.number(16, 9, lastScore, rgb(255, 255, 255));
        s.number(16, 18, best[choice], rgb(255, 210, 40));
        if ((int32_t)(now - doneAt) >= 0 && press) { mode = MENU; idleSince = now; }
        if ((int32_t)(now - doneAt - 8000) >= 0) { mode = MENU; idleSince = now; }
        break;
      case MAGIC:
        break;
    }
  }
  void begin(uint32_t now) {
    rnd.seed(rnd.next() ^ now);
    if (choice == 2) { mode = MAGIC; return; }
    if (choice == 0) { maze.start(&rnd); mode = MAZE; stepAt = now; }
    else { tet.start(&rnd); mode = BLOCKS; fallAt = now + tet.fallMs(); }
  }
  void finish(long score, int game, uint32_t now) {
    lastScore = score;
    if (score > best[game]) best[game] = score;
    mode = DONE; doneAt = now + 1500;
  }
  void drawMenu(uint32_t now) {
    int t = now / 900;
    for (int y = 0; y < 32; y++) for (int x = 0; x < 32; x++)
      s.px[y][x] = (((x >> 2) + (y >> 2) + t) & 1) ? rgb(239, 159, 39) : rgb(38, 33, 92);
    if (now - idleSince > 10000) return;
    s.rect(0, 8, 32, 16, 0);
    uint32_t edge = rgb(255, 255, 255);
    int bx = 1 + choice * 10;
    s.rect(bx, 9, 10, 1, edge); s.rect(bx, 22, 10, 1, edge); s.rect(bx, 9, 1, 14, edge); s.rect(bx + 9, 9, 1, 14, edge);
    // Maze: a little purple maze with the pumpkin in it.
    static const uint8_t M[7] = {0x7F, 0x41, 0x5D, 0x51, 0x57, 0x40, 0x7F};
    for (int y = 0; y < 7; y++) for (int x = 0; x < 7; x++) if (M[y] >> (6 - x) & 1) s.set(2 + x + 1, 12 + y, rgb(150, 70, 255));
    s.set(6, 15, rgb(255, 120, 0));
    // Blocks.
    s.rect(13, 17, 6, 2, rgb(255, 140, 26)); s.rect(15, 15, 2, 2, rgb(255, 140, 26)); s.rect(14, 12, 4, 2, rgb(255, 95, 162));
    // Magic: a sparkle that changes colour.
    static const uint32_t C[6] = {0xFF2828, 0xFFAA00, 0xFFFF28, 0x28FF28, 0x28AAFF, 0xFF50FF};
    uint32_t m = C[(now / 250) % 6], m2 = C[(now / 250 + 3) % 6];
    s.rect(25, 12, 2, 8, m); s.rect(22, 15, 8, 2, m); s.rect(24, 14, 4, 4, m); s.rect(25, 15, 2, 2, rgb(255, 255, 255));
    s.set(23, 13, m2); s.set(28, 13, m2); s.set(23, 18, m2); s.set(28, 18, m2);
  }
};
