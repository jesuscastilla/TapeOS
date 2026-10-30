#!/bin/bash
# ==============================================================================
# apply-tapeos.sh - aplica la capa TapeOS sobre una instalacion del framework
# Uso (en WSL/Linux, con el disco en --bare): sudo bash apply-tapeos.sh /dev/sdX
# ==============================================================================
set -e
DISK="$1"
[ -n "$DISK" ] || { echo "Uso: apply-tapeos.sh /dev/sdX"; exit 1; }
SRC="$(cd "$(dirname "$0")/../.." && pwd)"
BR="${TAPEOOS_FRAMEWORK_DIR:-$SRC/dist/framework}"
P7=/tmp/tapeos-p7
P12=/tmp/tapeos-p12
mkdir -p $P7 $P12
mount "${DISK}7" $P7
mount "${DISK}12" $P12

# 1) Parches de TapeOS (se ejecutan en cada arranque, segun options=)
cp "$SRC"/core/framework/patches/[0-9]*.sh $P7/patches/

# 2) Instalador a disco + herramientas (resize2fs/e2fsck + libs)
mkdir -p $P7/tapeos/bin $P7/tapeos/apps $P7/tapeos/lib
cp "$SRC"/core/framework/tapeos-install.sh $P7/tapeos/
cp "$BR"/tapeos-tools/bin/* $P7/tapeos/bin/
cp -r "$BR"/tapeos-tools/lib/* $P7/tapeos/lib/
cp "$BR"/AuroraStore.apk $P7/tapeos/apps/

# 3) GRUB de TapeOS (sin menus de configuracion del framework base)
# 3b) Identidad TapeOS en el initramfs del framework (mensajes propios)
rm -rf /tmp/irfs; mkdir -p /tmp/irfs
zcat $P7/initramfs.img | ( cd /tmp/irfs && cpio -idm --quiet 2>/dev/null )
if [ -f /tmp/irfs/init ]; then
    sed -i "s/brunch:/tapeos:/g" /tmp/irfs/init
    ( cd /tmp/irfs && find . -print0 | cpio --null -o --format=newc 2>/dev/null | gzip -9 > $P7/initramfs.img.new )
    mv $P7/initramfs.img.new $P7/initramfs.img
    echo "[TapeOS] initramfs con identidad TapeOS"
fi
sed "s/__TAPEOOS_OPTIONS__/${TAPEOOS_OPTIONS:-enable_updates}/g" "$SRC"/core/framework/grub/grub.cfg > $P12/efi/boot/grub.cfg
cp "$SRC"/core/framework/grub/settings.cfg $P12/efi/boot/settings.cfg

# 3c) GRUB BIOS (i386-pc): arranque sin UEFI (imagenes hibridas)
if ! command -v grub-install >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y grub-pc-bin grub2-common >/dev/null 2>&1 || true
fi
if [ -x /usr/sbin/grub-install ]; then
    mkdir -p $P7/grub
    cp "$SRC"/core/framework/grub/grub.cfg $P7/grub/grub.cfg
    /usr/sbin/grub-install --target=i386-pc --boot-directory=$P7 --recheck --no-floppy "$DISK" 2>/dev/null \
        && echo "[TapeOS] GRUB BIOS (sin UEFI) instalado" \
        || echo "[TapeOS] aviso: GRUB BIOS no instalado"
fi

# 4) Normalizar y permisos
sed -i 's/\r$//' $P7/patches/[0-9]*.sh $P7/tapeos/tapeos-install.sh
chmod +x $P7/patches/[0-9]*.sh $P7/tapeos/tapeos-install.sh $P7/tapeos/bin/*
sync
umount $P7 $P12
echo "TapeOS aplicado sobre $DISK"