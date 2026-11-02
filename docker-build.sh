#!/bin/sh
# Compiles arcade_suit inside Docker, so there is no ESP32 toolchain to install.
#
#   ./docker-build.sh
#
# Output lands in build/:
#   arcade_suit_flash_at_0x0.bin   the whole flash image, for a first install (wipes pairing and Wi-Fi settings)
#   arcade_suit.ino.bin            just the program, for updates: flash it at 0x10000 and settings survive
set -e

# The toolchain and libraries are pinned to what the working firmware was built with.
IMAGE=debian:13-slim@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f
ARDUINO_CLI=1.3.1
ARDUINO_CLI_SHA_X86=376428d7d45be640c00812a71612e1742edc2f5f9ee3742a2d6da7870e079588
ARDUINO_CLI_SHA_ARM=cf4f668b1add7a20310d79e83a1f3eb148031f95e5673d9171c65f5e9a126a94
BLUEPAD32_CORE=4.1.0
BLUEPAD32_INDEX_SHA=d1bbefedc549d6ad3a29048795a75fc2b8bfe7f9
ESP32_INDEX_SHA=15b99c39726fb7f8abca22fe01119946ab15b9a7
FASTLED=3.6.0
M5GFX=0.1.17
M5UNIFIED=0.1.17
FQBN=esp32-bluepad32:esp32:m5stack-core-esp32

# The container can read this script, the sketch and the patch but not change them. build/ is all it can write.
if [ ! -f /.dockerenv ]; then
  HERE="$(cd "$(dirname "$0")" && pwd)"
  mkdir -p "$HERE/build"
  exec docker run --rm \
    -v "$HERE/docker-build.sh:/src/docker-build.sh:ro" \
    -v "$HERE/arcade_suit:/src/arcade_suit:ro" \
    -v "$HERE/patches:/src/patches:ro" \
    -v "$HERE/build:/out" \
    -v arcade-suit-arduino-cache:/root/.arduino15 \
    "$IMAGE" sh /src/docker-build.sh
fi

apt-get update -qq && apt-get install -y -qq curl ca-certificates python3 python3-serial patch >/dev/null

case "$(uname -m)" in
  x86_64)  CLI_ARCH=64bit; CLI_SHA=$ARDUINO_CLI_SHA_X86 ;;
  aarch64) CLI_ARCH=ARM64; CLI_SHA=$ARDUINO_CLI_SHA_ARM ;;
  *) echo "no pinned arduino-cli for $(uname -m)" >&2; exit 2 ;;
esac
curl -fsSL -o /tmp/arduino-cli.tar.gz "https://github.com/arduino/arduino-cli/releases/download/v$ARDUINO_CLI/arduino-cli_${ARDUINO_CLI}_Linux_$CLI_ARCH.tar.gz"
echo "$CLI_SHA  /tmp/arduino-cli.tar.gz" | sha256sum -c - >/dev/null
tar -xzf /tmp/arduino-cli.tar.gz -C /usr/local/bin arduino-cli
arduino-cli config init --overwrite >/dev/null
# Bluepad32's core borrows its compilers from Espressif's package list, so both lists are needed.
arduino-cli config set board_manager.additional_urls \
  "https://raw.githubusercontent.com/ricardoquesada/esp32-arduino-lib-builder/$BLUEPAD32_INDEX_SHA/bluepad32_files/package_esp32_bluepad32_index.json" \
  "https://raw.githubusercontent.com/espressif/arduino-esp32/$ESP32_INDEX_SHA/package_esp32_index.json"
arduino-cli core update-index >/dev/null
echo "[*] installing the Bluepad32 ESP32 core $BLUEPAD32_CORE (cached in the arcade-suit-arduino-cache volume after the first run)..."
arduino-cli core install "esp32-bluepad32:esp32@$BLUEPAD32_CORE"
arduino-cli lib install --no-deps "FastLED@$FASTLED" "M5GFX@$M5GFX" "M5Unified@$M5UNIFIED" >/dev/null

CORE="/root/.arduino15/packages/esp32-bluepad32/hardware/esp32/$BLUEPAD32_CORE"
# Two small time limits in the stock web server, so a phone that walks out of range mid-upload cannot freeze the suit.
if ! grep -q arcadeGuard "$CORE/libraries/WebServer/src/Parsing.cpp"; then
  patch -d "$CORE" -p0 < /src/patches/webserver-timeouts.patch
fi

echo "[*] compiling arcade_suit ..."
mkdir -p /work && rm -rf /work/arcade_suit && cp -r /src/arcade_suit /work/arcade_suit   # the toolchain writes beside the sketch, so compile a copy
# huge_app: 3 MB for the program, and a spare partition at 0x310000 where the last good game is kept.
arduino-cli compile --fqbn "$FQBN" --output-dir /work/out \
  --build-property build.partitions=huge_app --build-property upload.maximum_size=3145728 /work/arcade_suit

ESPTOOL="$(ls /root/.arduino15/packages/esp32/tools/esptool_py/*/esptool* | head -1)"
case "$ESPTOOL" in *.py) ESPTOOL="python3 $ESPTOOL" ;; esac
$ESPTOOL --chip esp32 merge_bin -o /out/arcade_suit_flash_at_0x0.bin --flash_mode dio --flash_size 4MB \
  0x1000 /work/out/arcade_suit.ino.bootloader.bin 0x8000 /work/out/arcade_suit.ino.partitions.bin \
  0xe000 "$CORE/tools/partitions/boot_app0.bin" 0x10000 /work/out/arcade_suit.ino.bin
cp /work/out/arcade_suit.ino.bin /out/
ls -la /out/
echo "[done]"
