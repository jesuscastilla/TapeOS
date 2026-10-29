#!/bin/bash
# TapeOS 95: memoria - zram al 150% de la RAM (se aplica siempre)
R="${TAPEOOS_ROOT:-/roota}"
mkdir -p "$R/etc/init" "$R/usr/local/sbin"
cat > "$R/etc/init/tapeos-zram.conf" <<'EOF'
start on started system-services
script
    RAMKB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    SIZE=$(( RAMKB * 150 / 100 ))
    echo ${SIZE}K > /sys/block/zram0/disksize 2>/dev/null
end script
EOF
echo "tapeos: zram configurado al 150% de la RAM" > /dev/kmsg
exit 0