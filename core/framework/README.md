# TapeOS - Framework de compatibilidad (core/framework)

Motor de compatibilidad de TapeOS: lleva el sistema base (ChromeOS para TapeOS;
openFyde/FydeOS para TapeOS Free) a PCs x86_64 con sus parches propios.

## Flujo de construccion de imagenes (solo en maquina con Linux/WSL)

1. Participar y copiar: `framework-partition.sh` + `write-framework-fast.sh`.
2. Aplicar la capa TapeOS: `apply-tapeos.sh <disco>`
   - Parches `patches/9*.sh` a ROOT-C, instalador a disco + herramientas,
     AuroraStore.apk, GRUB propio (sin menus de configuracion) e identidad
     TapeOS en el initramfs.
3. O generar la imagen completa: `build-tapeos-img.sh <recovery.bin> <salida.img> [GB] [opciones]`.

## Parches de TapeOS (se ejecutan en el primer arranque segun options=)

- `90-tapeos-dgpu-amd.sh`     -> `dgpu` (dGPU AMD: amdgpu forzado + flags)
- `91-tapeos-no-google-play.sh` -> `no_google_play` (sin Play + Aurora Store)
- `92-tapeos-legacy-gpu.sh`   -> `legacy_gpu` (Intel Gen 2-9: crocus/noccs)
- `93-tapeos-branding.sh`     -> siempre (identidad TapeOS)
- `94-tapeos-hardware.sh`     -> WiFi/audio/tactil por opciones detectadas
- `95-tapeos-zram.sh`         -> siempre (zram 150 %)
- `96-tapeos-install.sh`      -> `install_tapeos` (instalador a disco duro)
- `97-tapeos-crostini.sh`     -> siempre (terminal Linux/Crostini + Centro de software Flatpak/GNOME Software; Chromium en Free)

## Menu GRUB (sin menus de configuracion del framework base)

1. TapeOS - modo normal
2. TapeOS - Diagnostico verbose
3. TapeOS - Modo seguro (sin graficos)
4. Instalar TapeOS en un disco duro
5. Consola de comandos GRUB
6. Apagar el equipo