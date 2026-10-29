# Historial de Cambios (Changelog) — TapeOS

Todas las modificaciones notables de este proyecto se documentarán en este archivo.

## [v1.0.0-alpha.17] — 29-10-2026

### Correcciones
- **Grabación en disco físico corregida**: la apertura de `\\.\PhysicalDriveN` ahora usa la API nativa **CreateFile** (kernel32) y envuelve el handle en un `FileStream`, evitando la restricción que impide abrir dispositivos Win32 con rutas `\\.\` en ciertos runtimes.
- **Reutilización de descargas**: si ya existe el ZIP oficial completo de una ejecución anterior, no se vuelve a descargar.

## [v1.0.0-alpha.16] — 29-10-2026

### Correcciones
- **Error "No se encuentra el tipo [System.IO.Compression.ZipFile]" corregido**: los módulos `ImagePatcher` y `DiskManager` cargan ahora la librería de compresión (`System.IO.Compression` + `.FileSystem`) al importarse, de modo que el runspace dedicado del pipeline tiene el tipo disponible.

## [v1.0.0-alpha.15] — 29-10-2026

### Correcciones críticas
- **Cierre al pulsar "Crear" definitivamente corregido**: el pipeline ya no se ejecuta en un hilo del `ThreadPool` (que en hosts STA de PowerShell 5.1 muere con "no runspace available" y cierra el proceso en silencio). Ahora se ejecuta en un **runspace dedicado (STA)** lanzado con `BeginInvoke` y vigilado desde la UI con un `Timer` de WinForms, con errores capturados en `EndInvoke`.

## [v1.0.0-alpha.14] — 29-10-2026

### Novedades
- **Identidad andaluza**: fondo de la GUI con la **bandera de Andalucía** (verde-blanco-verde), esquema de colores verde (#00843D)/blanco en cabecera y botones, y selector de idioma **Español / Andaluz** (andalûh). El icono del EXE sigue siendo el logo de DiploTech.
- **Modo "Sin Google Play" con APK y Aurora Store**: al elegirlo se conserva Android (ARC) para instalar aplicaciones APK y se prepara la tienda alternativa **Aurora Store**. La opción de framework pasa a `no_google_play` y el nuevo parche `core/patches/40-no_google_play.sh` deshabilita la Play Store y prepara las APK de la tienda alternativa (metadatos `AppStore=aurora`, `ApkSideload=enabled`).

### Correcciones
- **Detección USB robusta**: cada fuente de detección (BusType USB, MediaType External, árbol PnP) falla de forma independiente sin anular las demás.
- **Aviso de pendrive claro**: eliminado el auto-cambio de modo; ahora informa y ofrece **reintentar la detección**.
- **Logging granular** en todo el flujo del botón "Crear" (click, confirmación, worker y pasos) para localizar cualquier cierre inesperado.

## [v1.0.0-alpha.13] — 29-10-2026

### Correcciones
- **Selección de modo corregida**: la inicialización dejaba marcados a la vez los dos radios (Live-USB e Instalador), por lo que la app siempre caía en el modo Instalador. Ahora solo uno queda marcado y al elegir **Live-USB la lista de pendrives se refresca automáticamente**.

## [v1.0.0-alpha.12] — 29-10-2026

### Correcciones
- **Soporte de adaptadores SSD/HDD-USB (UASP)**: la detección de dispositivos USB combina ahora `BusType USB`, `MediaType External` y el recorrido del árbol PnP hasta la raíz USB (los puentes USB-SATA/NVMe se reportan como SCSI y antes no se detectaban).
- **Seguridad reforzada**: el flasher verifica que el destino esté en la lista de dispositivos USB detectados antes de escribir.

## [v1.0.0-alpha.11] — 29-10-2026

### Correcciones
- **Evitado el cierre silencioso de la app**: captura global de excepciones (ThreadException + try/catch en el flujo del botón "Crear") con diálogo de error visible y **archivo de log** en `%ProgramData%\TapeOS\tapeos-installer.log`.
- **Descargador endurecido**: sustituida la descarga TPL async (`DownloadFileTaskAsync`, fuente de fallos en hosts PS 5.1 sin consola) por `DownloadFile` síncrono en el hilo de trabajo (la barra de progreso sigue funcionando vía eventos). Añadido forzado de TLS 1.2.

## [v1.0.0-alpha.10] — 29-10-2026

### Correcciones y Mejoras de UX
- El modo **Instalador** es ahora el predeterminado: al abrir la app no se pide ningún pendrive.
- Si se elige **Live-USB** sin pendrive conectado, la app ofrece automáticamente cambiar al modo Instalador (en lugar de bloquearse con un aviso).
- El log inicial explica ambos modos y los controles se habilitan/deshabilitan según el modo activo.

## [v1.0.0-alpha.9] — 29-10-2026

### Novedades
- **Solo dos modos, sin dual-boot**: la aplicación ofrece únicamente **Live-USB** (grabar en pendrive) e **Instalador** (crear el medio de instalación `.img` sin grabar). Eliminada toda la funcionalidad dual-boot: `Register-TapeOSInWindowsBCD`, la entrada "Windows Boot Manager" y el arranque loopback `chromeos.img` de GRUB, y `New-TapeOSDiskImage` (discos sparse).
- `New-TapeOSGrubConfig` genera ahora configuraciones estilo USB/instalador (búsqueda por etiqueta `ROOT-A`), coherentes con el `grub.cfg` que genera el patcher.

## [v1.0.0-alpha.8] — 29-10-2026

### Novedades
- **Compatibilidad con GPUs dedicadas (dGPU)**: detección por vendor ID (NVIDIA `10DE`, AMD `1002`) con reglas heurísticas (NVIDIA siempre; AMD en equipos Intel+AMD o multi-GPU). La opción `dgpu` se inyecta automáticamente en `options=`.
- Nuevo parche del framework **`core/patches/45-dgpu.sh`**: en NVIDIA suspende la dGPU vía udev (renderiza la iGPU) y desactiva `nouveau`; en AMD fuerza `amdgpu` con modeset y desactiva `radeon`.
- La GUI y la CLI muestran ahora el fabricante de cada GPU detectada (NVIDIA/AMD/Intel).

## [v1.0.0-alpha.7] — 29-10-2026

### Novedades
- **Rebranding completo**: eliminadas todas las referencias a proyectos de terceros de la documentación, código y comentarios. Identidad propia con el **logo de DiploTech** en la GUI, el icono del EXE y el README.
- Nuevo icono multi-tamaño generado desde el logo (`tools/make-icon.ps1`) y logo blanco en la cabecera de la interfaz gráfica.

## [v1.0.0-alpha.6] — 29-10-2026

### Novedades
- **Detección ampliada de hardware**: el instalador ahora detecta **WiFi** (con vendor ID y mapeo a parche: `iwlwifi_backport`, `broadcom_wl`, `brcmfmac`, `rtl*`...), **Bluetooth** (`rtbth` para RT3290), **códecs de audio** (`essx8336`, `legacy_audio_ucm`), **pantallas táctiles** (`ipts_touchscreen`, `ithc_touchscreen`, `goodix`), **GPU dedicada** (`dgpu`) y **MacBook** (`macbook_trackpad`).
- Las opciones detectadas se inyectan automáticamente en la línea del kernel (`options=...`) vía `Invoke-TapeOSImagePatch -AdditionalFrameworkOptions` y `New-TapeOSGrubConfig -FrameworkOptions`, y quedan registradas en `tapeos_patches.json` (`HardwarePatches`).
- Nuevo parche del framework `core/patches/50-hardware_patches.sh`: fuerza la carga de los módulos kernel correspondientes (`modules-load.d`) en el arranque de ChromeOS.
- La GUI muestra WiFi/Bluetooth/audio/táctil y los parches detectados en el panel de diagnóstico; la CLI los lista en el paso 1.

## [v1.0.0-alpha.5] — 29-10-2026

### Novedades
- **Firma digital del EXE**: nueva tool `tools/sign-exe.ps1` (signtool de Windows SDK o `Set-AuthenticodeSignature`, con timestamp RFC 3161) y `tools/new-signing-cert.ps1` para crear el certificado propio. El CI firma el EXE automáticamente si los secretos `SIGNING_PFX_BASE64` / `SIGNING_PFX_PASSWORD` están configurados, y cada release incluye `tapeos-signing.cer` (clave pública) para instalar como Editor de Confianza.
- **Modo "solo crear archivo .img" (sin grabar)**: la GUI y la CLI permiten elegir como destino un archivo de imagen (`TapeOS-<board>-M<milestone>-googleapps|lite.img`) en lugar de un pendrive USB. El proceso descarga y parchea la imagen y la guarda en la carpeta elegida (con su `grub.cfg`), lista para grabar más tarde con Rufus/Win32DiskImager o con TapeOS.

## [v1.0.0-alpha.4] — 29-10-2026

### Novedades
- **Ejecutable autocontenido para Windows** (`TapeOS-Installer-<versión>.exe`): empaqueta la GUI y los 7 módulos en un único EXE generado con ps2exe. No requiere PowerShell configurado ni asociaciones de archivos, y eleva UAC automáticamente.
- Nueva herramienta de build **`tools/build-exe.ps1`** e icono propio en `tools/assets/tapeos.ico`.
- **Workflow de release ampliado**: el EXE se construye en `windows-latest` y se adjunta a cada release junto al ZIP.

## [v1.0.0-alpha.3] — 29-10-2026

### Correcciones
- **Codificación UTF-8 con BOM + CRLF** en todos los scripts PowerShell del instalador: Windows PowerShell 5.1 muestra ahora correctamente los acentos y emojis de la interfaz (antes podían verse caracteres extraños).
- **Nota de soporte**: si al hacer doble clic en `Run-Installer.cmd` aparece el error `0x800700C1` ("%1 no es una aplicación Win32 válida"), es una asociación de archivos `.cmd` rota en Windows. Repárala con `cmd /c assoc .cmd=cmdfile` y `cmd /c ftype cmdfile="%1" %*`, o ejecuta el instalador directamente: `powershell -NoProfile -ExecutionPolicy Bypass -File .\TapeOS-Installer.ps1`.

## [v1.0.0-alpha.2] — 29-10-2026

### Novedades
- **Opción de Google Apps en el instalador**: elección entre instalar ChromeOS **con Google Apps (Play Store + Android)** o **sin ellas (modo ligero)**:
  - Selector en la GUI (radio buttons) y pregunta en el CLI.
  - Nueva opción de framework `no_google_apps` en la línea del kernel (`options=`).
  - Nuevo parche `core/patches/40-no_google_apps.sh` que elimina la sección ARC del config unibuild (JSON o configfs.img) para que ChromeOS no arranque el contenedor Android.
  - El modo elegido queda registrado en `tapeos_patches.json` y reflejado en el menú de GRUB generado.

## [v1.0.0-alpha.1] — 29-10-2026

### Correcciones de publicación
- Licencia del proyecto cambiada a **GPLv3**.
- Badge de issues apuntando al repositorio correcto (`jesuscastilla/TapeOS`).
- Workflow de release corregido (eliminado glob `dist/*.tar.gz` inexistente).
- Añadido `TapeOS.code-workspace` al control de versiones.

## [v1.0.0-alpha] — 28-10-2026

### Novedades
- **Instalador Interactivo para Windows**:
  - Interfaz gráfica (GUI en Windows Forms) con diagnóstico automático de CPU, firmware y BitLocker.
  - Asistente por consola (CLI/TUI) para instalaciones automatizadas.
  - Creación del medio de instalación (.img) para grabar después en USB.
- **Soporte Ampliado para Dispositivos Legacy**:
  - Matriz de soporte para procesadores Intel de 2ª a 7ª generación (Sandy Bridge, Haswell, Skylake) y AMD serie A (Stoney Ridge).
  - Soporte de arranque para sistemas con UEFI de 32 bits (`ia32`) en CPUs de 64 bits (Intel Atom Bay Trail/Cherry Trail).
  - Soporte preliminar para arranque mediante BIOS Legacy / MBR.
- **Arquitectura y Estructura de Repositorio**:
  - Separación limpia de componentes: `installer/`, `core/`, `boot/`, `tools/` y `docs/`.
  - Integración de scripts de búsqueda de imágenes oficiales vía `cros.tech` (`tools/fetch_recovery.py`).
  - Workflows de CI/CD para GitHub Actions (`build.yml`, `release.yml`).
