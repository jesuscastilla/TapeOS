# TapeOS sobre Brunch

TapeOS usa el framework Brunch (r154, ChromeOS r154, kernels r156) como base y anade su propia capa:

## Flujo de instalacion (Live-USB)

1. Grabar/instalar Brunch sobre el recovery de ChromeOS:
   `echo yes | bash chromeos-install.sh -l -src recovery.bin -dst /dev/sdX`
2. Aplicar la capa TapeOS:
   `bash core/brunch/apply-tapeos.sh /dev/sdX`
   - Copia los parches `patches/9*.sh` a ROOT-C (`/patches`).
   - Copia el instalador a disco (`tapeos-install.sh` + resize2fs/e2fsck) a ROOT-C (`/tapeos`).
   - Copia AuroraStore.apk a ROOT-C (`/tapeos/apps`).
   - Sustituye el grub.cfg de Brunch por el de TapeOS (sin menu de configuracion).

## Parches de TapeOS (se ejecutan en el primer arranque, segun options=)

- `90-tapeos-dgpu-amd.sh`  -> `dgpu` (RX 5700 XT / dGPU AMD: amdgpu forzado, firmware, flags Chrome)
- `91-tapeos-no-google-play.sh` -> `no_google_play` (sin Play Store + Aurora Store)
- `92-tapeos-legacy-gpu.sh` -> `legacy_gpu` (Intel Gen 2-9: crocus/noccs)
- `93-tapeos-branding.sh`  -> siempre (identidad TapeOS)
- `94-tapeos-hardware.sh`  -> `iwlwifi_backport`, `essx8336`, `legacy_audio_ucm`, touch, MacBook
- `95-tapeos-zram.sh`      -> siempre (zram 150%)
- `96-tapeos-install.sh`   -> `install_tapeos` (instalador a disco duro)

## Menu GRUB (sin configuracion de Brunch)

1. TapeOS - modo normal
2. TapeOS - Diagnostico verbose
3. TapeOS - Modo seguro (sin graficos)
4. Instalar TapeOS en un disco duro
5. Consola de comandos GRUB
6. Apagar el equipo

Las opciones van fijas en cada entrada (`options=...`); el instalador Windows las
calcula segun el hardware detectado.