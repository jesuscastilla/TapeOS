#!/bin/bash
# write-brunch-fast.sh <src.bin> <dst> - copia rapida de particiones Brunch
# La tabla GPT debe existir ya en el destino (la crea chromeos-install.sh).
set -e
SRC="$1"; DST="$2"
BRDIR="${TAPEOOS_FRAMEWORK_DIR:-$(cd "$(dirname "$0")/../.." && pwd)/dist/framework}"

fast_dd() {
    local img="$1" ob="$2" db="$3" bytes="$4" rem os ds sc
    if [ $(( ob % 4096 )) -eq 0 ] && [ $(( db % 4096 )) -eq 0 ] && [ $(( bytes % 4096 )) -eq 0 ]; then
        dd if="$img" iflag=skip_bytes skip="$ob" of="$DST" oflag=seek_bytes seek="$db" bs=4M conv=notrunc status=none 2>/dev/null || true
        rem=$(( bytes % 4194304 ))
        if [ "$rem" -gt 0 ]; then
            dd if="$img" iflag=skip_bytes skip=$(( ob + bytes - rem )) of="$DST" oflag=seek_bytes seek=$(( db + bytes - rem )) bs=1 count="$rem" status=none 2>/dev/null || true
        fi
    else
        os=$(( ob / 512 )); ds=$(( db / 512 )); sc=$(( bytes / 512 ))
        dd if="$img" bs=512 skip="$os" of="$DST" seek="$ds" count="$sc" conv=notrunc status=none 2>/dev/null || true
    fi
}

copy_part() {
    local num="$1" img="$2" srcnum="$3" dstart dsize ostart osize ob db bytes
    dstart=$(cgpt show -i "$num" -b "$DST")
    dsize=$(cgpt show -i "$num" -s "$DST")
    if [ "$srcnum" = "0" ]; then
        ostart=0; osize=$(( $(stat -c %s "$img") / 512 + 1 ))
    else
        ostart=$(cgpt show -i "$srcnum" -b "$img")
        osize=$(cgpt show -i "$srcnum" -s "$img")
    fi
    ob=$(( ostart * 512 )); db=$(( dstart * 512 )); bytes=$(( osize * 512 ))
    [ "$bytes" -gt $(( dsize * 512 )) ] && bytes=$(( dsize * 512 ))
    echo "part $num: $img(src $srcnum) -> $DST($num)  $(( bytes / 1048576 )) MB"
    fast_dd "$img" "$ob" "$db" "$bytes"
}

# Mismo mapeo que chromeos-install.sh (install_singleboot)
copy_part 1 "$SRC" 1
copy_part 2 "$SRC" 4
copy_part 3 "$SRC" 3
copy_part 4 "$SRC" 2
copy_part 5 "$SRC" 3
copy_part 7 "$BRDIR/rootc.img" 0
copy_part 8 "$SRC" 8
copy_part 12 "$BRDIR/efi_legacy.img" 0
sync
echo "COPIA-RAPIDA-COMPLETADA"