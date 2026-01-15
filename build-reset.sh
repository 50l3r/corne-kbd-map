#!/bin/bash
# Compila el firmware de reset de settings

set -e

BOARD="mikoto@7.2"
SHIELD="settings_reset"
CACHE_DIR="$(pwd)/.zmk-cache"
BUILD_DIR="$(pwd)/build-temp-reset"

mkdir -p "$CACHE_DIR" "$BUILD_DIR" "build"

echo "⚡ Compilando settings_reset..."

docker run --rm \
    -v "$(pwd)/config:/workspace/config" \
    -v "$CACHE_DIR:/workspace/zmk-cache" \
    -v "$BUILD_DIR:/workspace/build" \
    -w /workspace \
    zmkfirmware/zmk-build-arm:stable \
    sh -c "
        set -e
        if [ -d zmk-cache/zmk ] && [ -d zmk-cache/.west ]; then
            cp -r zmk-cache/.west .
            cp -r zmk-cache/zmk .
            cp -r zmk-cache/modules .
            cp -r zmk-cache/zephyr .
        fi
        west zephyr-export
        west build -s zmk/app -d build -b ${BOARD} -- -DSHIELD=${SHIELD}
    "

if [ -f "$BUILD_DIR/zephyr/zmk.uf2" ]; then
    cp "$BUILD_DIR/zephyr/zmk.uf2" "build/settings_reset.uf2"
    echo "✅ Generado: build/settings_reset.uf2"
    rm -rf "$BUILD_DIR"
else
    echo "❌ Error"
    rm -rf "$BUILD_DIR"
    exit 1
fi
