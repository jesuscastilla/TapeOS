#!/usr/bin/env bash
# ==============================================================================
# TapeOS Patch: 40-no_google_apps.sh
# Modo "Sin Google Apps": elimina la configuración ARC (Android / Play Store)
# del config unibuild de ChromeOS para que el contenedor Android no arranque.
#
# Se activa con la opción de framework "no_google_apps" en la línea del kernel
# (options=no_google_apps), siguiendo el patrón de 80-unibuild.sh de Brunch:
# los parches reciben la lista de opciones como $1 separada por comas.
# ==============================================================================

no_google_apps=0
for i in $(echo "$1" | sed 's#,# #g')
do
    if [ "$i" == "no_google_apps" ]; then no_google_apps=1; fi
done

if [ "$no_google_apps" -eq 0 ]; then
    exit 0
fi

echo "[TapeOS] Modo sin Google Apps: eliminando configuración ARC (Android / Play Store)..." > /dev/kmsg

ret=0

# 1) Config unibuild en formato JSON: eliminar el bloque "arc" completo.
#    Sin la sección arc, ChromeOS no habilita el contenedor Android ni la Play Store.
if [ -f /roota/usr/share/chromeos-config/config.json ]; then
    if command -v python3 >/dev/null 2>&1; then
        python3 - <<'EOF'
import json
p = "/roota/usr/share/chromeos-config/config.json"
with open(p) as f:
    data = json.load(f)
def strip_arc(d):
    if isinstance(d, dict):
        d.pop("arc", None)
        for v in d.values():
            strip_arc(v)
    elif isinstance(d, list):
        for v in d:
            strip_arc(v)
strip_arc(data)
with open(p, "w") as f:
    json.dump(data, f, indent=2)
EOF
        if [ ! "$?" -eq 0 ]; then ret=$((ret + (2 ** 0))); fi
    else
        # Fallback sin python3 (best-effort): eliminar bloques "arc" por rango de líneas.
        sed -i '/"arc"[[:space:]]*:[[:space:]]*{/,/^[[:space:]]*}[,]*$/d' /roota/usr/share/chromeos-config/config.json
    fi
fi

# 2) Config unibuild en formato squashfs (configfs.img): regenerar sin la
#    sección arc si las herramientas están disponibles en el initramfs de TapeOS.
if [ -f /roota/usr/share/chromeos-config/configfs.img ] && command -v mksquashfs >/dev/null 2>&1 && command -v unsquashfs >/dev/null 2>&1; then
    rm -rf /tmp/configfs_noga
    unsquashfs -d /tmp/configfs_noga /roota/usr/share/chromeos-config/configfs.img > /dev/null
    rm -rf /tmp/configfs_noga/v1/chromeos/configs/0/arc
    mksquashfs /tmp/configfs_noga /roota/usr/share/chromeos-config/configfs.img > /dev/null
    if [ ! "$?" -eq 0 ]; then ret=$((ret + (2 ** 1))); fi
    rm -rf /tmp/configfs_noga
fi

# 3) Red de seguridad: deshabilitar el lanzamiento de servicios ARC/Android si existen.
for svc in arcvm arc-setup arc-sdcard arc-obb-mounter; do
    if [ -f "/roota/etc/init/$svc.conf" ]; then
        sed -i 's/^start on/stop on/' "/roota/etc/init/$svc.conf"
    fi
done

echo "[TapeOS] Modo sin Google Apps aplicado (ret=$ret)." > /dev/kmsg
exit $ret