#!/usr/bin/env bash
TAPEOOS_ROOT=${TAPEOOS_ROOT:-/roota}
# ==============================================================================
# TapeOS Patch: 10-legacy_gpu_freon.sh
# Habilita aceleración gráfica fluida en ChromeOS moderno para GPUs Intel y AMD antiguas
# ==============================================================================

# Detectar chipset gráfico mediante lspci o sysfs
GPU_PCI=$(lspci -nn | grep -E "VGA|3D|Display" | head -n 1)

echo "[TapeOS] Verificando compatibilidad de GPU..."

if echo "$GPU_PCI" | grep -qi "8086"; then
    # Intel Graphics
    echo "[TapeOS] GPU Intel detectada: $GPU_PCI"
    
    # Comprobar si es Gen 2 a Gen 7.5 (Sandy Bridge, Ivy Bridge, Haswell, Bay Trail)
    if echo "$GPU_PCI" | grep -qiE "0102|0106|0112|0116|0122|0126|0152|0156|0162|0166|0402|0412|0416|0422|0a06|0a16|0a26|0f31|22b0|22b1"; then
        echo "[TapeOS] Aplicando perfil de compatibilidad Legacy Intel GPU (Gen 2 - Gen 7)..."
        
        # Inyectar configuración para Mesa y Chrome
        mkdir -p $TAPEOOS_ROOT/etc/chrome_dev.conf.d/
        cat << 'EOF' > $TAPEOOS_ROOT/etc/chrome_dev.conf.d/10-tapeos-legacy-gpu.conf
--ignore-gpu-blocklist
--enable-gpu-rasterization
--enable-zero-copy
--disable-features=Vulkan,VulkanFromANGLE
--disable-gpu-watchdog
EOF

        # Variables de entorno para Mesa (desactivar compresión no soportada)
        cat << 'EOF' > $TAPEOOS_ROOT/etc/env.d/99tapeos-mesa
INTEL_DEBUG=noccs,norbc
MESA_LOADER_DRIVER_OVERRIDE=crocus
LIBGL_ALWAYS_SOFTWARE=0
EOF
    fi
elif echo "$GPU_PCI" | grep -qi "1002"; then
    # AMD Graphics (Radeon TeraScale / GCN 1.0)
    echo "[TapeOS] GPU AMD Legacy detectada: $GPU_PCI"
    mkdir -p $TAPEOOS_ROOT/etc/chrome_dev.conf.d/
    cat << 'EOF' > $TAPEOOS_ROOT/etc/chrome_dev.conf.d/10-tapeos-legacy-gpu.conf
--ignore-gpu-blocklist
--enable-gpu-rasterization
--disable-features=Vulkan,VulkanFromANGLE
EOF
fi

echo "[TapeOS] Parche de GPU completado."
