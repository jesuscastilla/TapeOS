#!/bin/bash
# ==============================================================================
# install-brunch-usb.sh - instala Brunch + capa TapeOS en un disco (via WSL --bare)
# Uso: sudo bash install-brunch-usb.sh <recovery.bin> /dev/sdX
# ==============================================================================
set -e
SRC="$1"
DISK="$2"
DIR="$(cd "$(dirname "$0")" && pwd)"
export TAPEOOS_BRUNCH_DIR="${3:-}"
export TAPEOOS_OPTIONS="${4:-enable_updates}"
[ -f "$SRC" ] || { echo "Falta el recovery: $SRC"; exit 1; }
[ -n "$DISK" ] || { echo "Uso: install-brunch-usb.sh <recovery.bin> /dev/sdX"; exit 1; }

echo "[TapeOS] 1/3 Particionando $DISK (layout Brunch)..."
umount "${DISK}"* 2>/dev/null || true
bash "$DIR/brunch-partition.sh" "$DISK"

echo "[TapeOS] 2/3 Copiando particiones (rapido, offsets en bytes)..."
bash "$DIR/write-brunch-fast.sh" "$SRC" "$DISK"

echo "[TapeOS] 3/3 Aplicando la capa TapeOS (parches, Aurora, GRUB)..."
bash "$DIR/apply-tapeos.sh" "$DISK"

echo "[TapeOS] BRUNCH+TAPEOS INSTALADO en $DISK"