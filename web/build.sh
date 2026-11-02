#!/bin/sh
# Builds web/arcade.wasm from the firmware's own game code. Needs zig:  pip install ziglang
set -e
cd "$(dirname "$0")"
FLAGS='-target wasm32-wasi -mexec-model=reactor -O2 -mexception-handling -mllvm -wasm-enable-sjlj -fno-exceptions -fno-rtti -D_WASI_EMULATED_SIGNAL -Dl_signalT=int -Dl_randomizePivot()=0 -s'
mkdir -p obj
for f in ../arcade_suit/src/lua/*.c; do
  python3 -m ziglang cc $FLAGS -c "$f" -o "obj/$(basename "$f" .c).o"
done
python3 -m ziglang c++ $FLAGS -std=c++17 engine.cpp longjmp_tag.S obj/*.o -o arcade.wasm
rm -rf obj
ls -la arcade.wasm
