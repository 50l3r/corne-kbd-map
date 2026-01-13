#!/bin/bash
# Compilación local usando el contenedor oficial de ZMK con caché

set -e

BOARD="mikoto@7.2"

# Directorio de caché local en el repositorio
CACHE_DIR="$(pwd)/.zmk-cache"
mkdir -p "$CACHE_DIR" "build"

# Función para compilar una mitad del teclado
build_side() {
    local SIDE=$1
    local SHIELD=$2
    local SNIPPET=$3
    local BUILD_DIR="$(pwd)/build-temp-${SIDE}"
    
    mkdir -p "$BUILD_DIR"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "⚡ Compilando lado ${SIDE}..."
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    # Ejecutar compilación en Docker con volúmenes persistentes
    docker run --rm \
        -v "$(pwd)/corne:/workspace/config" \
        -v "$CACHE_DIR:/workspace/zmk-cache" \
        -v "$BUILD_DIR:/workspace/build" \
        -w /workspace \
        zmkfirmware/zmk-build-arm:stable \
        sh -c "
            set -e

            # Usar caché si existe, sino inicializar
            if [ -d zmk-cache/zmk ] && [ -d zmk-cache/.west ]; then
                echo '==> Usando caché existente...'
                cp -r zmk-cache/.west .
                cp -r zmk-cache/zmk .
                cp -r zmk-cache/modules .
                cp -r zmk-cache/zephyr .
                cp -r zmk-cache/bootloader 2>/dev/null || true
                echo '==> Actualizando workspace...'
                west update --narrow --fetch-opt=--depth=1 2>/dev/null || true
            else
                echo '==> Inicializando workspace (primera vez)...'
                west init -l config
                echo '==> Descargando dependencias...'
                west update --narrow --fetch-opt=--depth=1
                echo '==> Guardando en caché...'
                mkdir -p zmk-cache
                cp -r .west zmk modules zephyr zmk-cache/
                cp -r bootloader zmk-cache/ 2>/dev/null || true
            fi

            echo '==> Exportando Zephyr CMake package...'
            west zephyr-export

            echo '==> Compilando firmware ${SIDE}...'
            west build -s zmk/app -d build -b ${BOARD} -- \
                -DSHIELD='${SHIELD}' \
                -DZMK_CONFIG=/workspace/config \
                ${SNIPPET:+-Dzmk-snippet='${SNIPPET}'}
        "

    # Copiar el firmware generado
    if [ -f "$BUILD_DIR/zephyr/zmk.uf2" ]; then
        cp "$BUILD_DIR/zephyr/zmk.uf2" "build/corne_${SIDE}.uf2"
        echo ""
        echo "✅ ${SIDE} compilado correctamente"
        rm -rf "$BUILD_DIR"
        return 0
    else
        echo "❌ Error: No se generó el firmware para ${SIDE}"
        rm -rf "$BUILD_DIR"
        return 1
    fi
}

# Compilar ambas mitades
echo "🔨 Compilando firmware Corne (ambas mitades)"
echo ""

FAILED=0

# Lado izquierdo (con ZMK Studio)
build_side "left" "corne_left nice_view_adapter nice_view" "studio-rpc-usb-uart" || FAILED=1

# Lado derecho (sin ZMK Studio snippet)
build_side "right" "corne_right nice_view_adapter nice_view" "" || FAILED=1

# Resumen final
echo ""
echo "═══════════════════════════════════════════════════════════"
if [ $FAILED -eq 0 ]; then
    echo "✅ ¡Compilación completa!"
    echo ""
    echo "Archivos generados:"
    ls -lh build/*.uf2
else
    echo "❌ Hubo errores durante la compilación"
    exit 1
fi
echo "═══════════════════════════════════════════════════════════"
