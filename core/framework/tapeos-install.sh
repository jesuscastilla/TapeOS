#!/bin/busybox sh
# ==============================================================================
# TapeOS - Instalador a disco duro (framework Brunch/TapeOS)
#   1. Vuelca el USB completo al disco destino (dd).
#   2. Repara la GPT (cgpt repair, mueve la tabla de respaldo al final).
#   3. Expande ROOT-A (particion 3) al maximo del disco.
#   4. Redimensiona el sistema de ficheros (resize2fs/e2fsck incluidos).
# Uso: tapeos-install.sh <disco_origen_usb>
# ==============================================================================
SRC="$1"
export PATH=$PATH:/rootc/tapeos/bin:/tapeos/bin
export LD_LIBRARY_PATH=/rootc/tapeos/lib/x86_64-linux-gnu:/rootc/tapeos/lib/lib64:$LD_LIBRARY_PATH

log() { echo "[TapeOS install] $*"; }

[ -n "$SRC" ] || { echo "Uso: tapeos-install.sh <disco_origen>"; exit 1; }
SRC_BASE="${SRC##*/}"

echo ""
echo "=================================================================="
echo "        TapeOS - INSTALACION EN DISCO DURO"
echo "=================================================================="
echo ""
echo "ADVERTENCIA: SE BORRARAN TODOS LOS DATOS DEL DISCO DESTINO."
echo "Discos detectados (se excluye el medio de arranque $SRC):"
echo ""
CANDIDATES=""
i=0
for d in /sys/block/*; do
    base="${d##*/}"
    case "$base" in loop*|ram*|dm-*|sr*) continue ;; esac
    [ -e "$d/partition" ] && continue
    [ "$base" = "$SRC_BASE" ] && continue
    sz=$(cat "$d/size" 2>/dev/null)
    [ -n "$sz" ] || continue
    i=$((i+1))
    gb=$(( sz * 512 / 1000000000 ))
    model=$(cat "$d/device/model" 2>/dev/null || echo desconocido)
    echo "  [$i] /dev/$base  ${gb} GB  ($model)"
    CANDIDATES="$CANDIDATES /dev/$base"
done
[ -n "$CANDIDATES" ] || { echo "No hay discos destino."; exit 1; }

printf "Elige el numero del disco destino: "
read choice
case "$choice" in ''|*[!0-9]*) echo "Opcion invalida."; exit 1 ;; esac
DST=""
j=0
for c in $CANDIDATES; do j=$((j+1)); [ "$j" = "$choice" ] && DST="$c"; done
[ -n "$DST" ] || { echo "Opcion invalida."; exit 1; }

echo ""
echo "Destino: $DST"
printf "Escribe BORRAR para confirmar: "
read confirm
[ "$confirm" = "BORRAR" ] || { echo "Cancelado."; exit 1; }

echo ""
echo "[1/5] Volcando $SRC -> $DST (tarda varios minutos)..."
dd if="$SRC" of="$DST" bs=4M conv=fsync 2>/dev/null
sync
echo "      Volcado completado."

echo "[2/5] Reparando la tabla GPT del destino..."
cgpt repair "$DST" || { echo "cgpt repair fallo"; exit 1; }
blockdev --rereadpt "$DST" 2>/dev/null || true
sleep 2

echo "[3/5] Expandiendo ROOT-A (particion 3) al maximo..."
START=$(cgpt show -i 3 -b "$DST")
END=$(cgpt show "$DST" | grep "Sec GPT table" | awk '{print $1}')
case "$START$END" in ''|*[!0-9]*) echo "No se pudo calcular el espacio."; exit 1 ;; esac
SIZE=$(( END - START - 1 ))
cgpt add -i 3 -b "$START" -s "$SIZE" -t rootfs -l ROOT-A "$DST" || { echo "cgpt add fallo"; exit 1; }
blockdev --rereadpt "$DST" 2>/dev/null || true
sleep 2

echo "[4/5] Redimensionando el sistema de ficheros..."
ROOTDEV="${DST}3"
case "$DST" in *nvme*|*mmcblk*) ROOTDEV="${DST}p3" ;; esac
if [ -x /rootc/tapeos/bin/e2fsck ]; then
    /rootc/tapeos/bin/e2fsck -f -y "$ROOTDEV" >/dev/null 2>&1 || true
    /rootc/tapeos/bin/resize2fs "$ROOTDEV" || { echo "resize2fs fallo"; exit 1; }
else
    e2fsck -f -y "$ROOTDEV" >/dev/null 2>&1 || true
    resize2fs "$ROOTDEV" || { echo "resize2fs fallo"; exit 1; }
fi
sync

echo "[5/5] Listo."
echo ""
echo "=================================================================="
echo " INSTALACION COMPLETADA en $DST"
echo " Reinicia, entra en la BIOS (F12/F11/Esc) y arranca desde el disco."
echo "=================================================================="
exit 0