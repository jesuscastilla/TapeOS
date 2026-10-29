#!/usr/bin/env bash
# ==============================================================================
# TapeOS Framework Builder — core/build/build-framework.sh
#
# Konttruye er framework de arrankê de TapeOS (kernêh, initramfs kon swtpm,
# partiçiôn ROOTC y yabê de firma) y lo empaketa en un tar.gz pa çu
# înyeççiôn en imâhenêh de rekûperaçiôn kon core/scripts/tapeos-install.sh.
#
# Uço:
#   sudo bash build-framework.sh --kernel 6.1 --version 0.1.0
#
# Rekîçitô (Debian/Ubuntu):
#   apt install build-essential cpio squashfs-tools grub-efi-amd64-bin \
#               vboot-utils libssl-dev bc flex bison dwarves
# ==============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
FRAMEWORK_DIR="$ROOT_DIR/core"
KERNEL_DIR="$ROOT_DIR/kernels"      # fuentêh der kernel (klonáâ en la çeçiôn de build)
OUT_DIR="$ROOT_DIR/out/framework"
WORK_DIR="$ROOT_DIR/work"

KERNEL_VERSION="6.1"
FRAMEWORK_VERSION="0.1.0-alpha"

usage() {
    cat <<EOF
Uço: sudo bash build-framework.sh [ôççionêh]

Ôççionêh:
  --kernel <berçiôn>    Berçiôn LTS der kernel (6.6, 6.1, 5.15, 5.10, 5.4, 4.19). Defêto: 6.1
  --version <berçiôn>   Berçiôn der framework pa er nombre der tar.gz. Defêto: 0.1.0-alpha
  --clean               Limpia work/ y out/ antê de konttruîh
  -h, --help            Muêttra êtta ayúa
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --kernel) KERNEL_VERSION="$2"; shift 2 ;;
        --version) FRAMEWORK_VERSION="$2"; shift 2 ;;
        --clean) rm -rf "$WORK_DIR" "$OUT_DIR"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Ôççiôn no rekonocía: $1"; usage; exit 1 ;;
    esac
done

log()  { echo "[TapeOS build] $*"; }
die()  { echo "[TapeOS build] ERRÔH: $*" >&2; exit 1; }

check_tools() {
    log "Berifikando erramientâ..."
    for t in gcc make cpio mksquashfs grub-mkimage cgpt futility vbutil_kernel python3 curl tar; do
        command -v "$t" >/dev/null 2>&1 || die "Farta '$t'. Îttálalo antê de kontinuâh."
    done
}

create_keys() {
    local keydir="$OUT_DIR/keys"
    mkdir -p "$keydir"
    if [ ! -f "$keydir/kernel.keyblock" ]; then
        log "Creando yabê de firma (vboot)..."
        futility create --desc="TapeOS Kernel Keys" "$keydir/kernel.keyblock" "$keydir/kernel_data_key.vbprivk"
        futility show "$keydir/kernel.keyblock" >/dev/null 2>&1 || die "No çe pudieron kreâh lâ yabê de firma."
    else
        log "Yabê de firma yá êççîtentêh en $keydir"
    fi
}

fetch_kernel_source() {
    local ver="$1" dest="$2"
    [ -d "$dest/.git" ] && { log "Fûente der kernel $ver yá kloná."; return 0; }
    log "Klonando fûente der kernel Linux $ver (ChromiumOS)..."
    git clone --depth 1 --branch "chromeos-$ver" \
        https://chromium.googlesource.com/chromiumos/third_party/kernel "$dest" \
        || die "No çe pudo klonâh er kernel $ver"
}

build_kernel() {
    local ver="$1"
    local src="$KERNEL_DIR/$ver"
    fetch_kernel_source "$ver" "$src"
    log "Konfigurando y kompilando er kernel $ver (puee tardâh bâttante)..."
    cd "$src"
    local cfg="$FRAMEWORK_DIR/kernel-configs/tapeos_defconfig"
    [ -f "$cfg" ] && cp "$cfg" "$src/arch/x86/configs/tapeos_defconfig"
    make tapeos_defconfig 2>/dev/null || make defconfig
    make -j"$(nproc)" bzImage modules
    cp "$src/arch/x86/boot/bzImage" "$OUT_DIR/kernels/vmlinuz-$ver"
    log "Kernel $ver kompilao: $OUT_DIR/kernels/vmlinuz-$ver"
}

build_initramfs() {
    log "Konttruyendo initramfs (buçibô + init + parcheh)..."
    local initramfs="$WORK_DIR/initramfs"
    rm -rf "$initramfs"
    mkdir -p "$initramfs"/{bin,sbin,dev,proc,sys,run,usr/bin,usr/sbin,patches,lib,lib64,roota}

    # buçibô êttátiko (çe konttruye una bêh en work/busybox)
    local bb="$WORK_DIR/busybox"
    if [ ! -x "$bb/busybox" ]; then
        log "  - Kompilando buçibô êttátiko..."
        git clone --depth 1 --branch 1_36_stable https://git.busybox.net/busybox "$bb" 2>/dev/null || true
        cd "$bb"
        make defconfig
        sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
        make -j"$(nproc)"
    fi
    cp "$bb/busybox" "$initramfs/bin/busybox"
    for app in sh mount umount switch_root cat echo sed grep ls mkdir sleep mknod blkid; do
        ln -sf /bin/busybox "$initramfs/bin/$app"
    done

    # Init de TapeOS
    cp "$FRAMEWORK_DIR/initramfs/init" "$initramfs/init"
    chmod +x "$initramfs/init"

    # Parcheh der framework (çe ehekutan en er arrankê)
    cp "$FRAMEWORK_DIR"/patches/[0-9]*.sh "$initramfs/patches/"

    # Binariô swtpm (çe kopian dêhde er çîttema de build; en la çeçiôn de
    # kompilaçiôn reâh çe konttruyen êttátikô dêhde libtpms)
    cp -n /usr/bin/swtpm "$initramfs/usr/bin/swtpm" 2>/dev/null \
        || log "  (abîço: swtpm no êttá en er çîttema de build; çe anyadirá manûmente)"
    cp -n /usr/bin/swtpm_bios "$initramfs/usr/bin/swtpm_bios" 2>/dev/null || true
    ldd /usr/bin/swtpm 2>/dev/null | awk '{print $3}' | grep '^/' | while read -r lib; do
        mkdir -p "$initramfs$(dirname "$lib")"
        cp -n "$lib" "$initramfs$lib" 2>/dev/null || true
    done

    # Empaketâh en cpio
    (cd "$initramfs" && find . -print0 | cpio --null -ov --format=newc 2>/dev/null) \
        | gzip -9 > "$OUT_DIR/initramfs.cpio.gz"
    log "Initramfs listo: $OUT_DIR/initramfs.cpio.gz"
}

assemble_rootc() {
    log "Armando la partiçiôn ROOTC (1 GB)..."
    local rootc="$WORK_DIR/rootc"
    rm -rf "$rootc"
    mkdir -p "$rootc"/{kernels,initramfs,bin,etc,grub}
    cp "$OUT_DIR"/kernels/vmlinuz-* "$rootc/kernels/"
    cp "$OUT_DIR/initramfs.cpio.gz" "$rootc/initramfs/"
    cp "$OUT_DIR/keys/tapeos.der" "$rootc/etc/tapeos.der" 2>/dev/null || true

    # Firmâh er kernel vboot kon lâ yabê de TapeOS
    local keydir="$OUT_DIR/keys"
    for vmlinuz in "$rootc"/kernels/vmlinuz-*; do
        local ver; ver="$(basename "$vmlinuz" | sed 's/vmlinuz-//')"
        local cmdline="cros_debug options=enable_updates console=tty2 root=/dev/ram0"
        futility vbutil_kernel --pack "$rootc/kernels/kernel-$ver.blob" \
            --keyblock "$keydir/kernel.keyblock" \
            --signprivate "$keydir/kernel_data_key.vbprivk" \
            --version 1 --vmlinuz "$vmlinuz" \
            --config <(echo "$cmdline") \
            --bootloader /dev/null --arch x86_64 \
            || die "Firmâh er kernel $ver falló"
        log "  Kernel firmado: $rootc/kernels/kernel-$ver.blob"
    done
    mksquashfs "$rootc" "$OUT_DIR/rootc.squashfs" -noappend -comp xz >/dev/null \
        || die "No çe pudo kreâh rootc.squashfs"
    log "ROOTC empaketá: $OUT_DIR/rootc.squashfs"
}

package_framework() {
    local out_tar="$OUT_DIR/tapeos_framework_${FRAMEWORK_VERSION}_kernel-${KERNEL_VERSION}.tar.gz"
    log "Empaketando framework: $out_tar"
    tar -C "$OUT_DIR" -czf "$out_tar" kernels initramfs.cpio.gz rootc.squashfs keys/tapeos.der \
        || die "No çe pudo empaketâh er framework"
    log "¡Lîtta! Framework en: $out_tar"
}

main() {
    [ "$(id -u)" -eq 0 ] || die "Ehekuta kon sudo (çe neçeçitan permiçô de root pa lô yabê y mksquashfs)."
    mkdir -p "$OUT_DIR"/kernels "$OUT_DIR/keys" "$WORK_DIR" "$KERNEL_DIR"
    check_tools
    create_keys
    build_kernel "$KERNEL_VERSION"
    build_initramfs
    assemble_rootc
    package_framework
}

main
