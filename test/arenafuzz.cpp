#include <cstdio>
#include <cstdlib>
#include <vector>
#include "../arcade_suit/arena.h"
struct B { uint8_t* p; size_t n; uint8_t tag; };
int main() {
  for (int seed = 1; seed <= 40; seed++) {
    srand(seed);
    uint32_t SZ = 4096 + (rand() % 8) * 3000;
    alignas(8) static uint8_t guardmem[64 + 40000 + 64];
    memset(guardmem, 0xEE, sizeof guardmem);
    Arena a; a.init(guardmem + 64, SZ);
    std::vector<B> live; long ops = 0, fails = 0;
    auto check = [&](B& b) { for (size_t i = 0; i < b.n; i++) if (b.p[i] != b.tag) { printf("CORRUPT seed %d\n", seed); exit(1); } };
    for (int it = 0; it < 300000; it++) {
      int k = rand() % 100; ops++;
      size_t n = (rand() % 10 < 7) ? 1 + rand() % 64 : (rand() % 10 < 8 ? 1 + rand() % 400 : 1 + rand() % 3000);
      if (k < 45 || live.empty()) {
        uint8_t* p = (uint8_t*)a.alloc(n);
        if (!p) { fails++; if (!live.empty()) { size_t j = rand() % live.size(); check(live[j]); a.release(live[j].p, live[j].n); live[j] = live.back(); live.pop_back(); } }
        else { if ((uintptr_t)p & 7 || !a.owns(p) || p + n > a.base + a.size) { puts("BADPTR"); return 1; } B b{p, n, (uint8_t)rand()}; memset(p, b.tag, n); live.push_back(b); }
      } else if (k < 80) {
        size_t j = rand() % live.size(); check(live[j]); a.release(live[j].p, live[j].n); live[j] = live.back(); live.pop_back();
      } else {
        size_t j = rand() % live.size(); B& b = live[j]; check(b);
        void* q = a.resize(b.p, b.n, n);
        if (q) { if (q != b.p) { puts("MOVED"); return 1; } if (n > b.n) memset(b.p + b.n, b.tag, n - b.n); b.n = n; }
        else if (n <= b.n) { puts("SHRINKFAIL"); return 1; }
      }
      if (it % 997 == 0) {
        if (!a.healthy()) { printf("UNHEALTHY seed %d it %d\n", seed, it); return 1; }
        uint32_t used = 0; for (auto& b : live) used += (b.n + 7) & ~7u;
        if (used + a.freeBytes != a.size) { puts("LEAK"); return 1; }
      }
    }
    for (auto& b : live) { check(b); a.release(b.p, b.n); }
    if (!a.healthy() || a.freeBytes != a.size || a.largest() != a.size) { printf("NOT WHOLE seed %d\n", seed); return 1; }
    for (int i = 0; i < 64; i++) if (guardmem[i] != 0xEE || guardmem[64 + a.size + i] != 0xEE) { puts("OVERRUN"); return 1; }
  }
  puts("arena fuzz ok: 40 seeds x 300k ops");
}
