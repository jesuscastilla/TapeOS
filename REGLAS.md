# REGLAS.md - Reglas permanentes del proyecto TapeOS

## Identidad
- TapeOS es una EVOLUCIÓN PROPIA del framework de compatibilidad. NO se menciona el
  proyecto base en el instalador, el sistema ni el arranque (los créditos se mantienen
  SOLO en el README, por licencia GPL).
- Marca: TapeOS / DiploTech. Idioma por defecto: EPA; Español seleccionable.
- Estructura interna: `core/framework/` (motor de compatibilidad + capa TapeOS).

## Dos versiones oficiales
- **TapeOS** (completa): base ChromeOS oficial (descargada limpia de Google CDN), con Google Play OPCIONAL.
- **TapeOS Free**: base libre/openFyde genérica (Intel o AMD). Cuenta LOCAL sin
  Google en el OOBE, Crostini, Android + Aurora Store y navegador Chromium.

## Arquitectura de Distribución y Viabilidad (Late-Binding Obligatorio)
- **PROHIBICIÓN ESTRICTA DE MONOLITOS PRE-PARCHEADOS**: NUNCA pre-construir, compilar
  ni alojar imágenes de disco completas (.img / .iso / .bin de varios GB) por cada combinación
  de hardware, GPU, TPM, kernel o parches. La explosión combinatoria hace inviable el proyecto.
- **DESACOPLAMIENTO BASE vs FRAMEWORK (Late-Binding)**:
  - Las imágenes base del sistema permanecen limpias e intactas, descargadas directamente desde
    sus repositorios oficiales (Google CDN para ChromeOS; base genérica limpia para Free).
  - El desarrollador SOLO mantiene y distribuye el paquete ligero del **Framework TapeOS**
    (kernel + initramfs + scripts de parcheo, ~150-200 MB) y el instalador de Windows.
  - Los parches (dGPU, GPU legacy, audio, WiFi, swtpm, no_google_play) se inyectan dinámicamente
    en tiempo de arranque (*Late-Binding*) mediante parámetros en `grub.cfg` (`options=...`)
    y se ejecutan desde el `initramfs` en RAM (vía OverlayFS / runtime hooks).
- **INSTALACIÓN EN DESTINO (CERO WSL PARA EL USUARIO FINAL)**:
  - El usuario final en Windows no necesita WSL ni compilar imágenes ext4 de 10 GB.
  - El instalador descarga la base limpia oficial, graba la imagen en el pendrive USB, inyecta
    el framework TapeOS (GRUB + initramfs) en la partición ESP/ROOTC y escribe el `grub.cfg`
    con las opciones detectadas automáticamente.
- `tapeos-config.json`: Configuración de URLs de descarga upstream/repositorio. NUNCA depender
  de almacenamiento masivo de imágenes completas en servidores personales o NAS.
- Detección de firmware: UEFI x64, UEFI ia32 y BIOS Legacy, siempre con explicación
  breve en el wizard. Imágenes híbridas (UEFI + BIOS) cuando sea posible.
- Genérico por diseño: cualquier board del catálogo, CPU, GPU y firmware.
- Las opciones de framework SIEMPRE se derivan del hardware detectado (nunca fijas).

## Sistema
- Terminal Linux (Crostini) y Centro de software (Flatpak + GNOME Software + Flathub)
  disponibles desde el primer arranque en ambas versiones.
- Sin Play: Aurora Store preinstalada y navegador Chromium.
- zram 150 %, parches de GPU (dgpu/legacy), WiFi, audio y táctil automáticos mediante `options=`.
- GRUB propio y legible; sin menús de configuración del framework base.

## Calidad y Saneamiento
- Validar parse (PS 5.1), smoke test de la GUI y rutas críticas en cada cambio.
- Actualizar `CHANGELOG.md` y `CONTEXT.md`; versionar (alpha.NN) y publicar release.
- Compatibilidad obligatoria con Windows PowerShell 5.1 (el EXE).
- Scripts .sh en LF; archivos .ps1 con BOM UTF-8 (PowerShell 5.1 los lee como ANSI sin BOM).
- Los .ps1 usan CRLF simple; NUNCA re-normalizar finales de línea sobre archivos ya CRLF (rompe las continuaciones con backtick). Ejecutar `tools/validate-pipeline.ps1` antes de cada release.
- Higiene del repositorio: NUNCA commitear imágenes de disco (.img, .bin, .iso), archivos comprimidos de gran tamaño (.zip, .tar.gz) ni temporales de compilación.
