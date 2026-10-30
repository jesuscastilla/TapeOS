#!/bin/bash
# TapeOS 97: terminal Linux (Crostini) y Centro de software desde el primer arranque.
# Se aplica SIEMPRE (no requiere opcion). En la version Free instala ademas Chromium
# dentro del contenedor (se detecta por la opcion no_google_play en options=).
R="${TAPEOOS_ROOT:-/roota}"
OPTIONS="$1"
mkdir -p "$R/etc/chrome_dev.conf.d" "$R/usr/local/bin" "$R/usr/local/share/tapeos"

# 1) Habilitar Crostini (Terminal de Linux) por defecto
cat > "$R/etc/chrome_dev.conf.d/99-tapeos-crostini.conf" <<EOF
--enable-crostini
--enable-features=Crostini,CrostiniImeSupport,CrostiniGpuSupport
EOF

# 2) Script del contenedor: Flatpak + GNOME Software + Flathub (+ Chromium en Free)
cat > "$R/usr/local/share/tapeos/tapeos-software-center.sh" <<'EOF'
#!/bin/bash
# Se ejecuta DENTRO del contenedor Linux (penguin).
set -e
echo "[TapeOS] Instalando el Centro de software..."
if command -v sudo >/dev/null 2>&1; then S="sudo"; else S=""; fi
$S apt-get update -y >/dev/null 2>&1 || true
$S apt-get install -y flatpak gnome-software gnome-software-plugin-flatpak >/dev/null 2>&1 || true
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/tapeos-software-center.desktop <<DESK
[Desktop Entry]
Name=Centro de software TapeOS
Comment=Instala aplicaciones de Linux (Flatpak/Flathub)
Exec=gnome-software
Type=Application
Terminal=false
Categories=System;
DESK
if echo "$TAPEOOS_OPTIONS" | grep -q 'no_google_play'; then
    $S apt-get install -y chromium >/dev/null 2>&1 || true
    cat > ~/.local/share/applications/tapeos-chromium.desktop <<DESK
[Desktop Entry]
Name=Chromium (TapeOS)
Comment=Navegador libre de TapeOS
Exec=chromium
Type=Application
Terminal=false
Categories=Network;
DESK
fi
echo "[TapeOS] Centro de software instalado."
EOF
chmod +x "$R/usr/local/share/tapeos/tapeos-software-center.sh"

# 3) Wrapper del sistema: instala el centro dentro del contenedor via vsh
cat > "$R/usr/local/bin/tapeos-software-center" <<'EOF'
#!/bin/bash
echo "TapeOS: arrancando termina e instalando el Centro de software..."
vmc start termina 2>/dev/null || true
export TAPEOOS_OPTIONS="$(grep -o 'options=[^ ]*' /proc/cmdline | cut -d= -f2)"
cat /usr/local/share/tapeos/tapeos-software-center.sh | vsh --vm_name=termina --target_container=penguin -- bash -s
echo "Listo. Abre el lanzador y busca 'Centro de software TapeOS'."
EOF
chmod +x "$R/usr/local/bin/tapeos-software-center"

echo "tapeos: Crostini habilitado y Centro de software preparado" > /dev/kmsg
exit 0