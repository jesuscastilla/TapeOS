# Guía de Instalación en Windows — TapeOS

Esta guía describe cómo instalar **TapeOS** directamente desde Windows utilizando el instalador gráfico interactivo o la línea de comandos, sin necesidad de configurar manualmente WSL2 ni recurrir a herramientas complejas.

---

## 🚀 Requisitos Previos

1. **Equipo con Windows 10 u 11** (64 bits).
2. **Espacio en disco**: Mínimo 16 GB libres (se recomiendan 32 GB o más).
3. **Privilegios de Administrador**: El instalador solicitará elevación automáticamente.
4. **Desactivar BitLocker y Fast Startup**:
   - Si tu partición `C:` está cifrada con BitLocker, debes suspenderlo o desactivarlo temporalmente para permitir que GRUB lea el disco sin bloqueos.
   - Desactiva el inicio rápido de Windows (*Fast Startup*) para evitar que el sistema de archivos NTFS quede bloqueado en estado de hibernación.

---

## ⚡ Método 0: Ejecutable (EXE) autocontenido

La forma más sencilla para el usuario final:

1. Descarga **`TapeOS-Installer-<versión>.exe`** desde la sección [Releases](https://github.com/jesuscastilla/TapeOS/releases).
2. Haz doble clic. El ejecutable incluye la interfaz y los 7 módulos (no necesita PowerShell configurado ni asociaciones de archivos) y pedirá permisos de administrador (UAC).
3. Si Windows SmartScreen muestra un aviso, instala el certificado de TapeOS (`tapeos-signing.cer`, adjunto en la release) como **Editor de confianza**: doble clic -> "Instalar certificado" -> Equipo local -> "Colocar todos los certificados en el siguiente almacén" -> **Editores de confianza**. También puedes pulsar **"Más información" -> "Ejecutar de todos modos"**.

---

## 🛠️ Método 1: Instalador Gráfico Interactivo (GUI)

El método recomendado para la mayoría de usuarios:

1. Ve a la carpeta `installer\windows\` dentro de este repositorio.
2. Haz doble clic en **`Run-Installer.cmd`** (o clic derecho en `TapeOS-Installer.ps1` -> *Ejecutar con PowerShell*).
3. El instalador detectará automáticamente:
   - Tu modelo de procesador y generación.
   - El modo de arranque del equipo (UEFI 64-bit, UEFI 32-bit o BIOS Legacy).
   - Estado de BitLocker y Secure Boot.
   - **WiFi, Bluetooth, códecs de audio y pantalla táctil**, y elegirá los parches de compatibilidad adecuados (`iwlwifi_backport`, `broadcom_wl`, `rtl*`, `rtbth`, `essx8336`, `ipts/goodix`, ...).
   - La imagen de recuperación de ChromeOS recomendada (ej. `voxel`, `jinlon`, `rammus`, `grunt`, etc.).
4. Selecciona tus preferencias:
   - **Modo**: **Live-USB** (graba TapeOS en un pendrive para arrancar desde él) o **Instalador** (crea el medio de instalación `.img` sin grabar; elige la carpeta de destino).
   - **Google Apps**: Elige entre **Con Google Apps** (Play Store + aplicaciones Android, recomendado) o **Sin Google Play** (Android con apps APK y tienda alternativa Aurora Store).
   - **Opciones Legacy**: Activa las casillas de GPU antigua o UEFI de 32 bits si tienes un equipo antiguo.

5. Pulsa **"Descargar, Parchear y Crear (1-Clic)"**.
6. ¡Listo! Con el modo **Live-USB**, reinicia el PC y arranca desde el pendrive (tecla F12/F11/Esc); con el modo **Instalador**, graba el `.img` cuando quieras.

---

## 💻 Método 2: Asistente Interactivo por Consola (CLI)

Para entornos automatizados o administración remota:

1. Abre PowerShell como Administrador.
2. Navega a `installer\windows\` y ejecuta:
   ```powershell
   .\TapeOS-CLI.ps1
   ```
3. Sigue las instrucciones paso a paso en pantalla: diagnóstico, modo Live-USB o Instalador, Google Apps (con Play Store o sin ellas) y confirmación.

---

## 🛡️ Secure Boot (Arranque Seguro)

Si tu equipo tiene **Secure Boot activado**, en el primer arranque podría aparecer una pantalla azul indicando `Verification failed: Access Denied`.

Para autorizar la clave de TapeOS:
1. Pulsa **OK**.
2. Selecciona **Enroll key from disk**.
3. Navega a la partición **EFI-SYSTEM** o busca el archivo **`tapeos.der`**.
4. Pulsa **Continue** y reinicia el equipo.

---

## 🔧 Solución de Problemas Comunes

- **El equipo se queda en el logo de ChromeOS**:
  - TapeOS detecta y parchea automáticamente las GPUs dedicadas (opción `dgpu`: NVIDIA suspendida renderizando con la iGPU; AMD con `amdgpu`). Si aun así no arranca, entra en el menú de configuración del arranque (*Settings*) y desactiva la GPU dedicada para usar los gráficos integrados.
- **Sin audio en portátiles antiguos**:
  - Selecciona un kernel *Legacy* (5.10 o 5.4) en el instalador y habilita la opción de parches ALSA UCM antiguos.
