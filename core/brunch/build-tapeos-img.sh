#!/bin/bash
# ==============================================================================
# build-tapeos-img.sh - genera la imagen completa TapeOS (Brunch + capa TapeOS)
# lista para grabar en CUALQUIER maquina sin WSL (Rufus, Win32DiskImager, TapeOS).
# Solo se necesita Linux/WSL en la maquina que GENERA la imagen.
# Uso: sudo bash build-tapeos-img.sh <recovery.bin> <salida.img> [GB]
# ==============================================================================
set -e
SRC_IMG="$1"
OUT_IMG="$2"
SIZE_GB="${3:-16}"
export TAPEOOS_OPTIONS="${4:-enable_updates}"
DIR="$(cd "$(dirname "$0")" && pwd)"
BR="${TAPEOOS_BRUNCH_DIR:-$DIR/../../dist/brunch}"

[ -f "$SRC_IMG" ] || { echo "Falta el recovery: $SRC_IMG"; exit 1; }
[ -n "$OUT_IMG" ] || { echo "Uso: build-tapeos-img.sh <recovery.bin> <salida.img> [GB]"; exit 1; }

echo "[TapeOS] 1/4 Creando archivo de imagen de ${SIZE_GB} GB..."
WORK_IMG="/tmp/tapeos-build.img"
rm -f "$WORK_IMG"
truncate -s "${SIZE_GB}G" "$WORK_IMG"

echo "[TapeOS] 2/4 Particionando (layout Brunch)..."
bash "$DIR/brunch-partition.sh" "$WORK_IMG"

echo "[TapeOS] 3/4 Copiando particiones (rapido, offsets en bytes)..."
bash "$DIR/write-brunch-fast.sh" "$SRC_IMG" "$WORK_IMG"

echo "[TapeOS] 4/4 Aplicando la capa TapeOS (parches, Aurora, GRUB)..."
LOOP=$(losetup --show -fP "$WORK_IMG")
cleanup() { umount /tmp/tp7 /tmp/tp12 2>/dev/null; losetup -d "$LOOP" 2>/dev/null; }
trap cleanup EXIT
mkdir -p /tmp/tp7 /tmp/tp12
mount "${LOOP}p7" /tmp/tp7
mount "${LOOP}p12" /tmp/tp12
cp "$DIR"/patches/[0-9]*.sh /tmp/tp7/patches/
mkdir -p /tmp/tp7/tapeos/bin /tmp/tp7/tapeos/apps /tmp/tp7/tapeos/lib
cp "$DIR"/tapeos-install.sh /tmp/tp7/tapeos/
cp "$BR"/tapeos-tools/bin/* /tmp/tp7/tapeos/bin/
cp -r "$BR"/tapeos-tools/lib/* /tmp/tp7/tapeos/lib/
cp "$BR"/AuroraStore.apk /tmp/tp7/tapeos/apps/
sed "s/__TAPEOOS_OPTIONS__/${TAPEOOS_OPTIONS:-enable_updates}/g" "$DIR"/grub/grub.cfg > /tmp/tp12/efi/boot/grub.cfg
cp "$DIR"/grub/settings.cfg /tmp/tp12/efi/boot/settings.cfg
sed -i 's/\r$//' /tmp/tp7/patches/[0-9]*.sh /tmp/tp7/tapeos/tapeos-install.sh
chmod +x /tmp/tp7/patches/[0-9]*.sh /tmp/tp7/tapeos/tapeos-install.sh /tmp/tp7/tapeos/bin/*
sync
cleanup
cp --sparse=always "$WORK_IMG" "$OUT_IMG"
rm -f "$WORK_IMG"
echo "IMAGEN-TAPEOS-LISTA: $OUT_IMG"