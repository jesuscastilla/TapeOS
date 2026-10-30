#!/bin/busybox sh
# ==============================================================================
# TapeOS - Instalador a disco duro (se ejecuta dentro del initramfs)
#
#   1. Vuelca el USB completo (dd) al disco destino elegido.
#   2. Reubica la GPT de respaldo al final del disco (sgdisk -e).
#   3. Expande ROOT-A (particion 3) hasta el final del disco.
#   4. Aplica los parches de TapeOS sobre la instalacion.
#   5. Reescribe el menu GRUB del destino con el nuevo PARTUUID.
#
# Uso: tapeos-install.sh <disco_origen> [particion_esp_origen]
# ==============================================================================

SRC="$1"
ESP_SRC="${2:-}"
OPTIONS="$(cat /run/tapeos-options 2>/dev/null || true)"

log() {
    echo "[TapeOS install] $*" > /dev/kmsg 2>/dev/null
    echo "[TapeOS install] $*"
}

[ -n "$SRC" ] || { echo "Uso: tapeos-install.sh <disco_origen>"; exit 1; }

# --- utilidades ---------------------------------------------------------------
disk_size_gb() {
    local sz
    sz=$(cat "/sys/class/block/$(basename "$1")/size" 2>/dev/null || echo 0)
    echo $(( sz * 512 / 1000000000 ))
}

part_dev() {  # <disco> <num> -> /dev/sda3 o /dev/nvme0n1p3
    case "$1" in
        *nvme*|*mmcblk*) echo "$1p$2" ;;
        *) echo "$1$2" ;;
    esac
}

echo ""
echo "=================================================================="
echo "        TapeOS - INSTALACION EN DISCO DURO"
echo "=================================================================="
echo ""
echo "ADVERTENCIA: SE BORRARAN TODOS LOS DATOS DEL DISCO DESTINO."
echo ""
echo "Discos detectados (se excluye el medio de arranque $SRC):"
echo ""
CANDIDATES=""
i=0
for d in /sys/class/block/*; do
    base="${d##*/}"
    case "$base" in loop*|ram*|dm-*|sr*) continue ;; esac
    [ -e "$d/partition" ] && continue
    [ "$base" = "$(basename "$SRC")" ] && continue
    i=$((i+1))
    CANDIDATES="$CANDIDATES /dev/$base"
    model="$(cat "$d/device/model" 2>/dev/null || echo desconocido)"
    gb=$(disk_size_gb "/dev/$base")
    echo "  [$i] /dev/$base  ${gb} GB  ($model)"
done
[ -n "$CANDIDATES" ] || { echo "No hay discos destino disponibles."; exit 1; }

printf "Elige el numero del disco destino: "
read choice
case "$choice" in ''|*[!0-9]*) echo "Opcion invalida."; exit 1 ;; esac
DST=""
j=0
for c in $CANDIDATES; do
    j=$((j+1))
    [ "$j" = "$choice" ] && DST="$c"
done
[ -n "$DST" ] || { echo "Opcion invalida."; exit 1; }

echo ""
echo "Destino elegido: $DST ($(disk_size_gb "$DST") GB)"
printf "Escribe BORRAR para confirmar: "
read confirm
[ "$confirm" = "BORRAR" ] || { echo "Cancelado."; exit 1; }

echo ""
echo "[1/6] Volcando $SRC -> $DST (tarda varios minutos)..."
dd if="$SRC" of="$DST" bs=4M conv=fsync 2>/dev/null
sync
echo "      Volcado completado."

echo "[2/6] Reubicando la GPT de respaldo al final del disco..."
sgdisk -e "$DST" || { echo "sgdisk -e fallo"; exit 1; }

echo "[3/6] Expandiendo ROOT-A (particion 3) al 100% del disco..."
START=$(sgdisk -i 3 "$DST" | awk -F: '/First sector/ {print $2}' | tr -d ' ' | sed 's/(.*//')
case "$START" in ''|*[!0-9]*) echo "No se pudo leer el inicio de ROOT-A."; exit 1 ;; esac
sgdisk -d 3 -n 3:"$START":0 -t 3:3CB8E202-3B7E-47DD-8A3C-7FF2A13CFCEB -c 3:ROOT-A "$DST" || { echo "sgdisk -n fallo"; exit 1; }
partprobe "$DST" 2>/dev/null || true
sleep 2

echo "[4/6] Redimensionando el sistema de ficheros..."
ROOTDEV=$(part_dev "$DST" 3)
e2fsck -f -y "$ROOTDEV" >/dev/null 2>&1 || true
resize2fs "$ROOTDEV" || { echo "resize2fs fallo"; exit 1; }
sync

echo "[5/6] Aplicando parches de TapeOS a la instalacion..."
NEWUUID=$(sgdisk -i 3 "$DST" | awk -F: '/Partition unique GUID/ {print $2}' | tr -d ' ')
mkdir -p /mnt/newroot
mount -o rw "$ROOTDEV" /mnt/newroot || { echo "No se pudo montar ROOT-A destino."; exit 1; }
export TAPEOOS_ROOT=/mnt/newroot
for p in /patches/[0-9]*.sh; do
    [ -x "$p" ] || continue
    echo "   + ${p##*/}"
    "$p" "$OPTIONS" > /dev/kmsg 2>&1
done
umount /mnt/newroot 2>/dev/null || true

echo "[6/6] Actualizando el menu GRUB del disco destino..."
ESP_DST=""
for p in /sys/class/block/$(basename "$DST")*; do
    [ -e "$p/partition" ] || continue
    dev="/dev/${p##*/}"
    mkdir -p /mnt/esp
    if mount -t vfat "$dev" /mnt/esp 2>/dev/null; then
        if [ -f /mnt/esp/efi/boot/grub.cfg ] || [ -f /mnt/esp/syslinux/vmlinuz.A ]; then
            ESP_DST="$dev"
            break
        fi
        umount /mnt/esp 2>/dev/null
    fi
done
if [ -n "$ESP_DST" ] && [ -n "$NEWUUID" ]; then
    mount -t vfat "$ESP_DST" /mnt/esp 2>/dev/null || true
    OLD_UUID=$(grep -o 'PARTUUID=[0-9A-F-]*' /mnt/esp/efi/boot/grub.cfg 2>/dev/null | head -1 | cut -d= -f2)
    if [ -n "$OLD_UUID" ]; then
        sed -i "s/$OLD_UUID/$NEWUUID/g" /mnt/esp/efi/boot/grub.cfg
        echo "   PARTUUID actualizado: $OLD_UUID -> $NEWUUID"
    else
        echo "   (AVISO: no se encontro PARTUUID en el grub.cfg del destino)"
    fi
    umount /mnt/esp 2>/dev/null || true
else
    echo "   (AVISO: no se encontro la ESP destino; revisa el grub.cfg a mano)"
fi

echo ""
echo "=================================================================="
echo " INSTALACION COMPLETADA en $DST"
echo " Reinicia, entra en la BIOS (F12/F11/Esc) y arranca desde el disco."
echo "=================================================================="
exit 0