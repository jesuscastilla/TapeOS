#!/usr/bin/env bash
# ==============================================================================
# TapeOS Patch: 40-no_google_play.sh
# Modo "Sin Google Play": conserva el contenedor Android (ARC) para poder
# instalar aplicaciones APK, pero sin los servicios de Google:
#  - Deshabilita la Play Store eliminando sus datos del contenedor Android.
#  - Prepara la tienda alternativa (Aurora Store / F-Droid): las APK las
#    incluye el framework en /roota/usr/local/share/tapeos/apps/ y un
#    asistente las copia a ~/Downloads tras el primer arranque.
# Se activa con la opcion de framework "no_google_play" (options=no_google_play).
# ==============================================================================

no_google_play=0
for i in $(echo "$1" | sed 's#,# #g'); do
    if [ "$i" == "no_google_play" ]; then no_google_play=1; fi
done
if [ "$no_google_play" -eq 0 ]; then exit 0; fi

echo "[TapeOS] Modo sin Google Play: conservando Android (APK) y preparando Aurora Store..." > /dev/kmsg

ret=0

# 1) Deshabilitar la Play Store (com.android.vending) si el contenedor esta montado
for vending in \
    /roota/opt/google/containers/android/rootfs/root/data/data/com.android.vending \
    /roota/opt/google/containers/android/rootfs/root/data/app/*com.android.vending* ; do
    if [ -e "$vending" ]; then
        rm -rf "$vending"
        echo "[TapeOS] Play Store deshabilitada: $vending" > /dev/kmsg
    fi
done

# 2) Preparar las APK de la tienda alternativa (Aurora Store / F-Droid)
mkdir -p /roota/usr/local/share/tapeos/apps /roota/usr/local/bin

cat > /roota/usr/local/bin/tapeos-apks.sh <<'HELPER'
#!/bin/bash
# Asistente TapeOS: copia las APK de la tienda alternativa a ~/Downloads
src=/usr/local/share/tapeos/apps
user=$(whoami 2>/dev/null)
[ -z "$user" ] && user=user
dst=/home/$user/Downloads
mkdir -p "$dst"
if ls "$src"/*.apk >/dev/null 2>&1; then
    cp "$src"/*.apk "$dst"/
    echo "APK copiadas a $dst"
    echo "Pasos: Ajustes de Android -> Seguridad -> Fuentes desconocidas -> instala Aurora Store."
else
    echo "No se encontraron APK en $src (las incluye el framework TapeOS)."
fi
HELPER
chmod +x /roota/usr/local/bin/tapeos-apks.sh

# 3) Marca para el primer arranque
touch /roota/var/lib/tapeos/no_google_play 2>/dev/null || true

echo "[TapeOS] Modo sin Google Play aplicado (ret=$ret)." > /dev/kmsg
exit $ret