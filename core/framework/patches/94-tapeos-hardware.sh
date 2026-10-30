#!/bin/bash
# TapeOS 94: parches de hardware adicionales (WiFi/Bluetooth/audio/tactil)
# Opciones: iwlwifi_backport, essx8336, legacy_audio_ucm, ipts_touchscreen,
#           ithc_touchscreen, goodix, macbook_trackpad
R="${TAPEOOS_ROOT:-/roota}"
MODS=""
for i in $(echo "$1" | sed 's/,/ /g'); do
    case "$i" in
        iwlwifi_backport) MODS="$MODS iwlwifi"; echo "options iwlwifi swcrypto=1 11n_disable=8" >> "$R/etc/modprobe.d/tapeos-hardware.conf" 2>/dev/null ;;
        essx8336) MODS="$MODS snd_soc_essx8336" ;;
        legacy_audio_ucm) MODS="$MODS snd_soc_rt5640 snd_soc_nau8825" ;;
        ipts_touchscreen) MODS="$MODS ipts intel_ipts" ;;
        ithc_touchscreen) MODS="$MODS ithc ithc_ts" ;;
        goodix) MODS="$MODS goodix_ts" ;;
        macbook_trackpad) MODS="$MODS applespi appletb" ;;
    esac
done
if [ -n "$MODS" ]; then
    mkdir -p "$R/etc/modules-load.d" "$R/etc/modprobe.d"
    for m in $MODS; do echo "$m" >> "$R/etc/modules-load.d/tapeos-hardware.conf"; done
    echo "tapeos: modulos de hardware forzados:$MODS" > /dev/kmsg
fi
exit 0