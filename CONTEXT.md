# Kontexto der Proyêtto — TapeOS (`G:\TapeOS`)

> **Êttao âttuâh (29-10-2026).** Framework e îttaladôh propiô pa yebâh **ChromeOS** a PC.
> Ôhhetibo fundamentâh: permettîh la
> îttalaçiôn de **berçionêh modernâ y âttualiçâh de ChromeOS** (v120–v149+) en **ordenadorêh antiguô kon EFI**,
> komplementao po una **çûite de îttalaçiôn întêratiba natiba pa Windows** ke kûbre er çîklo kompleto
> en 1 çolo klik: Detêççiôn de hardware -> Konhûtta y dehkarga ofiçiâh dêhde Google CDN -> Parcheo retro -> Grabaçiôn dirêtta en pendraîh USB.
> Fûera de `G:\GITHUB`: proyêtto independiente en `G:\TapeOS`.

## [29-10-2026] — Andamiahe der framework de arrankê

- **Tipo:** Arkîtêttûra
- **Kambio:** `core/build/build-framework.sh` (konttruye kernêh, initramfs, ROOTC y yabê vboot; empaketa tar.gz), `core/initramfs/init` (swtpm + montahe de ROOT-A + parcheh) y `core/build/README.md` en EPA. Lîtta pa kompilâh.
- **Impâtto:** `core/build/`, `core/initramfs/`, `.gitignore`.

## [29-10-2026] — Preçentaçiôn de GitHub: identidá, kréditô y çelettôh de idioma

- **Tipo:** Bîtta
- **Kambio:** README kon çelettôh **EPA/Êppanyôh** (`README.md` / `README.es.md`), çeççiôn de identidá (çîttema operatibo propio andalûh, çoftware libre, Googlêh Play ôççionalêh, baçao en ChromeOS/ChromiumOS) y çeççiôn de kréditô a Brunch (Sebanc) kon lâ diferençiâ. Dêkripçiôn y topî der repo âttualiáô (software-libre, andalucia, chromiumos, e-waste).
- **Impâtto:** `README.md`, `README.es.md`, `release.yml`, dêkripçiôn/topî de GitHub.

## [29-10-2026] — Wîçâh po paçô kon ETA y lîtta TODO

- **Tipo:** Bîtta
- **Kambio:** `TapeOS-Installer.ps1` reêkkrito komo açîtente de 5 paçô (detêççiôn, rekûperaçiôn, konfiguraçiôn, reçûmen, ehekuçiôn) kon barra de progreço y ETA po etapa y çelettôh EPA/Êppanyôh. Lîtta TODO en README.md y README.es.md (identidá andalûça, dok de âttualiçaçionêh, eliminâh referençiâ a Google).
- **Impâtto:** `TapeOS-Installer.ps1`, `README.md`, `README.es.md`.

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
| **no_google_play** | Opción de framework de TapeOS (formato `options=`) que desactiva la Play Store pero conserva Android (ARC) para apps APK, con Aurora Store como tienda alternativa. |

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
 .github/                 # Workflows de CI/CD (GitHub Actions) y plantillas
 .vscode/                 # Tareas automatizadas para IDE (VS Code)
 installer/
 windows/             # Suite de instalación nativa de Windows (GUI + CLI)
 Run-Installer.cmd
 TapeOS-Installer.ps1
 TapeOS-CLI.ps1
 modules/
 HardwareDetector.psm1
 RecoveryDownloader.psm1
 ImagePatcher.psm1
 UsbFlasher.psm1
 RecoveryCatalog.psm1
 DiskManager.psm1
 BootManager.psm1
 core/
 scripts/             # Scripts centrales (tapeos-install.sh, tapeos-setup)
 patches/             # Parches para GPU antigua, Wi-Fi, audio ALSA UCM
 initramfs/           # Inicializador de arranque y swtpm
 tools/
 fetch_recovery.py    # Cliente CLI en Python para consulta de imágenes oficiales
 docs/
 WINDOWS_INSTALL_GUIDE.md
 LEGACY_HARDWARE_MATRIX.md
 PATCHING_MODERN_CROS_FOR_LEGACY_EFI.md
 ARCHITECTURE.md
 upstream_sources/         # Referencia upstream descargada para consulta técnica (ignorada)
 CHANGELOG.md
 CONTEXT.md
 CONTRIBUTING.md
 LICENSE
 README.md
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

## [29-10-2026] — Instalador como modo predeterminado (sin pendrive)

- **Tipo:** Vista
- **Cambio:** El modo **Instalador** pasa a ser el predeterminado en la GUI (controles de USB deshabilitados al inicio). Si se elige Live-USB sin pendrive, la app ofrece cambiar a Instalador con un diálogo Sí/No.
- **Impacto:** `TapeOS-Installer.ps1`.

## [29-10-2026] — Cierre silencioso corregido: log global y descarga síncrona

- **Tipo:** Configuración
- **Cambio:** Captura global de excepciones con log (`%ProgramData%\TapeOS\tapeos-installer.log`) y diálogo visible en la GUI; el botón "Crear" queda envuelto en try/catch con logging por pasos. `RecoveryDownloader` pasa a `DownloadFile` síncrono (+TLS 1.2), eliminando el patrón TPL async que puede matar el host PS 5.1 sin consola.
- **Impacto:** `TapeOS-Installer.ps1`, `RecoveryDownloader.psm1`.

## [29-10-2026] — Identidad andaluza, idioma andaluz y modo Aurora (APK)

- **Tipo:** Vista | Arquitectura
- **Cambio:** Fondo de la GUI con la bandera de Andalucía (verde #00843D / blanco), esquema verde/blanco y selector de idioma **Español/Andaluz** (andalûh). El modo "Sin Google Play" conserva Android para APK con Aurora Store: opción `no_google_play` + parche `core/patches/40-no_google_play.sh` (deshabilita vending, prepara APK) + metadatos `AppStore`/`ApkSideload`. Detección USB con fuentes independientes y logging granular del botón "Crear".
- **Impacto:** `TapeOS-Installer.ps1`, `TapeOS-CLI.ps1`, `ImagePatcher.psm1`, `BootManager.psm1`, `UsbFlasher.psm1`, `core/patches/40-no_google_play.sh`.

## [29-10-2026] — Wîçâh kompakto 900x660 y balidáçiôn de dîppóçiçiôn

- **Tipo:** Bîtta
- **Kambio:** La GUI pâhha a `ClientSize` 900x660 (en lûgâh de `Size` 900x700): lîtta de lôh y botonêh de nabegaçiôn dentro der área de kliênte, bandera dibuhá ar tamaño êhâtto y çin `AutoScroll`/`Stretch`. Er arnêh `tools/wizard-smoke-test.ps1` komprueba lô lîmitê de tô lô kontrolê (`wizard-layout-check.log`) y guarda una kaptûra (`dist/gui-snapshot.png`).
- **Impâtto:** `installer/windows/TapeOS-Installer.ps1`, `tools/wizard-smoke-test.ps1`, `CHANGELOG.md`.

## [29-10-2026] — Intêrfâh renobá y arrankê çîn êpperâ

- **Tipo:** Bîtta
- **Kambio:** `EnableVisualStyles` + paleta unifiká + bâttonêh/chips redondeáô + doble buffering en la GUI. La detêççiôn de hardware/katálogo/USB paça al ebento `Shown` kon timer de repôtto (`Initialize-TapeOSDetection`, idempotente) pa ke la bentana apareçca al îttante. Er arnêh de pruebâ rekorta er área de kliênte en la kaptûra y añade diânnôttiko de iniçialiçaçiôn.
- **Impâtto:** `installer/windows/TapeOS-Installer.ps1`, `tools/wizard-smoke-test.ps1`, `CHANGELOG.md`.

## [29-10-2026] — Bentana 1000x730 y kabêçera korrehíâ

- **Tipo:** Bîtta
- **Kambio:** La GUI pâhha a `ClientSize` 1000x730 kon layout rekalkulao (kabêçera 86 px, chip 150x36, tarheta 952x384, lîtta 952x92, nabegaçiôn 160x46). Çûttitulo korto, franha tricolôh dêntro de la kabêçera, çelettôh de idioma çîn foko iniçiâh y tipografía mâh grande (títulô 15pt, kuerpô 10pt).
- **Impâtto:** `installer/windows/TapeOS-Installer.ps1`, `tools/wizard-smoke-test.ps1`, `CHANGELOG.md`.

## [29-10-2026] — Bentana redimençionable, kabêçera anti-çolapamiento y layout repponçibo

- **Tipo:** Bîtta
- **Kambio:** La GUI pâhha a çêh redimençionable (`FormBorderStyle = Sizable`, `MaximizeBox = $true`, `MinimumSize = 920x600`). Se implementa `FlowLayoutPanel` bertikâh pa títulô y çûttitulo ebitando kuarkêh çolapamiento horiçontâh po eçkaláo DPI (125%-150%), anclahe dinámiko (`Anchor`, `Dock`) en tô lô panelêh, chip de paçô repponçibô (`Update-TapeOSStepChips`), franha tricolôh ahattá ar fondo de la kabêçera y botón «Crear» çentrao automátiko.
- **Impâtto:** `installer/windows/TapeOS-Installer.ps1`, `dist/TapeOS-Installer-1.0.0-alpha.34.exe`, `tools/wizard-smoke-test.ps1`, `CHANGELOG.md`.
## [29-10-2026] — Framework de arranque real: initramfs, GRUB legible e instalador a disco

- **Tipo:** Arkîtêttûra
- **Kambio:** Nuevo `core/build/build-initramfs.sh` (busybox estático + cgpt/sgdisk/resize2fs + swtpm + parches), `core/initramfs/init` con modos normal/verbose/install, `core/scripts/tapeos-install.sh` (vuelca el USB, arregla la GPT y expande ROOT-A al tamaño del disco). `BootManager.psm1` genera el menú GRUB de 7 entradas e inyecta menú + initramfs en la ESP del pendrive; el EXE empaqueta el initramfs y el CI lo construye en cada release.
- **Impâtto:** `core/`, `installer/windows/modules/BootManager.psm1`, `ImagePatcher.psm1`, `TapeOS-Installer.ps1`, `tools/build-exe.ps1`, `.github/workflows/release.yml`.
## [29-10-2026] — Kernel Linux de PC para el arranque de TapeOS

- **Tipo:** Arkîtêttûra | Configuración
- **Kambio:** El kernel del recovery de ChromeOS no arranca en PCs (vboot/`cros_efi`): pantalla negra o reinicio. Se inyecta un kernel Linux de PC (`dist/tapeos-vmlinuz`, Ubuntu 6.8) en `\tapeos\vmlinuz` de la ESP y el menú GRUB pasa a 8 entradas (4 con kernel de PC, 2 con el del recovery, consola y apagar). El EXE empaqueta kernel + initramfs; el pipeline los inyecta automáticamente al grabar.
- **Impâtto:** `installer/windows/modules/BootManager.psm1`, `TapeOS-Installer.ps1`, `tools/build-exe.ps1`, `dist/tapeos-vmlinuz`.
## [30-10-2026] — TapeOS sobre Brunch r154 (base + capa propia)

- **Tipo:** Arkîtêttûra
- **Kambio:** El framework pasa a basarse en Brunch r154 (ChromeOS r154, kernels r156): el asistente instala Brunch + capa TapeOS vía WSL (`install-brunch-usb.sh`: particionado, copia por offsets y `apply-tapeos.sh` con parches 90-96, Aurora Store y GRUB de 6 entradas sin menú de configuración). Parches automáticos según el hardware detectado (dGPU, legacy, WiFi, audio/táctil, zram, no_google_play).
- **Impâtto:** `core/brunch/`, `installer/windows/modules/BrunchInstaller.psm1`, `TapeOS-Installer.ps1`, `tools/build-exe.ps1`.
## [30-10-2026] — Imâhen Free kompleta y label de façe çîn rekortêh

- **Tipo:** Arkîtêttûra | Bîtta
- **Kambio:** `apply-free.sh` rekreaba ROOT-A kon el 5% de reçerba y kopiaba kon `tar` çîn `--sparse`: er rootfs (2605 MB) no kabía (faltaban ~6 MB) y la imâhen arrankaba pero çe kolgaba en er logo. Ahora rekreaba kon `-m 0` y çîn jûnnâh, kopia kon `--sparse`, aplika lô parxêh en kaliente y berifika er reçûttao. La etiketa de façe pâhha de 28 a 38 px (têttô en negrita rekortao). Er grub.cfg de Free pîerde `noinitrd` y uça `console=tty0`.
- **Impâtto:** `core/free/apply-free.sh`, `core/free/grub/grub.cfg`, `installer/windows/TapeOS-Installer.ps1`, `tools/wizard-smoke-test.ps1`, imâhen `TapeOS-Free-Iris-v23.1.img`.