#!/usr/bin/env bash
TAPEOOS_ROOT=${TAPEOOS_ROOT:-/roota}
# ==============================================================================
# TapeOS Patch: 50-hardware_patches.sh
# Dispatcher de parches de hardware detectados por el instalador Windows.
#
# El instalador anota en la linea del kernel las opciones de framework
# detectadas (options=iwlwifi_backport,rtl8821ce,rtbth,...). Este patch las lee
# y prepara el arranque forzando la carga de los modulos correspondientes en
# ChromeOS. Los binarios de firmware viajan con el framework TapeOS (kernel).
# ==============================================================================

MODULE_MAP="iwlwifi_backport:iwlwifi
broadcom_wl:wl
brcmfmac:brcmfmac
rtl8188eu:r8188eu
rtl8188fu:rtl8188fu
rtl8192eu:8192eu
rtl8723bs:r8723bs
rtl8723bu:8723bu
rtl8723de:rtw88_8723de
rtl8723du:rtw88_8723du
rtl8812au:88XXau
rtl8814au:8814au
rtl8821ce:rtw88_8821ce
rtl8821cu:rtw88_8821cu
rtl885xxx:rtw89pci
rtl88x2bu:rtl88x2bu
rtbth:btusb"

# Opciones que no fuerzan modulo: las gestionan los parches especificos del framework
NO_MODULE_OPTIONS="ipts_touchscreen ithc_touchscreen goodix essx8336 legacy_audio_ucm macbook_trackpad dgpu sysfs_tablet_mode"

mkdir -p $TAPEOOS_ROOT/etc/modules-load.d
load_file=$TAPEOOS_ROOT/etc/modules-load.d/tapeos-hardware.conf
rm -f "$load_file"

for opt in $(echo "$1" | sed 's#,# #g'); do
    mod=$(echo "$MODULE_MAP" | awk -F: -v o="$opt" '$1 == o { print $2 }')
    if [ -n "$mod" ]; then
        echo "$mod" >> "$load_file"
        echo "tapeos: hardware patch '$opt' -> forzando modulo $mod" > /dev/kmsg
    elif echo "$NO_MODULE_OPTIONS" | grep -qw "$opt"; then
        echo "tapeos: hardware patch '$opt' activado (lo gestiona el framework TapeOS)" > /dev/kmsg
    fi
done

if [ -s "$load_file" ]; then
    echo "tapeos: modulos de hardware forzados: $(tr '\n' ' ' < "$load_file")" > /dev/kmsg
fi

exit 0