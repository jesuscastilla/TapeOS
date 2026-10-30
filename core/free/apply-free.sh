#!/bin/bash
# ==============================================================================
# apply-free.sh - adapta una imagen FydeOS/openFyde a TapeOS Free.
#   Monta ROOT-A y ESP por OFFSET explicito (evita los loops -P stale de WSL).
#   ROOT-A de FydeOS usa features ext4 nuevos: se lee en ro, se parchea el arbol
#   y se recrea la particion con ext4 estandar.
# Uso: sudo bash apply-free.sh <imagen.img> <opciones>
# ==============================================================================
set -e
BIN="$1"
OPTIONS="${2:-no_google_play}"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
BR="${TAPEOOS_FRAMEWORK_DIR:-$DIR/../dist/framework}"

[ -f "$BIN" ] || { echo "Falta la imagen: $BIN"; exit 1; }

P3=$(cgpt show -i 3 -b "$BIN")
P12=$(cgpt show -i 12 -b "$BIN")
ROOTA_UUID=$(cgpt show -i 3 -u "$BIN")
echo "[TapeOS Free] p3@$P3 p12@$P12 uuid=$ROOTA_UUID"

LOOP3=$(losetup --show -f -o $(( P3 * 512 )) "$BIN")
LOOP12=$(losetup --show -f -o $(( P12 * 512 )) "$BIN")
cleanup() { umount /tmp/ffroot /tmp/ffesp 2>/dev/null; losetup -d "$LOOP3" "$LOOP12" 2>/dev/null; }
trap cleanup EXIT
mkdir -p /tmp/ffroot /tmp/ffesp /tmp/free-root

# 1) Leer ROOT-A (ro) y extraer el arbol
mount -o ro "$LOOP3" /tmp/ffroot
echo "[TapeOS Free] Extrayendo rootfs..."
rm -rf /tmp/free-root/*
tar -C /tmp/ffroot -cf - . | tar -C /tmp/free-root -xf -
umount /tmp/ffroot

# 2) Parches TapeOS sobre el arbol
rm -rf /tmp/free-root/etc/chrome_dev.conf.d
mkdir -p /tmp/free-root/etc/chrome_dev.conf.d /tmp/free-root/usr/local/share/tapeos/apps /tmp/free-root/usr/local/bin
export TAPEOOS_ROOT=/tmp/free-root
for p in "$DIR"/framework/patches/[0-9]*.sh; do
    [ -x "$p" ] || continue
    echo "  + ${p##*/}"
    "$p" "$OPTIONS" >/dev/null 2>&1 || echo "  (aviso: ${p##*/})"
done
cp "$BR"/AuroraStore.apk /tmp/free-root/usr/local/share/tapeos/apps/ 2>/dev/null || true
# 3) Rebranding FINAL (tras los parches, para que gane TapeOS Free)
sed -i 's/^CHROMEOS_RELEASE_NAME=.*/CHROMEOS_RELEASE_NAME=TapeOS Free/' /tmp/free-root/etc/lsb-release
sed -i 's/^CHROMEOS_RELEASE_DESCRIPTION=.*/CHROMEOS_RELEASE_DESCRIPTION=TapeOS Free (sin Google, con Android)/' /tmp/free-root/etc/lsb-release

# 4) Recrear ROOT-A con ext4 estandar y volcar el arbol parcheado
echo "[TapeOS Free] Recreando ROOT-A (ext4 estandar)..."
mke2fs -t ext4 -q -F -L ROOT-A "$LOOP3"
mount "$LOOP3" /tmp/ffroot
tar -C /tmp/free-root -cf - . | tar -C /tmp/ffroot -xf -
umount /tmp/ffroot

# 5) GRUB de TapeOS (sin menu del fabricante)
mount "$LOOP12" /tmp/ffesp
sed "s/__ROOTA_UUID__/$ROOTA_UUID/g" "$DIR/free/grub/grub.cfg" > /tmp/ffesp/efi/boot/grub.cfg
umount /tmp/ffesp
sync
cleanup
echo "TAPEOS-FREE-LISTA: $BIN"