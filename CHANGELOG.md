# Historial de Cambios (Changelog) — TapeOS

Todas las modificaciones notables de este proyecto se documentarán en este archivo.

## [v1.0.0-alpha.2] — 29-10-2026

### Novedades
- **Opción de Google Apps en el instalador**: elección entre instalar ChromeOS **con Google Apps (Play Store + Android)** o **sin ellas (modo ligero)**:
  - Selector en la GUI (radio buttons) y pregunta en el CLI.
  - Nueva opción de framework `no_google_apps` en la línea del kernel (`options=`), coherente con el patrón de Brunch.
  - Nuevo parche `core/patches/40-no_google_apps.sh` que elimina la sección ARC del config unibuild (JSON o configfs.img) para que ChromeOS no arranque el contenedor Android.
  - El modo elegido queda registrado en `tapeos_patches.json` y reflejado en el menú de GRUB generado.

## [v1.0.0-alpha.1] — 29-10-2026

### Correcciones de publicación
- Licencia del proyecto cambiada a **GPLv3** (coherente con Brunch upstream).
- Badge de issues apuntando al repositorio correcto (`jesuscastilla/TapeOS`).
- Workflow de release corregido (eliminado glob `dist/*.tar.gz` inexistente).
- Añadido `TapeOS.code-workspace` al control de versiones.

## [v1.0.0-alpha] — 28-10-2026

### Novedades
- **Instalador Interactivo para Windows**:
  - Interfaz gráfica (GUI en Windows Forms) con diagnóstico automático de CPU, firmware y BitLocker.
  - Asistente por consola (CLI/TUI) para instalaciones automatizadas.
  - Creación de discos virtuales sparse y automatización del menú BCD de Windows.
- **Soporte Ampliado para Dispositivos Legacy**:
  - Matriz de soporte para procesadores Intel de 2ª a 7ª generación (Sandy Bridge, Haswell, Skylake) y AMD serie A (Stoney Ridge).
  - Soporte de arranque para sistemas con UEFI de 32 bits (`ia32`) en CPUs de 64 bits (Intel Atom Bay Trail/Cherry Trail).
  - Soporte preliminar para arranque mediante BIOS Legacy / MBR.
- **Arquitectura y Estructura de Repositorio**:
  - Separación limpia de componentes: `installer/`, `core/`, `boot/`, `tools/` y `docs/`.
  - Integración de scripts de búsqueda de imágenes oficiales vía `cros.tech` (`tools/fetch_recovery.py`).
  - Workflows de CI/CD para GitHub Actions (`build.yml`, `release.yml`).
