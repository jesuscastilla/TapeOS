# Arquitectura de Parches: ChromeOS Actualizado en Equipos EFI Antiguos — TapeOS

Este documento detalla la ingeniería y los mecanismos de parcheo que utiliza **TapeOS** para permitir que una **versión moderna y actualizada de ChromeOS** (v120–v134+) funcione de manera fluida y estable en **ordenadores antiguos con firmware EFI**.

---

## 🎯 El Problema con Brunch y ChromeOS Oficial en Hardware Antiguo

A medida que Google actualiza ChromeOS:
1. **Fin de soporte (AUE)**: Google retira de soporte los Chromebooks antiguos basados en Intel Core de 2ª a 8ª generación (Sandy Bridge, Ivy Bridge, Haswell, Broadwell, Skylake, Apollo Lake).
2. **Abandono de drivers gráficos clásicos**:
   - El compositor de ChromeOS (**Freon**) requiere asignación de buffers mediante `minigbm` y soporte DRM/KMS moderno.
   - Las versiones recientes de Mesa abandonaron los controladores clásicos `i915` e `i965`, forzando el nuevo controlador `crocus` que puede fallar o provocar cuelgues en gráficas Intel HD 2000 / 3000 / 4000 / 4400 si se solicitan capacidades no soportadas (Vulkan, modificadores DRM avanzados, compresión de color CCS).
3. **Consumo de memoria de Android (ARCVM)**:
   - Las compilaciones modernas sustituyeron los contenedores ligeros de Android 9/11 (`ARC++`) por máquinas virtuales completas (`ARCVM`). En PCs con 2 GB o 4 GB de RAM, esto agota la memoria física y congela el sistema.
4. **Requisitos de seguridad y TPM**:
   - Modern ChromeOS exige hardware TPM 2.0 para el cifrado de datos de usuario (*cryptohome*). Las placas base EFI antiguas carecen de TPM o solo cuentan con TPM 1.2 obsoleto.
5. **Firmware UEFI de 32 bits en procesadores de 64 bits (`ia32`)**:
   - Muy extendido en tablets y netbooks Intel Atom (Bay Trail Z3735F, Cherry Trail x5-Z8350, Celeron N2800). Los cargadores estándar de 64 bits (`bootx64.efi`) son invisibles para este firmware.

---

## 🧩 La Solución TapeOS: El Motor de Parches en 5 Capas

TapeOS no utiliza una versión vieja de ChromeOS desactualizada; en su lugar, **toma la última versión oficial de ChromeOS y la parchea en caliente durante el arranque** mediante su partición `ROOTC` y su `initramfs` inteligente.

```text
┌────────────────────────────────────────────────────────────────────────┐
│            1. ARRANQUE EFI HÍBRIDO (UEFI x64 / UEFI ia32)             │
│ • Detecta la arquitectura del firmware EFI.                            │
│ • Carga bootx64.efi o bootia32.efi con soporte para EFI stub mixto.    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     2. KERNEL MULTI-PERFIL TAPEOS                      │
│ • Parcheado con compatibilidad para GPUs retro (Intel i915 / AMD).     │
│ • Flags cmdline automáticas: i915.enable_guc=0, i915.enable_psr=0,     │
│   cros_legacy, efi=noruntime (si se detecta firmware EFI bugueado).    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                 3. INITRAMFS & EMULACIÓN DE SEGURIDAD                  │
│ • Arranca swtpm (TPM 2.0 emulado por software) antes de cryptohomed.  │
│ • Permite iniciar sesión con cuenta de Google y cifrado completo.      │
│ • Aplica parches al RootFS oficial de ChromeOS mediante overlayfs.     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│               4. ADAPTADOR DE GRÁFICOS PARA FREON / MESA               │
│ • Intercepta llamadas de minigbm para Intel Gen 2 a 7.5.              │
│ • Redirige a Mesa crocus optimizado (INTEL_DEBUG=noccs) o fallback    │
│   software rasterizer (llvmpipe) evitando la pantalla en negro.        │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│             5. GESTIÓN EFICIENTE DE RECURSOS & PLAY STORE              │
│ • Para CPUs antiguas: asignación preferente de recovery ARC++ (rammus) │
│ • Configuración agresiva de zram (150% de RAM) y swappiness para       │
│   mantener la fluidez en equipos con 2 GB / 4 GB de RAM.               │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Parches Específicos Integrados en TapeOS

### 1. Parche Gráfico para Freon (Intel HD 2000 / 3000 / 4000 / 5000)
- **Fichero**: `core/patches/10-legacy_gpu_freon.sh`
- **Función**:
  - Inyecta variables de entorno en `/etc/env.d/` para la sesión de ChromeOS:
    - `INTEL_DEBUG=noccs,norbc`: Desactiva algoritmos de compresión de framebuffer no soportados por hardware anterior a Skylake.
    - `MESA_LOADER_DRIVER_OVERRIDE=crocus`: Garantiza que Mesa utilice el driver moderno optimizado para Haswell/Ivy Bridge en vez de colapsar.
    - `CHROME_EXTRA_FLAGS="--disable-features=Vulkan,VulkanFromANGLE --ignore-gpu-blocklist --enable-gpu-rasterization"`: Obliga a Chromium a utilizar el backend OpenGL ES sin intentar inicializar Vulkan en tarjetas que no lo soportan.

### 2. Parche de Emulación TPM 2.0 (`swtpm`)
- **Fichero**: `core/patches/20-swtpm_legacy_tpm.sh`
- **Función**:
  - Genera un dispositivo de caracteres `/dev/tpm0` virtualizado mediante `swtpm` y `swtpm_bios`.
  - Permite a `cryptohomed` y `chapsd` inicializar el almacén seguro de claves sin exigir un módulo TPM 2.0 físico en la placa base.

### 3. Parche de Audio ALSA UCM para Chips Económicos
- **Fichero**: `core/patches/30-legacy_audio_ucm.sh`
- **Función**:
  - Carga los mapas de sonido UCM para procesadores Intel Atom (Bay Trail RT5640, Cherry Trail ES8316, Braswell NAU88L25).
  - Corrige el problema clásico de ChromeOS en portátiles chinos o convertibles donde no hay audio ni micrófono.

### 4. Parche de Firmware EFI de 32 bits (ia32)
- **Fichero**: `core/patches/15-efi_ia32_runtime.sh`
- **Función**:
  - Genera entradas de arranque compatibles con procesadores x86_64 ejecutando firmware EFI de 32 bits.
  - Pasa el parámetro `efi=noruntime` al kernel cuando se detecta que las llamadas a los servicios en tiempo de ejecución de la BIOS provocan *Kernel Panics* en tablets antiguas.
