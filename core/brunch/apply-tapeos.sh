#!/bin/bash
# ==============================================================================
# apply-tapeos.sh - aplica la capa TapeOS sobre una instalacion Brunch
# Uso (en WSL/Linux, con el disco en --bare): sudo bash apply-tapeos.sh /dev/sdX
# ==============================================================================
set -e
DISK="$1"
[ -n "$DISK" ] || { echo "Uso: apply-tapeos.sh /dev/sdX"; exit 1; }
SRC="$(cd "$(dirname "$0")/../.." && pwd)"
P7=/tmp/tapeos-p7
P12=/tmp/tapeos-p12
mkdir -p $P7 $P12
mount "${DISK}7" $P7
mount "${DISK}12" $P12

# 1) Parches de TapeOS (se ejecutan en cada arranque, segun options=)
cp "$SRC"/core/brunch/patches/[0-9]*.sh $P7/patches/

# 2) Instalador a disco + herramientas (resize2fs/e2fsck + libs)
mkdir -p $P7/tapeos/bin $P7/tapeos/apps $P7/tapeos/lib
cp "$SRC"/core/brunch/tapeos-install.sh $P7/tapeos/
cp "$SRC"/dist/brunch/tapeos-tools/bin/* $P7/tapeos/bin/
cp -r "$SRC"/dist/brunch/tapeos-tools/lib/* $P7/tapeos/lib/
cp "$SRC"/dist/brunch/AuroraStore.apk $P7/tapeos/apps/

# 3) GRUB de TapeOS (sin menu de configuracion de Brunch)
cp "$SRC"/core/brunch/grub/grub.cfg $P12/efi/boot/grub.cfg
cp "$SRC"/core/brunch/grub/settings.cfg $P12/efi/boot/settings.cfg

# 4) Normalizar y permisos
sed -i 's/\r$//' $P7/patches/[0-9]*.sh $P7/tapeos/tapeos-install.sh
chmod +x $P7/patches/[0-9]*.sh $P7/tapeos/tapeos-install.sh $P7/tapeos/bin/*
sync
umount $P7 $P12
echo "TapeOS aplicado sobre $DISK"