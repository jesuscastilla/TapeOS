#!/bin/bash
# ==============================================================================
# apply-free.sh - adapta una imagen FydeOS/openFyde a TapeOS Free.
#
#   ROOT-A de FydeOS usa features ext4 propietarias (ff000000, R24-R31) que Linux
#   no puede montar en rw, y el fs viene al 100% de ocupacion. Por eso:
#     1) se lee el arbol en RO (siempre funciona) con tar --sparse
#     2) se recrea ROOT-A como ext4 estandar SIN reserva ni journal
#        (-m 0 -O ^has_journal) para que el arbol quepa (~137 MB libres)
#     3) se aplican los parches en caliente sobre el fs nuevo
#   STATE/KERN/EFI no se tocan.
#
# Uso: sudo bash apply-free.sh <imagen.img> [opciones] [salida.img]
#      sudo bash apply-free.sh FydeOS.bin no_google_play,dgpu TapeOS-Free.img
# ==============================================================================
set -euo pipefail

BIN="$1"
OPTIONS="${2:-no_google_play}"
OUT="${3:-}"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
BR="${TAPEOOS_FRAMEWORK_DIR:-$DIR/../dist/framework}"

[ -f "$BIN" ] || { echo "Falta la imagen: $BIN"; exit 1; }

P3=$(cgpt show -i 3 -b "$BIN")
P3S=$(cgpt show -i 3 -s "$BIN")
P12=$(cgpt show -i 12 -b "$BIN")
P12S=$(cgpt show -i 12 -s "$BIN")
ROOTA_UUID=$(cgpt show -i 3 -u "$BIN")
echo "[TapeOS Free] p3@$P3+$P3S  p12@$P12+$P12S  uuid=$ROOTA_UUID"

# Copia de trabajo: nunca se modifica la imagen original
WORK="$BIN"
if [ -n "$OUT" ] && [ "$OUT" != "$BIN" ]; then
    echo "[TapeOS Free] Copiando imagen de trabajo -> $OUT ..."
    cp --sparse=always "$BIN" "$OUT"
    WORK="$OUT"
fi

LOOP3=$(losetup --show -f --sizelimit $(( P3S * 512 )) -o $(( P3 * 512 )) "$WORK")
LOOP12=$(losetup --show -f --sizelimit $(( P12S * 512 )) -o $(( P12 * 512 )) "$WORK")
cleanup() { umount /tmp/ffroot /tmp/ffesp 2>/dev/null || true; losetup -d "$LOOP3" "$LOOP12" 2>/dev/null || true; }
trap cleanup EXIT
rm -rf /tmp/free-root /tmp/ffroot /tmp/ffesp
mkdir -p /tmp/free-root /tmp/ffroot /tmp/ffesp

# 1) Leer ROOT-A (ro) y extraer el arbol preservando huecos (sparse)
echo "[TapeOS Free] Extrayendo el rootfs (ro + tar --sparse)..."
mount -o ro "$LOOP3" /tmp/ffroot
[ -f /tmp/ffroot/etc/lsb-release ] || { echo "ERROR: ROOT-A no parece un rootfs valido."; exit 1; }
TREE_BYTES=$(du -s --block-size=1 /tmp/ffroot | cut -f1)
echo "[TapeOS Free] Tamano real del rootfs: $(( TREE_BYTES / 1024 / 1024 )) MB"
( cd /tmp/ffroot && tar --sparse --numeric-owner -cf - . ) | ( cd /tmp/free-root && tar --sparse --numeric-owner -xf - )
umount /tmp/ffroot

# 2) Recrear ROOT-A: ext4 estandar, sin reserva y sin journal
PART_BYTES=$(( P3S * 512 ))
if [ "$TREE_BYTES" -gt $(( PART_BYTES - 32 * 1024 * 1024 )) ]; then
    echo "ERROR: el rootfs ($(( TREE_BYTES / 1024 / 1024 )) MB) no cabe en ROOT-A ($(( PART_BYTES / 1024 / 1024 )) MB)."
    exit 1
fi
echo "[TapeOS Free] Recreando ROOT-A (ext4 estandar, sin reserva ni journal)..."
mke2fs -t ext4 -q -F -m 0 -O ^has_journal -L ROOT-A "$LOOP3"
mount "$LOOP3" /tmp/ffroot
AVAIL=$(df -B1 --output=avail /tmp/ffroot | tail -1)
echo "[TapeOS Free] Espacio libre tras recrear: $(( AVAIL / 1024 / 1024 )) MB"

# 3) Volcar el arbol parcheado
echo "[TapeOS Free] Copiando el rootfs..."
( cd /tmp/free-root && tar --sparse --numeric-owner -cf - . ) | ( cd /tmp/ffroot && tar --sparse --numeric-owner -xf - )

# 4) Parches TapeOS en caliente
echo "[TapeOS Free] Aplicando capa TapeOS (opciones: $OPTIONS)..."
export TAPEOOS_ROOT=/tmp/ffroot
for p in "$DIR"/framework/patches/[0-9]*.sh; do
    [ -x "$p" ] || continue
    echo "  + ${p##*/}"
    "$p" "$OPTIONS" >/dev/null 2>&1 || echo "  (aviso: ${p##*/})"
done
mkdir -p /tmp/ffroot/usr/local/share/tapeos/apps
cp "$BR"/AuroraStore.apk /tmp/ffroot/usr/local/share/tapeos/apps/ 2>/dev/null || echo "  (aviso: AuroraStore.apk no encontrada)"

# 5) Rebranding FINAL (tras los parches, para que gane TapeOS Free)
sed -i 's/^CHROMEOS_RELEASE_NAME=.*/CHROMEOS_RELEASE_NAME=TapeOS Free/' /tmp/ffroot/etc/lsb-release
sed -i 's/^CHROMEOS_RELEASE_DESCRIPTION=.*/CHROMEOS_RELEASE_DESCRIPTION=TapeOS Free (sin Google, con Android)/' /tmp/ffroot/etc/lsb-release
mkdir -p /tmp/ffroot/var/lib/tapeos
touch /tmp/ffroot/var/lib/tapeos/free-applied

echo "[TapeOS Free] Verificando..."
grep -E '^CHROMEOS_RELEASE_(NAME|DESCRIPTION)=' /tmp/ffroot/etc/lsb-release
for f in /etc/lsb-release /sbin/init /usr/local/bin/tapeos-apks.sh /usr/local/share/tapeos/apps/AuroraStore.apk /etc/modprobe.d/tapeos-dgpu.conf; do
    [ -e "/tmp/ffroot$f" ] && echo "  OK  $f" || echo "  FALTA $f"
done
df -h /tmp/ffroot | tail -1
umount /tmp/ffroot

# 6) GRUB de TapeOS en la ESP (sin menu del fabricante)
mount "$LOOP12" /tmp/ffesp
mkdir -p /tmp/ffesp/efi/boot
[ -f /tmp/ffesp/efi/boot/grub.cfg ] && cp /tmp/ffesp/efi/boot/grub.cfg /tmp/ffesp/efi/boot/grub.cfg.bak
sed "s/__ROOTA_UUID__/$ROOTA_UUID/g" "$DIR/free/grub/grub.cfg" > /tmp/ffesp/efi/boot/grub.cfg
umount /tmp/ffesp
sync
cleanup
echo "TAPEOS-FREE-LISTA: $WORK"