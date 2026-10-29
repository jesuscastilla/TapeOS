# Contexto del Proyecto — TapeOS (`G:\TapeOS`)

> **Estado actual (29-10-2026).** Framework e instalador propios para llevar **ChromeOS** a PCs.
> Objetivo fundamental: permitir la
> instalación de **versiones modernas y actualizadas de ChromeOS** (v120–v149+) en **ordenadores antiguos con EFI**,
> complementado por una **suite de instalación interactiva nativa para Windows** que cubre el ciclo completo
> en 1 solo clic: Detección de hardware -> Consulta y descarga oficial desde Google CDN -> Parcheo retro -> Grabación directa en pendrive USB.
> Fuera de `G:\GITHUB`: proyecto independiente en `G:\TapeOS`.

---

## Glosario

| Término | Significado |
|---|---|
| **TapeOS** | Framework de arranque y suite de instalación para convertir PCs x86_64 en equipos ChromeOS con Play Store. |
| **DiploTech** | Marca personal de Jesús Castilla (desarrollo de software), autora del proyecto TapeOS. |
| **Chromium Dash API** | API oficial de Google (`chromiumdash.appspot.com`) empleada para consultar en tiempo real las últimas imágenes de recuperación estables. |
| **ROOTC** | Partición de 1 GB donde reside el kernel parcheado de TapeOS, el initramfs y los binarios de emulación (swtpm). |
| **swtpm** | Emulador de módulo TPM 2.0 en espacio de usuario que permite inicio de sesión seguro y cifrado en PCs que carecen de TPM físico. |
| **ia32 / UEFI 32-bit** | Firmware UEFI de 32 bits en procesadores de 64 bits (típico en convertibles y netbooks Intel Atom Bay Trail / Cherry Trail). |
| **Freon / minigbm** | Subsistema gráfico y gestor de buffers de pantalla de ChromeOS nativo (sin servidor X11 ni Wayland externo). |
| **ARC++ vs ARCVM** | Android Container (`ARC++`, más ligero para hardware retro) vs Android Virtual Machine (`ARCVM`, para hardware moderno). |
| **no_google_apps** | Opción de framework de TapeOS (formato `options=`) que elimina la sección ARC del config unibuild: ChromeOS sin Play Store ni contenedor Android (modo ligero). |

---

## Decisiones de Diseño y Arquitectura

1. **Pipeline de Instalación Automatizado para Windows (`installer/windows/`)**:
   - Elimina al 100% la fricción de instalar WSL2, paquetes Debian (`pv`, `cgpt`) y comandos bash manuales.
   - **Módulos desacoplados en PowerShell**:
     - `HardwareDetector.psm1`: Identifica CPU, GPU, modo de arranque EFI y estado de BitLocker.
     - `RecoveryDownloader.psm1`: Consulta la API de Google Chromium Dash y descarga directamente el archivo `.bin.zip` más reciente con barra de progreso.
     - `ImagePatcher.psm1`: Descomprime la imagen y aplica el esquema de cargadores TapeOS (`grub.cfg`, `bootx64.efi`, `bootia32.efi`), compatibilidad Freon/Mesa y ganchos de `swtpm`.
     - `UsbFlasher.psm1`: Graba de forma nativa sector a sector en pendrives USB físicos mediante Win32 FileStream, con protección contra escritura en discos de sistema o de arranque internos.
     - `BootManager.psm1` / `DiskManager.psm1`: Generación de configuraciones de arranque GRUB (USB/instalador) y utilidades de descompresión y detección de USB.

2. **Estrategia para Ejecutar ChromeOS Actualizado en Equipos EFI Antiguos**:
   - **TPM 2.0 por Software**: Modern ChromeOS exige TPM 2.0 para el login. TapeOS arranca `swtpm` en el initramfs antes de que `cryptohomed` comience, permitiendo vincular cuentas Google y cifrar perfiles en ordenadores de cualquier época.
   - **Adaptación Gráfica (Freon / Mesa)**: Inyección de variables (`INTEL_DEBUG=noccs`, driver `crocus` y desactivación de Vulkan) para evitar la pantalla negra clásica en GPUs Intel HD 2000 a 4400.
   - **Bootloader Mixto (Dual EFI)**: Incluye `bootx64.efi` para sistemas estándar y `bootia32.efi` para dispositivos con UEFI de 32 bits (Intel Atom Z3735F, Z8350).
   - **Control de Memoria**: Ajuste de `zram` al 150% de la capacidad de RAM para garantizar estabilidad en equipos con 2 GB o 4 GB.

3. **Estructura del Repositorio y Entorno**:
   - Fuentes upstream descargadas en `upstream_sources/` e ignoradas en `.gitignore` para no contaminar el árbol de Git oficial.
   - Configuración lista para desarrollo en VS Code (`.vscode/settings.json`, `.vscode/tasks.json`).
   - Plantillas de incidencias y workflows de CI/CD en `.github/`.

---

## Estructura de Directorios

```text
TapeOS/
├── .github/                 # Workflows de CI/CD (GitHub Actions) y plantillas
├── .vscode/                 # Tareas automatizadas para IDE (VS Code)
├── installer/
│   └── windows/             # Suite de instalación nativa de Windows (GUI + CLI)
│       ├── Run-Installer.cmd
│       ├── TapeOS-Installer.ps1
│       ├── TapeOS-CLI.ps1
│       └── modules/
│           ├── HardwareDetector.psm1
│           ├── RecoveryDownloader.psm1
│           ├── ImagePatcher.psm1
│           ├── UsbFlasher.psm1
│           ├── RecoveryCatalog.psm1
│           ├── DiskManager.psm1
│           └── BootManager.psm1
├── core/
│   ├── scripts/             # Scripts centrales (tapeos-install.sh, tapeos-setup)
│   ├── patches/             # Parches para GPU antigua, Wi-Fi, audio ALSA UCM
│   └── initramfs/           # Inicializador de arranque y swtpm
├── tools/
│   └── fetch_recovery.py    # Cliente CLI en Python para consulta de imágenes oficiales
├── docs/
│   ├── WINDOWS_INSTALL_GUIDE.md
│   ├── LEGACY_HARDWARE_MATRIX.md
│   ├── PATCHING_MODERN_CROS_FOR_LEGACY_EFI.md
│   └── ARCHITECTURE.md
├── upstream_sources/         # Referencia upstream descargada para consulta técnica (ignorada)
├── CHANGELOG.md
├── CONTEXT.md
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

---

## Historial de Actualizaciones

## [28-10-2026] — Creación inicial del repositorio TapeOS y suite Windows interactiva

- **Tipo:** Arquitectura | Vista | API | Dependencia
- **Cambio:** Creación oficial de TapeOS, framework propio de arranque para ChromeOS en PCs. Se implementó la suite completa de instalación en Windows (`installer/windows/`), con detección de hardware, consulta de la API Chromium Dash de Google para recoveries actualizados, motor de descarga con barra de progreso, parcheo retro (Legacy EFI, `swtpm`, GPUs Intel/AMD clásicas) y flasher directo a USB.
- **Impacto:** Proyecto nuevo e independiente en `G:\TapeOS`, sin dependencias obligatorias de WSL2 para el usuario final de Windows.

## [29-10-2026] — Publicación en GitHub y cambio de licencia a GPLv3

- **Tipo:** Configuración
- **Cambio:** Repositorio publicado en `https://github.com/jesuscastilla/TapeOS` (público, remoto `origin`). Licencia cambiada de Apache 2.0 a **GPLv3** (`LICENSE` con texto íntegro). Badge de issues corregido; workflow de release sin glob `dist/*.tar.gz`; `TapeOS.code-workspace` añadido a Git.
- **Impacto:** CI de GitHub Actions operativo sobre `main`; los ficheros de `upstream_sources/` siguen ignorados y no se publican.

## [29-10-2026] — Opción de instalación con o sin Google Apps (Play Store)

- **Tipo:** Vista | Arquitectura
- **Cambio:** El instalador Windows (GUI y CLI) permite elegir instalar ChromeOS **con Google Apps** (Play Store + Android) o **sin ellas** (modo ligero). Nueva opción de framework `no_google_apps` en `options=` del kernel y nuevo parche `core/patches/40-no_google_apps.sh` que elimina la sección ARC del config unibuild (JSON o configfs.img).
- **Impacto:** `ImagePatcher.psm1`, `BootManager.psm1`, `TapeOS-Installer.ps1`, `TapeOS-CLI.ps1`, `docs/WINDOWS_INSTALL_GUIDE.md`, `README.md`.

## [29-10-2026] — Ejecutable Windows autocontenido (EXE)

- **Tipo:** Vista | Configuración
- **Cambio:** Nueva build `tools/build-exe.ps1` que empaqueta la GUI y los 7 módulos en un único `TapeOS-Installer-<version>.exe` con ps2exe (+icono `tools/assets/tapeos.ico`). El workflow de release construye el EXE en `windows-latest` y lo adjunta a cada release.
- **Impacto:** Los usuarios finales ya no dependen de asociaciones de archivos ni de PowerShell; cada release incluye EXE + ZIP.

## [29-10-2026] — Firma digital del EXE y modo "solo crear .img"

- **Tipo:** Configuración | Vista
- **Cambio:** Herramientas `tools/sign-exe.ps1` (firma Authenticode con timestamp) y `tools/new-signing-cert.ps1` (certificado propio); CI firma el EXE si hay secretos de firma; releases incluyen `tapeos-signing.cer`. Nueva opción de destino en GUI y CLI: crear solo el archivo `.img` sin grabar en pendrive (`TapeOS-<board>-M<milestone>-googleapps|lite.img` + `grub.cfg`).
- **Impacto:** `TapeOS-Installer.ps1`, `TapeOS-CLI.ps1`, workflow de release, docs.

## [29-10-2026] — Detección ampliada de hardware (WiFi/Bluetooth/audio/táctil)

- **Tipo:** Arquitectura | Vista
- **Cambio:** `HardwareDetector.psm1` detecta WiFi (VID→opción de framework de TapeOS: `iwlwifi_backport`, `broadcom_wl`, `brcmfmac`, `rtl*`), Bluetooth (`rtbth`), audio (`essx8336`, `legacy_audio_ucm`), táctil (`ipts/ithc/goodix`), dGPU (`dgpu`) y MacBook (`macbook_trackpad`). Las opciones fluyen a `options=` del kernel vía `-AdditionalFrameworkOptions`/`-FrameworkOptions` y quedan en `tapeos_patches.json`. Nuevo `core/patches/50-hardware_patches.sh` (force-load de módulos vía `modules-load.d`).
- **Impacto:** `HardwareDetector.psm1`, `ImagePatcher.psm1`, `BootManager.psm1`, GUI, CLI, `core/patches/`.

## [29-10-2026] — Rebranding: identidad DiploTech, sin referencias a terceros

- **Tipo:** Vista
- **Cambio:** Eliminadas todas las referencias a proyectos de terceros de README, CONTEXT, CHANGELOG, docs y comentarios de código. Logo de **DiploTech** en la cabecera de la GUI y en el README; nuevo icono del EXE multi-tamaño generado desde el logo (`tools/make-icon.ps1`); carpeta local de referencia ignorada con patrón genérico.
- **Impacto:** `TapeOS-Installer.ps1`, `tools/build-exe.ps1`, `tools/make-icon.ps1`, `tools/assets/`, `release.yml`, documentación.

## [29-10-2026] — Compatibilidad con GPUs dedicadas (dGPU)

- **Tipo:** Arquitectura
- **Cambio:** `HardwareDetector.psm1` añade `VendorId` a cada GPU y detecta dGPU (NVIDIA `10DE` siempre; AMD `1002` en equipos Intel+AMD o multi-GPU) inyectando la opción `dgpu`. Nuevo parche `core/patches/45-dgpu.sh`: NVIDIA suspendida vía udev + blacklist `nouveau`; AMD con `amdgpu` forzado + blacklist `radeon`. GUI y CLI muestran el fabricante de cada GPU.
- **Impacto:** `HardwareDetector.psm1`, `TapeOS-Installer.ps1`, `TapeOS-CLI.ps1`, `core/patches/`, README, guía de instalación.

## [29-10-2026] — Solo modos Live-USB e Instalador (sin dual-boot)

- **Tipo:** Arquitectura | Vista
- **Cambio:** La aplicación ofrece únicamente dos modos: **Live-USB** (grabar en pendrive) e **Instalador** (crear el medio `.img` sin grabar). Eliminados `Register-TapeOSInWindowsBCD`, la entrada "Windows Boot Manager" y el arranque loopback de `New-TapeOSGrubConfig`, y `New-TapeOSDiskImage` de `DiskManager.psm1`. GUI y CLI renombradas en consecuencia.
- **Impacto:** `BootManager.psm1`, `DiskManager.psm1`, `TapeOS-Installer.ps1`, `TapeOS-CLI.ps1`, README, guía de instalación.
