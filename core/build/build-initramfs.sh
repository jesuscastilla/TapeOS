#!/usr/bin/env bash
# ==============================================================================
# TapeOS Framework Builder: initramfs - core/build/build-initramfs.sh
#
# Construye el initramfs de arranque de TapeOS SIN compilar kernel:
#   busybox estatico + herramientas de particionado (cgpt/sgdisk/e2fsprogs)
#   + /init + instalador a disco + parches + swtpm (si esta instalado).
#
# El initramfs se carga desde la ESP del medio (GRUB: initrd /tapeos/initramfs.img)
# junto al kernel del recovery de ChromeOS (/syslinux/vmlinuz.A).
#
# Uso (WSL/Linux, como root):
#   sudo bash build-initramfs.sh /mnt/g/TapeOS/dist/tapeos-initramfs.cpio.gz
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CORE_DIR="$ROOT_DIR/core"
STAGE="${TAPEOOS_STAGE:-/tmp/tapeos-initramfs-build}"
OUT="${1:-$ROOT_DIR/dist/tapeos-initramfs.cpio.gz}"

log() { echo "[TapeOS initramfs] $*"; }

# --- 1. Dependencias ----------------------------------------------------------
DEB_NEEDED=""
need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        DEB_NEEDED="$DEB_NEEDED $2"
    fi
}
need cpio cpio
need gzip gzip
need busybox busybox-static
need cgpt vboot-utils
need sgdisk gdisk
need sfdisk util-linux
need resize2fs e2fsprogs
need e2fsck e2fsprogs
need partprobe parted
need blkid util-linux
need mkfs.vfat dosfstools
need du coreutils
need swtpm swtpm

if [ -n "$DEB_NEEDED" ]; then
    log "Instalando paquetes:$DEB_NEEDED"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y $DEB_NEEDED >/dev/null 2>&1
fi

# --- 2. Estructura y binarios -------------------------------------------------
rm -rf "$STAGE"
mkdir -p "$STAGE"/{bin,sbin,usr/bin,dev,proc,sys,run,tmp,etc,patches,lib,roota,boot,mnt}

add_bin() {
    # add_bin <binario> <ruta-dentro-del-initramfs>
    local src
    src="$(command -v "$1" 2>/dev/null || true)"
    if [ -z "$src" ]; then
        log "  !! omitido (no instalado): $1"
        return 0
    fi
    local dst="$STAGE/$2"
    mkdir -p "$(dirname "$dst")"
    cp -L "$src" "$dst"
    chmod +x "$dst"
    # Cargador dinamico: copiarlo a las rutas estandar
    local ld
    for ld in /lib64/ld-linux-x86-64.so.2 /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2; do
        if [ -e "$ld" ] || [ -L "$ld" ]; then
            mkdir -p "$STAGE$(dirname "$ld")"
            cp -L "$ld" "$STAGE$ld"
        fi
    done
    for lib in $(ldd "$src" 2>/dev/null | awk '/=> \// {print $3} /^\// {print $1}'); do
        mkdir -p "$STAGE$(dirname "$lib")"
        cp -L "$lib" "$STAGE$lib"
    done
    log "  + $1 -> $2"
}

log "Anadiendo busybox estatico y applets..."
add_bin busybox bin/busybox
for app in sh mount umount switch_root cat cp dd echo grep ls mkdir mknod sleep blkid df du head tail wc rm mv sed sort find expr test ps kill sync true false printf awk xargs chmod chroot poweroff reboot halt; do
    ln -sf /bin/busybox "$STAGE/bin/$app"
done

log "Anadiendo herramientas de particionado..."
add_bin cgpt sbin/cgpt
add_bin sgdisk sbin/sgdisk
add_bin sfdisk sbin/sfdisk
add_bin resize2fs sbin/resize2fs
add_bin e2fsck sbin/e2fsck
add_bin partprobe sbin/partprobe
add_bin blkid sbin/blkid
add_bin mkfs.vfat sbin/mkfs.vfat

log "Anadiendo swtpm (TPM 2.0 por software) si esta disponible..."
add_bin swtpm usr/bin/swtpm
add_bin swtpm_setup usr/bin/swtpm_setup

log "Copiando scripts de TapeOS..."
cp "$CORE_DIR/initramfs/init" "$STAGE/init"
cp "$CORE_DIR/scripts/tapeos-install.sh" "$STAGE/lib/tapeos-install.sh"
cp "$CORE_DIR"/patches/[0-9]*.sh "$STAGE/patches/" 2>/dev/null || true
for f in "$STAGE/init" "$STAGE/lib/tapeos-install.sh" "$STAGE"/patches/*.sh; do
    sed -i 's/\r$//' "$f"
    chmod +x "$f"
done

# --- 3. Empaquetado -----------------------------------------------------------
mkdir -p "$(dirname "$OUT")"
log "Empaquetando $OUT ..."
( cd "$STAGE" && find . -print0 | cpio --null -ov --format=newc 2>/dev/null ) | gzip -9 > "$OUT"
log "Initramfs listo: $OUT"
log "Tamano: $(du -h "$OUT" | cut -f1)"
log "Primeras entradas del cpio:"
gzip -dc "$OUT" | cpio -t 2>/dev/null | head -30