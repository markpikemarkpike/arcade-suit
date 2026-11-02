// A small memory pool with no per-block header. Lua always tells its allocator the old size of a block,
// so nothing needs to be stored next to the data. On the ESP32 that saves 16 bytes on every allocation.
// Free blocks form one list sorted by address, and neighbours are merged as soon as they are freed.
#pragma once
#include <stdint.h>
#include <stddef.h>
#include <string.h>

class Arena {
 public:
  static const uint32_t NIL = 0xFFFFFFFFu;
  struct Node { uint32_t size, next; };
  uint8_t* base = nullptr;
  uint32_t size = 0, head = NIL, freeBytes = 0;

  void init(void* mem, uint32_t bytes) {
    base = (uint8_t*)mem;
    size = bytes & ~7u;
    head = 0;
    at(0)->size = size;
    at(0)->next = NIL;
    freeBytes = size;
  }
  bool owns(const void* p) const { return base && (const uint8_t*)p >= base && (const uint8_t*)p < base + size; }

  void* alloc(size_t n) {
    if (n == 0 || n > size) return nullptr;
    uint32_t need = up(n);
    if (need <= 128) {  // Small blocks: first fit from the bottom.
      for (uint32_t prev = NIL, cur = head; cur != NIL; prev = cur, cur = at(cur)->next)
        if (at(cur)->size >= need) return carveFront(prev, cur, need);
      return nullptr;
    }
    uint32_t bestPrev = NIL, best = NIL;  // Big blocks: last fit, cut from the top, to keep the two kinds apart.
    for (uint32_t prev = NIL, cur = head; cur != NIL; prev = cur, cur = at(cur)->next)
      if (at(cur)->size >= need) { best = cur; bestPrev = prev; }
    if (best == NIL) return nullptr;
    if (at(best)->size == need) return carveFront(bestPrev, best, need);
    at(best)->size -= need;
    freeBytes -= need;
    return base + best + at(best)->size;
  }

  void release(void* p, size_t n) {
    if (!p || n == 0) return;
    uint32_t off = (uint32_t)((uint8_t*)p - base), len = up(n), prev = NIL, cur = head;
    while (cur != NIL && cur < off) { prev = cur; cur = at(cur)->next; }
    freeBytes += len;
    Node* me = at(off);
    me->size = len;
    me->next = cur;
    if (cur != NIL && off + len == cur) { me->size += at(cur)->size; me->next = at(cur)->next; }
    if (prev == NIL) head = off;
    else if (prev + at(prev)->size == off) { at(prev)->size += me->size; at(prev)->next = me->next; }
    else at(prev)->next = off;
  }

  // Changes a block's size without moving it. Shrinking always works. Growing works only if free space follows the block.
  void* resize(void* p, size_t o, size_t n) {
    uint32_t ol = up(o), nl = up(n), off = (uint32_t)((uint8_t*)p - base);
    if (nl == ol) return p;
    if (nl < ol) { release((uint8_t*)p + nl, ol - nl); return p; }
    uint32_t want = nl - ol, after = off + ol;
    for (uint32_t prev = NIL, cur = head; cur != NIL && cur <= after; prev = cur, cur = at(cur)->next)
      if (cur == after) {
        if (at(cur)->size < want) return nullptr;
        carveFront(prev, cur, want);
        return p;
      }
    return nullptr;
  }

  uint32_t largest() const {
    uint32_t m = 0;
    for (uint32_t cur = head; cur != NIL; cur = at(cur)->next) if (at(cur)->size > m) m = at(cur)->size;
    return m;
  }
  // Self-check for the tests: sorted, merged, in range, and the sizes add up.
  bool healthy() const {
    uint32_t sum = 0, last = 0;
    bool first = true;
    for (uint32_t cur = head; cur != NIL; cur = at(cur)->next) {
      if (cur & 7 || cur >= size || at(cur)->size == 0 || at(cur)->size & 7 || cur + at(cur)->size > size) return false;
      if (!first && cur <= last) return false;  // "last" is the end of the previous block: touching blocks must have merged.
      last = cur + at(cur)->size;
      first = false;
      sum += at(cur)->size;
    }
    return sum == freeBytes;
  }

 private:
  static uint32_t up(size_t n) { return (uint32_t)((n + 7) & ~(size_t)7); }
  Node* at(uint32_t off) const { return (Node*)(base + off); }
  void* carveFront(uint32_t prev, uint32_t cur, uint32_t need) {
    Node c = *at(cur);
    uint32_t follow = c.next;
    if (c.size > need) {
      follow = cur + need;
      at(follow)->size = c.size - need;
      at(follow)->next = c.next;
    }
    if (prev == NIL) head = follow; else at(prev)->next = follow;
    freeBytes -= need;
    return base + cur;
  }
};
