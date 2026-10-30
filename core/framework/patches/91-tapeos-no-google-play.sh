#!/bin/bash
# TapeOS 91: modo sin Google Play + Aurora Store - opcion "no_google_play"
ngp=0
for i in $(echo "$1" | sed 's/,/ /g'); do [ "$i" = "no_google_play" ] && ngp=1; done
[ $ngp -eq 1 ] || exit 0
R="${TAPEOOS_ROOT:-/roota}"
# 1) Deshabilitar la Play Store (com.android.vending)
for v in "$R"/opt/google/containers/android/rootfs/root/data/data/com.android.vending* "$R"/opt/google/containers/android/rootfs/root/data/app/*com.android.vending*; do
    [ -e "$v" ] && rm -rf "$v"
done
# 2) Aurora Store: copiar la APK al rootfs (la deja ROOT-C en /tapeos/apps)
mkdir -p "$R/usr/local/share/tapeos/apps" "$R/usr/local/bin"
for apk in /rootc/tapeos/apps/*.apk /tapeos/apps/*.apk; do
    [ -f "$apk" ] && cp "$apk" "$R/usr/local/share/tapeos/apps/" 2>/dev/null
done
# 3) Helper para el primer arranque
cat > "$R/usr/local/bin/tapeos-apks.sh" <<'EOF'
#!/bin/bash
src=/usr/local/share/tapeos/apps
mkdir -p /home/*/Downloads 2>/dev/null
cp $src/*.apk /home/*/Downloads/ 2>/dev/null
cat <<MSG
TapeOS - Tienda libre (Aurora Store)
1) Abre Archivos -> Descargas.
2) Toca AuroraStore.apk e instala (permite "fuentes desconocidas").
3) Entra con tu cuenta (anonima o Google) y usa la tienda.
MSG
EOF
chmod +x "$R/usr/local/bin/tapeos-apks.sh"
touch "$R/var/lib/tapeos/no_google_play" 2>/dev/null || true
echo "tapeos: modo sin Google Play aplicado (Aurora Store lista)" > /dev/kmsg
exit 0