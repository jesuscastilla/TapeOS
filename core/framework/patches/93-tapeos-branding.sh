#!/bin/bash
# TapeOS 93: identidad TapeOS (se aplica siempre)
R="${TAPEOOS_ROOT:-/roota}"
if [ -f "$R/etc/lsb-release" ]; then
    sed -i 's/^CHROMEOS_RELEASE_NAME=.*/CHROMEOS_RELEASE_NAME=TapeOS/' "$R/etc/lsb-release"
    sed -i 's/^CHROMEOS_RELEASE_DESCRIPTION=.*/CHROMEOS_RELEASE_DESCRIPTION=TapeOS (Andalucia, software libre)/' "$R/etc/lsb-release"
fi
mkdir -p "$R/usr/local/share/tapeos"
echo "tapeos: branding aplicado" > /dev/kmsg
exit 0