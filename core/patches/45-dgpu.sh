#!/usr/bin/env bash
TAPEOOS_ROOT=${TAPEOOS_ROOT:-/roota}
# ==============================================================================
# TapeOS Patch: 45-dgpu.sh
# Compatibilidad con GPUs dedicadas (dGPU) en ChromeOS:
#  - NVIDIA: el stack grafico de ChromeOS (Freon/minigbm) no puede usar el
#    driver propietario ni nouveau de forma fiable. La dGPU se mantiene
#    suspendida mediante una regla udev y el equipo renderiza con la GPU
#    integrada (mejor temperatura y autonomia). Se desactiva nouveau.
#  - AMD: se fuerza el driver abierto amdgpu (soportado por ChromeOS/Mesa,
#    el mismo camino que ChromeOS Flex) y se desactiva radeon para evitar
#    conflictos de modulos.
# Se activa con la opcion de framework "dgpu" (options=dgpu).
# ==============================================================================

dgpu=0
for i in $(echo "$1" | sed 's#,# #g'); do
    if [ "$i" == "dgpu" ]; then dgpu=1; fi
done
if [ "$dgpu" -eq 0 ]; then exit 0; fi

echo "[TapeOS] Opcion dgpu activada: preparando compatibilidad con GPU dedicada..." > /dev/kmsg

ret=0
mkdir -p $TAPEOOS_ROOT/lib/udev/rules.d $TAPEOOS_ROOT/etc/modprobe.d $TAPEOOS_ROOT/etc/modules-load.d

# --- NVIDIA: suspender la dGPU y renderizar con la iGPU ---
cat > $TAPEOOS_ROOT/lib/udev/rules.d/99-tapeos-dgpu.rules <<'UDEV'
# Mantener suspendida la dGPU NVIDIA y sus dispositivos auxiliares
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{power/control}="auto", ATTR{remove}="1"
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{power/control}="auto", ATTR{remove}="1"
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", ATTR{power/control}="auto", ATTR{remove}="1"
UDEV
if [ ! "$?" -eq 0 ]; then ret=$((ret + (2 ** 0))); fi

cat > $TAPEOOS_ROOT/etc/modprobe.d/blacklist-nouveau.conf <<'MODPROBE'
blacklist nouveau
options nouveau modeset=0
MODPROBE
if [ ! "$?" -eq 0 ]; then ret=$((ret + (2 ** 1))); fi

# --- AMD: forzar amdgpu y desactivar radeon (legacy) ---
cat > $TAPEOOS_ROOT/etc/modprobe.d/tapeos-amdgpu.conf <<'MODPROBE'
blacklist radeon
options amdgpu modeset=1
MODPROBE
if [ ! "$?" -eq 0 ]; then ret=$((ret + (2 ** 2))); fi

if ! grep -q '^amdgpu$' $TAPEOOS_ROOT/etc/modules-load.d/tapeos-dgpu.conf 2>/dev/null; then
    echo "amdgpu" >> $TAPEOOS_ROOT/etc/modules-load.d/tapeos-dgpu.conf
fi

echo "[TapeOS] Compatibilidad dGPU preparada (ret=$ret)." > /dev/kmsg
exit $ret