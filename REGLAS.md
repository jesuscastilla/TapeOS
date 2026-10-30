# REGLAS.md - Reglas permanentes del proyecto TapeOS

## Identidad
- TapeOS es una EVOLUCION PROPIA del framework de compatibilidad. NO se menciona el
  proyecto base en el instalador, el sistema ni el arranque (los creditos se mantienen
  SOLO en el README, por licencia GPL).
- Marca: TapeOS / DiploTech. Idioma por defecto: EPA; Espanol seleccionable.
- Estructura interna: `core/framework/` (motor de compatibilidad + capa TapeOS).

## Dos versiones oficiales
- **TapeOS** (completa): base ChromeOS, con Google Play OPCIONAL.
- **TapeOS Free**: base openFyde (prototipo local con imagen FydeOS). Cuenta LOCAL sin
  Google en el OOBE, Crostini, Android + Aurora Store y navegador Chromium.

## Instalacion
- El equipo destino NO necesita WSL: descarga imagenes preconstruidas (NAS u otra URL
  configurable) y las graba con el flasher nativo. Rufus/Win32DiskImager tambien validos.
- WSL/Linux se usa SOLO para CONSTRUIR imagenes (build-tapeos-img.sh).
- `tapeos-config.json`: URL base de imagenes configurable; NUNCA hardcodear dominios
  de otros proyectos.
- Deteccion de firmware: UEFI x64, UEFI ia32 y BIOS Legacy, siempre con explicacion
  breve en el wizard. Imagenes hibridas (UEFI + BIOS) cuando sea posible.
- Generico por diseno: cualquier board del catalogo, CPU, GPU y firmware.
- Las opciones de framework SIEMPRE se derivan del hardware detectado (nunca fijas).

## Sistema
- Terminal Linux (Crostini) y Centro de software (Flatpak + GNOME Software + Flathub)
  disponibles desde el primer arranque en ambas versiones.
- Sin Play: Aurora Store preinstalada y navegador Chromium.
- zram 150 %, parches de GPU (dgpu/legacy), WiFi, audio y tactil automaticos.
- GRUB propio y legible; sin menus de configuracion del framework base.

## Calidad
- Validar parse (PS 5.1), smoke test de la GUI y rutas criticas en cada cambio.
- Actualizar `CHANGELOG.md` y `CONTEXT.md`; versionar (alpha.NN) y publicar release.
- Compatibilidad obligatoria con Windows PowerShell 5.1 (el EXE).
- Scripts .sh en LF; archivos .ps1 con BOM UTF-8 (PowerShell 5.1 los lee como ANSI sin BOM).
- Los .ps1 usan CRLF simple; NUNCA re-normalizar finales de linea sobre archivos ya CRLF (rompe las continuaciones con backtick). Ejecutar `tools/validate-pipeline.ps1` antes de cada release.
