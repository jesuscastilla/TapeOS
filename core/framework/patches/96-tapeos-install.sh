#!/bin/bash
# TapeOS 96: instalador a disco duro - opcion "install_tapeos"
# Vuelca el USB completo al disco elegido, arregla la GPT y expande ROOT-A.
ins=0
for i in $(echo "$1" | sed 's/,/ /g'); do [ "$i" = "install_tapeos" ] && ins=1; done
[ $ins -eq 1 ] || exit 0
for c in /rootc/tapeos/tapeos-install.sh /tapeos/tapeos-install.sh; do
    if [ -x "$c" ]; then
        echo "tapeos: iniciando instalador a disco duro..." > /dev/kmsg
        exec "$c"
    fi
done
echo "tapeos: instalador no encontrado en ROOT-C" > /dev/kmsg
exit 1