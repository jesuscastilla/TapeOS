<div align="center">

<img src="tools/assets/diplotech-logo.png" alt="DiploTech" width="180" />

# 📼 TapeOS
### Suite Automatizada de ChromeOS para PC (Edición Moderna & Legacy EFI)
**Detecta tu hardware, descarga la última versión oficial de ChromeOS, aplica parches retro y la graba directamente en tu pendrive en 1 solo clic.**

[![License: GPL v3](https://img.shields.io/badge/License-GPL_v3-blue.svg)](LICENSE)
[![Platform: Windows / Linux](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-brightgreen.svg)]()
[![Hardware: Modern & Legacy](https://img.shields.io/badge/Hardware-Modern%20%26%20Legacy%20EFI-orange.svg)]()
[![Google CDN: Realtime API](https://img.shields.io/badge/ChromeOS-Chromium%20Dash%20API-informational.svg)]()
[![GitHub Issues](https://img.shields.io/github/issues/jesuscastilla/TapeOS?color=red)](../../issues)

[Visión General](#-visión-general) •
[Pipeline Automatizado](#-pipeline-automatizado-en-1-clic) •
[Soporte para Hardware Legacy](#-chromeos-actualizado-en-equipos-antiguos) •
[Instalador Windows](#-instalador-interactivo-para-windows) •
[Arquitectura de Parches](#-arquitectura-de-parches) •
[Estructura](#-estructura-del-proyecto)

---

</div>

## 📖 Visión General

**TapeOS** es un framework propio de arranque concebido para superar las limitaciones históricas de instalación y compatibilidad de ChromeOS en PCs.

Permite instalar una **versión oficial y completamente actualizada de ChromeOS** (v120–v149+, con **Google Play Store**, navegación web moderna y soporte de contenedores) en **ordenadores antiguos que cuenten con EFI**, así como en PCs y portátiles de última generación.

### ¿Qué hace único a TapeOS?
En las herramientas tradicionales, el usuario debía instalar WSL2, manejar manualmente comandos de consola Linux (`pv`, `cgpt`, `tar`, `unzip`), buscar y descargar a mano imágenes binarias gigantescas de sitios web externos, configurar cargadores de terceros y sufrir cuelgues o pantallas en negro en PCs anteriores a 2018.

**TapeOS automatiza el 100% de este proceso de principio a fin desde Windows:**
1. 🔍 **Escanea tu hardware**: CPU, GPU, modo de firmware (UEFI x64 o UEFI 32-bit `ia32`) y BitLocker.
2. 🌐 **Elige la imagen ideal**: Consulta la API oficial de Google (Chromium Dash) y selecciona la versión más moderna y estable para tu arquitectura.
3. ⬇️ **Descarga automática**: Descarga la imagen oficial de Google directamente con barra de progreso.
4. 🩹 **Aplica los parches de compatibilidad**: Inyecta cargadores EFI retro, emulación TPM 2.0 por software (`swtpm`), parches de GPU para Freon/Mesa y audio ALSA UCM.
5. 💾 **Graba directo en tu Pendrive USB**: Flashea el pendrive sector a sector con detección de seguridad (protegiendo discos internos y unidades del sistema).

---

## ⚡ Pipeline Automatizado en 1 Clic

```text
  [ 1. Detección ] ──► [ 2. Selección ] ──► [ 3. Descarga ] ──► [ 4. Parcheo ] ──► [ 5. Grabación ]
   CPU / GPU / EFI      API Google CDN       Progreso en vivo     Legacy EFI/TPM      Pendrive USB listo
   (Intel/AMD/ia32)     (Última versión)     (dl.google.com)       (Freon / Mesa)      (Sector a sector)
```

---

## 🏛️ ChromeOS Actualizado en Equipos Antiguos

Muchos ordenadores fabricados entre 2011 y 2018 cuentan con firmware **EFI** pero quedan fuera de soporte por los siguientes motivos que **TapeOS resuelve**:

| Reto en Hardware Antiguo | Causa en ChromeOS Moderno | Solución TapeOS |
|---|---|---|
| **Pantalla en negro al iniciar** | Drivers de Mesa modernos (`iris`) incompatibles con Intel HD 2000–4400. | Inyección de flags `INTEL_DEBUG=noccs`, forzado de driver `crocus` y OpenGL fallback. |
| **Error en inicio de sesión / Cuentas** | ChromeOS exige hardware TPM 2.0 inexistente en placas antiguas. | Emulación en segundo plano con `swtpm` (TPM 2.0 virtual) en el initramfs. |
| **Tablets Atom no arrancan (Bay/Cherry Trail)** | Firmware UEFI de 32 bits (`ia32`) en CPUs de 64 bits (ej. Z3735F). | Inclusión del bootloader dual `bootia32.efi` y `bootx64.efi`. |
| **Lentitud o congelamiento (2-4 GB RAM)** | El subsistema ARCVM (Android en VM) devora la memoria RAM. | Asignación preferente de recovery ARC++ (`rammus`) y compresión `zram` al 150%. |
| **Sin audio en netbooks económicos** | Dispositivos con códecs Intel SST o Realtek ES8316 / RT5640 sin configurar. | Mapas de sonido ALSA UCM inyectados en el arranque. |

---

## 🪟 Instalador Interactivo para Windows

El instalador se encuentra en `installer/windows/` y puede ejecutarse mediante interfaz gráfica o consola:

```text
installer/windows/
├── Run-Installer.cmd            # Lanzador rápido con elevación automática de permisos
├── TapeOS-Installer.ps1         # Interfaz Gráfica interactiva completa (GUI Windows Forms)
├── TapeOS-CLI.ps1               # Asistente interactivo por consola (TUI)
└── modules/
    ├── HardwareDetector.psm1    # Detección de CPU, GPU, UEFI x64 / ia32 y BitLocker
    ├── RecoveryDownloader.psm1  # Cliente Chromium Dash API y descargador oficial de Google
    ├── ImagePatcher.psm1        # Motor de extracción y parcheo de imágenes ChromeOS
    ├── UsbFlasher.psm1          # Grabador directo a pendrives USB con protección de discos
    ├── RecoveryCatalog.psm1     # Base de datos de compatibilidad y perfiles de hardware
    ├── DiskManager.psm1         # Utilidades de disco y descompresión
    └── BootManager.psm1         # Generador de configuraciones de arranque y GRUB
```

### Instrucciones de uso rápido:
1. Conecta un pendrive USB de **al menos 16 GB**.
2. Haz doble clic en el ejecutable **`TapeOS-Installer.exe`** (descargado de la sección Releases) o, si usas el ZIP, en **`installer\windows\Run-Installer.cmd`**.
3. El instalador detectará tu PC (CPU, GPU, WiFi, Bluetooth, audio y táctil) y seleccionará el recovery y los parches de hardware adecuados.
4. Elige si quieres **Google Apps (Play Store + Android)** o el modo ligero **sin ellas**.
5. Selecciona el destino: **grabar en pendrive USB** o **crear solo el archivo .img** (sin grabar).
6. Haz clic en **`⚡ Descargar, Parchear y Crear (1-Clic)`**.
7. ¡Listo! Al terminar, reinicia tu PC y arranca desde el pendrive (tecla F12, F11 o Esc según tu placa base).

---

## 📊 Matriz de Codenames Oficiales Soportados

| Generación de Procesador | Codename Oficial | Milestone Google | Kernel TapeOS | Tipo de Equipo |
|---|---|---|---|---|
| **Intel Core 14ª Gen / Ultra** | `brya` / `kanix` | **M156+** (Último) | `kernel-6.6` | Moderno (Meteor Lake) |
| **Intel Core 11ª - 13ª Gen** | `volteer` / `voxel` | **M156+** (Último) | `kernel-6.1` | Moderno (Tiger / Alder Lake) |
| **Intel Core 10ª Gen** | `hatch` / `jinlon` | **M156+** (Último) | `kernel-6.1` | Moderno (Comet Lake) |
| **Intel Core 4ª - 9ª Gen** | `rammus` | **M149** (Estable) | `kernel-5.10` | Legacy (Haswell a Coffee Lake) |
| **Intel Core 2ª - 3ª Gen** | `samus` / `rammus` | **M149** (Parcheado) | `kernel-legacy-5.4` | Retro (Sandy / Ivy Bridge) |
| **Intel Atom Bay / Cherry Trail** | `cyan` / `rammus` | **M149** (Parcheado) | `kernel-legacy-4.19` | Retro (UEFI 32-bit / Tablets) |
| **AMD Ryzen (Zen / Zen+ / Zen 2-4)**| `zork` / `gumboz` | **M156+** (Último) | `kernel-6.1` | Moderno (Radeon Vega/RDNA) |
| **AMD Legacy APU (A4-A10 / Stoney)**| `grunt` | **M149** (Estable) | `kernel-legacy-5.4` | Retro (Radeon clásica) |

---

## 🛠️ Desarrollo en el Repositorio

Si vas a trabajar en este proyecto con **VS Code** o cualquier IDE:

- **Tareas preconfiguradas** en `.vscode/tasks.json`:
  - `Ctrl + Shift + P` -> **Tasks: Run Task** -> `TapeOS: Launch Windows Installer (GUI)` para probar la interfaz.
  - `TapeOS: Run Hardware Detection` para verificar el diagnóstico de tu máquina.
- **Fuentes upstream**: La carpeta de referencia técnica local (material descargado de terceros) está excluida del repositorio y no se publica.

---

## 📄 Licencia

TapeOS se distribuye bajo la licencia **GNU GPLv3**. Componentes derivados de ChromiumOS o del kernel de Linux mantienen sus licencias originales respectivas (BSD / GPLv2).
