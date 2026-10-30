#!/bin/bash
# TapeOS 92: GPUs Intel antiguas (Gen 2-9) - opcion "legacy_gpu"
lg=0
for i in $(echo "$1" | sed 's/,/ /g'); do [ "$i" = "legacy_gpu" ] && lg=1; done
[ $lg -eq 1 ] || exit 0
R="${TAPEOOS_ROOT:-/roota}"
mkdir -p "$R/etc/env.d" "$R/etc/chrome_dev.conf.d" "$R/etc/modprobe.d"
cat > "$R/etc/env.d/99tapeos-legacy-gpu" <<EOF
INTEL_DEBUG=noccs,norbc
MESA_LOADER_DRIVER_OVERRIDE=crocus
LIBGL_ALWAYS_SOFTWARE=0
EOF
cat > "$R/etc/chrome_dev.conf.d/tapeos-legacy-gpu.conf" <<EOF
--ignore-gpu-blocklist
--enable-gpu-rasterization
--enable-zero-copy
--disable-features=Vulkan,VulkanFromANGLE
--disable-gpu-watchdog
EOF
cat > "$R/etc/modprobe.d/tapeos-i915.conf" <<EOF
options i915 enable_guc=0 enable_psr=0 modeset=1 fastboot=1
EOF
echo "tapeos: perfil GPU legacy Intel aplicado (crocus/noccs)" > /dev/kmsg
exit 0