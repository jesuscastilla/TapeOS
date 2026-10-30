#!/bin/bash
# TapeOS 90: GPUs dedicadas AMD (amdgpu) - opcion "dgpu"
# ChromeOS Flex usa amdgpu, asi que forzamos el mismo camino en Brunch.
dgpu=0
for i in $(echo "$1" | sed 's/,/ /g'); do [ "$i" = "dgpu" ] && dgpu=1; done
[ $dgpu -eq 1 ] || exit 0
R="${TAPEOOS_ROOT:-/roota}"
mkdir -p "$R/etc/modprobe.d" "$R/etc/modules-load.d" "$R/etc/env.d" "$R/etc/chrome_dev.conf.d"
cat > "$R/etc/modprobe.d/tapeos-dgpu.conf" <<EOF
blacklist radeon
blacklist nouveau
options amdgpu modeset=1 dc=1 dpm=1
options radeon modeset=0
EOF
echo "amdgpu" >> "$R/etc/modules-load.d/tapeos-dgpu.conf"
cat > "$R/etc/chrome_dev.conf.d/tapeos-dgpu.conf" <<EOF
--ignore-gpu-blocklist
--enable-gpu-rasterization
--enable-zero-copy
--disable-features=Vulkan,VulkanFromANGLE
--use-gl=egl
EOF
cat > "$R/etc/env.d/99tapeos-dgpu" <<EOF
MESA_LOADER_DRIVER_OVERRIDE=amdgpu
AMD_DEBUG=novmacopyimage
EOF
echo "tapeos: compatibilidad dGPU AMD aplicada" > /dev/kmsg
exit 0