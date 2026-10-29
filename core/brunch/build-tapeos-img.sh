#!/bin/bash
# ==============================================================================
# build-tapeos-img.sh - genera una imagen completa TapeOS (Brunch + capa TapeOS)
# lista para grabar con Rufus/Win32DiskImager o desde el instalador TapeOS.
# Uso (WSL/Linux): sudo bash build-tapeos-img.sh <recovery.bin> <salida.img> [GB]
# ==============================================================================
set -e
SRC_IMG="$1"
OUT_IMG="$2"
SIZE_GB="${3:-16}"
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BR="$DIR/dist/brunch"

[ -f "$SRC_IMG" ] || { echo "Falta el recovery: $SRC_IMG"; exit 1; }
[ -n "$OUT_IMG" ] || { echo "Uso: build-tapeos-img.sh <recovery.bin> <salida.img> [GB]"; exit 1; }

echo "[TapeOS] Creando imagen Brunch de ${SIZE_GB} GB..."
( cd "$BR" && echo yes | bash chromeos-install.sh -s "$SIZE_GB" -l -src "$SRC_IMG" -dst "$OUT_IMG" )

echo "[TapeOS] Aplicando la capa TapeOS sobre la imagen..."
LOOP=$(losetup --show -fP "$OUT_IMG")
cleanup() { umount /tmp/tp7 /tmp/tp12 2>/dev/null; losetup -d "$LOOP" 2>/dev/null; }
trap cleanup EXIT
mkdir -p /tmp/tp7 /tmp/tp12
mount "${LOOP}p7" /tmp/tp7
mount "${LOOP}p12" /tmp/tp12

cp "$DIR"/core/brunch/patches/[0-9]*.sh /tmp/tp7/patches/
mkdir -p /tmp/tp7/tapeos/bin /tmp/tp7/tapeos/apps /tmp/tp7/tapeos/lib
cp "$DIR"/core/brunch/tapeos-install.sh /tmp/tp7/tapeos/
cp "$BR"/tapeos-tools/bin/* /tmp/tp7/tapeos/bin/
cp -r "$BR"/tapeos-tools/lib/* /tmp/tp7/tapeos/lib/
cp "$BR"/AuroraStore.apk /tmp/tp7/tapeos/apps/
cp "$DIR"/core/brunch/grub/grub.cfg /tmp/tp12/efi/boot/grub.cfg
cp "$DIR"/core/brunch/grub/settings.cfg /tmp/tp12/efi/boot/settings.cfg
sed -i 's/\r$//' /tmp/tp7/patches/[0-9]*.sh /tmp/tp7/tapeos/tapeos-install.sh
chmod +x /tmp/tp7/patches/[0-9]*.sh /tmp/tp7/tapeos/tapeos-install.sh /tmp/tp7/tapeos/bin/*
sync
cleanup
echo "[TapeOS] Imagen completa lista: $OUT_IMG"