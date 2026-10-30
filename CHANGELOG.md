# Îttoriâh de Kambiô (Xangelo) — TapeOS

Tô lâ modifikaçionêh notablêh de êtte proyêtto çe dokumentarán en êtte arxibo.

## [v1.0.0-alpha.54] — 30-10-2026

### Correcciones
- **Texto de fase sin recortes**: la etiqueta del paso de Ejecucion pasa de 28 a 38 px de alto con alineacion vertical centrada. El smoke test lo comprueba (`DIAG-CLIP`).
- **Imagen Free que se colgaba en el logo**: `apply-free.sh` recreaba ROOT-A con el 5 % de reserva y copiaba con `tar` sin `--sparse`, asi que el rootfs (2605 MB) no cabia en la particion (faltaban ~6 MB) y quedaba incompleto. Ahora recrea con `-m 0` (sin reserva), sin journal, copia con `--sparse`, aplica los parches en caliente y verifica el resultado.
- ROOT-A de FydeOS usa features ext4 propietarias (`ff000000`, R24-R31) que Linux no puede montar en rw: el script lo documenta y recrea la particion como ext4 estandar.

### Cambios
- Menu GRUB de Free: sin `noinitrd` y con `console=tty0` explicito para ver los mensajes en el modo verbose.

## [v1.0.0-alpha.53] — 30-10-2026

### Correcciones
- **Barra de progreso visible otra vez**: el wizard saltaba al paso 5 (inexistente tras quitar el paso de Recovery) y ocultaba todos los paneles. Ahora salta al paso 4 y hay clamp de seguridad (un indice fuera de rango nunca vuelve a dejar la interfaz en blanco). El smoke test lo comprueba.
- Aviso de pendrive ausente vuelve al paso Medio (indice 2).
- **Boton Cerrar al terminar**: al finalizar la grabacion, el boton `Siguiente` pasa a `Cerrar` (cierra la ventana).

### Cambios
- **Sin referencias a ChromeOS** en textos visibles del instalador, menus GRUB, sistema Free (lsb-release: `TapeOS Free (sin Google, con Android)`) e initramfs. Se conservan solo las URLs/API oficiales de descarga y las claves `CHROMEOS_RELEASE_*` del formato del sistema.

## [v1.0.0-alpha.52] — 30-10-2026

### Cambios
- **Parches automaticos segun el equipo**: el instalador detecta firmware (UEFI X64/IA32/BIOS), esquema de disco (GPT/MBR) y TPM. swtpm solo se aplica sin TPM; IA32 solo en tablets con UEFI 32 bits; legacy_gpu solo con kernel/GPU legacy. Eliminada la opcion manual de Modo BIOS.
- **Deteccion de GPT/MBR y TPM**: nuevos campos en el informe de hardware (`DiskLayout`, `TpmPresent`) mostrados en Detección y Resumen con la linea de arranque automático.
- **Ventana**: titulo `Instalador de TapeOS` e icono propio (tapeos.ico embebido en el EXE y aplicado a la ventana).
- **Mas aire entre el titulo del paso y los detalles** (margen ampliado en todos los pasos).
- **Emojis eliminados de TODO el proyecto** (instalador, modulos, READMEs, docs, plantillas y changelog).

## [v1.0.0-alpha.51] — 30-10-2026

### Cambios
- **Sin emojis**: eliminados todos los emojis de la interfaz del instalador y de los mensajes de los modulos (textos limpios, sin caracteres pictograficos).
- Limpieza de espacios residuales dejados por los emojis al inicio de los textos.

## [v1.0.0-alpha.50] — 30-10-2026

### Cambios
- **Paso de Recovery eliminado del wizard**: el recovery se elige automaticamente segun el hardware detectado y ya no es una opcion editable. El asistente pasa de 6 a 5 pasos (Detección → Aplicaciones → Medio → Resumen → Ejecución).
- La recomendacion automatica (codename + kernel) se muestra en el paso de Detección y en el resumen como informacion, no como opcion.
- Eliminados el combo de recovery, el boton `Buscar Última Versión` y su timer/consulta (el pipeline usa siempre `Recommendations.RecoveryCodename`).

## [v1.0.0-alpha.49] — 30-10-2026

### Correcciones
- **La GUI ya termina**: el timer que vigilaba el pipeline era local del handler (PowerShell lo recogia y el Tick nunca corria). Ahora vive en el scope del script; al acabar: fase `Si Kompletao`, barra 100%, ETA `Kompletao`, boton Siguiente visible y `Pipeline completado sin errores.` en el log.
- **Rama Live-USB reescrita**: habia un bloque duplicado anidado en el catch de la rama WSL; el MessageBox de exito solo salia en el flujo clasico. Ahora hay cierre unico (imagen/WSL/clasico) con MessageBox `Grabaçiôn Kompletá`.
- **Timers del paso 2** (consulta de version): mismo arreglo de scope (`$script:qTimer`, etc.).
- **Acentos**: BOM UTF-8 en los 5 modulos que no lo tenian (se acabaron los `Ã¢` en el panel de log).
- **Sin restos de la base original**: parametros `-FrameworkScriptDir/-FrameworkAssetsDir` (con alias retrocompatibles), textos y rutas `dist\framework`.

### Novedades
- **Barra de progreso al final**: la barra de la fase de ejecucion queda justo encima del log, con el ETA a su derecha sin recortarse (se recoloca al redimensionar).

## [v1.0.0-alpha.48] — 30-10-2026

### Mejoras
- **Descarga con curl.exe**: 4x-8x mas rapida que WebClient (fallback automatico si falta curl).
- **Imagen Free local**: si existe `TapeOS-Free-*.img` en dist/, C:\TapeOS\images o assets, se graba directamente sin descargar.
- Flujo de descarga Free validado de punta a punta en PS 5.1 (catalogo con BOM, curl, SHA256, descompresion).

## [v1.0.0-alpha.47] — 30-10-2026

### Korreççionêh
- **Descarga del catalogo arreglada**: el NAS sirve images.json con BOM UTF-8 y PS 5.1 lo decodificaba como ANSI (`ConvertFrom-Json` fallaba con "Primitivo JSON no valido"). Ahora se decodifican los bytes como UTF-8 y se elimina el BOM.
- **TLS**: `RecoveryDownloader` ya no fija TLS 1.2 (rompia el canal seguro con el NAS); se usa `SystemDefault` en descargas y catalogo.
- El fallback clasico ya no se activa por estos motivos: el flujo descarga la imagen del NAS y la graba.

## [v1.0.0-alpha.46] — 30-10-2026

### Korreççionêh
- **Pipeline roto por dobles CR**: las reescrituras habian dejado `\r\r\n` en TapeOS-Installer.ps1 (1255 secuencias); los backticks de continuacion se cortaban y `Invoke-TapeOSImagePatch` se ejecutaba sin argumentos ("faltan los parametros obligatorios RecoveryZipPath OutputDir"). Archivo normalizado a CRLF simple y verificado byte a byte.
- **Validador permanente**: `tools/validate-pipeline.ps1` (parse aislado del pipeline, dobles CR, argumentos de las llamadas clave y binding real de ImagePatch) integrado en el smoke test. Regla anadida a REGLAS.md.

## [v1.0.0-alpha.45] — 30-10-2026

### Nobedáêh
- **Catálogo con variantes**: `images.json` ahora distingue `version: full | free`; la imagen TapeOS Free (APU/AMD) esta publicada en el NAS.
- **Instalador integrado**: al elegir "Software Libre" (sin Google Play) descarga y graba la imagen Free automaticamente; con Google Play usa la imagen full de la board elegida.

## [v1.0.0-alpha.44] — 30-10-2026

### Nobedáêh
- **TapeOS Free sobre FydeOS/openFyde**: `core/free/apply-free.sh` adapta imagenes ChromiumOS (FydeOS v23.1) a TapeOS Free: cuenta local sin Google (de serie), rebranding, parches 90-97 (dGPU AMD, Aurora Store, Crostini + Centro de software, zram) y GRUB propio de 5 entradas.
- Primera imagen Free generada y verificada: `TapeOS-Free-APU-v23.1.img` (AMD/APU, con parche dgpu).
- Nota tecnica: ROOT-A de FydeOS usa features ext4 nuevos (se recrea con ext4 estandar); la variante iris es un instalador (rootfs en STATE/dev_image), pendiente de inyeccion directa.

## [v1.0.0-alpha.43] — 30-10-2026

### Nobedáêh
- **Terminal Linux automatica (Crostini)**: parche `97-tapeos-crostini.sh` habilita Crostini desde el primer arranque en ambas versiones.
- **Centro de software**: Flatpak + GNOME Software + Flathub instalados dentro del contenedor con lanzador "Centro de software TapeOS"; en la version Free ademas Chromium (navegador libre).
- Wrapper `tapeos-software-center` en el sistema (vsh a penguin) y script del contenedor.

## [v1.0.0-alpha.42] — 30-10-2026

### Nobedáêh
- **Catalogo de imagenes sin WSL**: el asistente descarga la imagen preconstruida del NAS (URL configurable en `tapeos-config.json`, hostname publico), verifica SHA256, descomprime (.img.gz) y la graba. Sin WSL en el destino.
- **Primeras imagenes publicadas**: voxel M168 y rammus M149 (hibridas UEFI+BIOS, con todos los parches) en el NAS con catalogo `images.json`.
- `tools/publish-images.ps1` (catalogo + subida SSH) y `ImageCatalog.psm1` (descarga/verificacion/descompresion con progreso).
- EXE aligerado: los artefactos del framework viajan en las imagenes, no en el bundle (265 KB).
- Limpieza de espacio: recoveries, imagenes intermedias y EXEs antiguos eliminados (local y remoto gestionado).

## [v1.0.0-alpha.41] — 30-10-2026

### Nobedáêh
- **Modo BIOS (sin UEFI)**: las imagenes son hibridas (UEFI + BIOS Legacy). Particion BIOS-BOOT (p13) + GRUB i386-pc instalado en el MBR (`grub-pc-bin`/`grub2-common`); el grub.cfg usa `search --set=root --file /kernel` (funciona en ambos firmwares).
- **Wizard**: nueva opcion "Modo BIOS (sin UEFI)" en el paso Medio con explicacion breve en EPA/Espanol.
- GRUB sin theme del framework base (texto limpio de TapeOS).

## [v1.0.0-alpha.40] — 30-10-2026

### Nobedáêh
- **REGLAS.md**: reglas permanentes del proyecto (identidad, dos versiones, instalacion sin WSL en destino, BIOS, Crostini, calidad).
- **Rebranding total**: `core/brunch` -> `core/framework`, `BrunchInstaller` -> `FrameworkInstaller` y eliminadas las referencias al framework base del instalador, el sistema y el arranque (GRUB, initramfs con identidad TapeOS, sin theme del framework base). Los creditos permanecen solo en el README (GPL).
- **TapeOS Free** (plan): base openFyde/FydeOS con cuenta local sin Google, Crostini, Android + Aurora y Chromium.

## [v1.0.0-alpha.39] — 30-10-2026

### Nobedáêh
- **Cualquier recovery**: el flujo Brunch+TapeOS ya no esta fijado a una board. El asistente usa el recovery elegido en el paso 2 (kanix/voxel/jinlon/gumboz/zork/rammus/samus/grunt/cyan), calcula las opciones de framework del hardware detectado (dgpu, wifi, audio, tactil, no_google_play...) y las aplica en el GRUB generado (plantilla `__TAPEOOS_OPTIONS__`).
- **Imagenes por board**: la busqueda de imagen preconstruida filtra por codename (`TapeOS-<board>-*.img`) con fallback generico.
- `build-tapeos-img.sh <recovery.bin> <salida.img> [GB] [opciones]` acepta las opciones como 4. argumento; `install-brunch-usb.sh` y `apply-tapeos.sh` usan `TAPEOOS_OPTIONS`.

## [v1.0.0-alpha.38] — 30-10-2026

### Nobedáêh
- **Imagen completa sin WSL en el destino**: `build-tapeos-img.sh` genera `TapeOS-<board>-M<ms>-brunch.img` (16 GB) con Brunch + todos los parches y el GRUB ya aplicados. Se graba en cualquier maquina con Rufus/Win32DiskImager o con el propio asistente (rama de grabacion directa de imagen, sin WSL).
- **Copia rapida por offsets**: `write-brunch-fast.sh` usa bs=4M con offsets alineados y bs=512 en sectores para los no alineados (arregla la corrupcion de GPT detectada con bs=1M).
- **Construccion fiable**: la imagen se genera dentro del ext4 de WSL (`/tmp`) y se copia a NTFS al final (DrvFs/9P corrompe los offsets grandes).

## [v1.0.0-alpha.37] — 30-10-2026

### Nobedáêh
- **Base Brunch r154**: el asistente instala Brunch (ChromeOS r154, kernels r156) + capa TapeOS vía WSL: particionado Brunch (`brunch-partition.sh`), copia rápida por offsets (`write-brunch-fast.sh`) y capa TapeOS (`apply-tapeos.sh`: parches 90-96, Aurora Store, herramientas del instalador a disco y GRUB sin menú de configuración).
- **Parches automáticos según el hardware**: dGPU AMD (`dgpu`), GPU Intel legacy (`legacy_gpu`), WiFi (`iwlwifi_backport`), audio/táctil, zram 150%, branding y sin Google Play + Aurora Store (`no_google_play`).
- **Menú GRUB de 6 entradas sin configuración de Brunch**: normal / verbose / seguro / Instalar en disco / consola / apagar, con `options=` fijas calculadas por el instalador.
- **Instalador a disco duro**: `tapeos-install.sh` en ROOT-C con resize2fs/e2fsck (vuelca el USB, repara la GPT y expande ROOT-A al tamaño del disco).
- **Fallback**: sin WSL o sin artefactos de Brunch se usa la grabación clásica del recovery.

## [v1.0.0-alpha.36] — 29-10-2026

### Korreççionêh
- **Arranque real con kernel Linux de PC**: el kernel del recovery de ChromeOS (`voxel`) no arranca en un PC normal (vboot/`cros_efi`: pantalla negra en modo normal y reinicio con `nomodeset`). El menú usa ahora un kernel Linux de PC (`/tapeos/vmlinuz`, Ubuntu 6.8) para las entradas 1-4 y deja el kernel del recovery como opción 5.
- **Menú GRUB de 8 entradas** con timeout de 20 s y comprobación de `/tapeos/vmlinuz` + `/tapeos/initramfs.img` (aviso en pantalla si faltan).
- **Inyección completa en la ESP**: el instalador Windows copia kernel + initramfs + menú; el EXE los empaqueta y el CI los publica en cada release.

### Nobedáêh
- `Write-TapeOSGrubToEsp -KernelImagePath` inyecta el kernel Linux de PC en `\tapeos\vmlinuz`.

## [v1.0.0-alpha.35] — 29-10-2026

### Nobedáêh
- **Menú GRUB de TapeOS**: 7 entradas legibles (normal, diagnóstico verbose, modo seguro, Instalar en un disco duro, recovery original, consola GRUB y apagar) con timeout de 15 s y aviso en pantalla si falta el initramfs.
- **Initramfs del framework**: build reproducible en WSL/Linux (`core/build/build-initramfs.sh`) con busybox estático, cgpt/sgdisk/resize2fs/e2fsck, swtpm y los parches de TapeOS.
- **Instalador a disco duro**: `core/scripts/tapeos-install.sh` vuelca el USB completo, reubica la GPT de respaldo (`sgdisk -e`), expande ROOT-A al tamaño del disco, aplica los parches y reescribe el menú GRUB del destino con el nuevo PARTUUID.
- **Arranque verbose**: `verbose` en la línea del kernel y `set -x` en el initramfs, con logs en consola y shell de rescate (fin de la pantalla en negro silenciosa).
- **Inyección automática**: tras grabar el Live-USB, el instalador Windows escribe el menú y el initramfs en la ESP; `build-exe.ps1` empaqueta el initramfs dentro del EXE y el CI lo construye en `ubuntu-latest` para cada release.

### Korreççionêh
- Los parches del framework usan `TAPEOOS_ROOT` (aplicables desde el initramfs y desde el instalador).
- `ImagePatcher` genera el menú a través de `BootManager` (una sola fuente de verdad para el GRUB).

## [v1.0.0-alpha.34] — 29-10-2026

### Nobedáêh
- **Bentana redimençionable y maximisable**: `FormBorderStyle = Sizable`, `MaximizeBox = $true`, `MinimizeBox = $true` y `MinimumSize = 920x600`. Permite adâttâh er tamaño der wîçâh a kuarkêh pantaya o eçkalao DPI sin recortâh kontenío.
- **Dîppóçiçiôn repponçiba kon Anchors y Dock**: tô lô panelêh (`Dock = Fill`), tarheta de kontenío, chips de paçô (`Update-TapeOSStepChips`), franhâ tricolôh de la bandera andalûça, kaxa de lîtta y botonêh de nabegaçiôn çe redimençionan y adaptan proporçionâhmente.
- **Botón 1-Klik çentrao**: `$btnCreate` mantienê çentrao automátiko horiçontâh y anclao al fondo de la tarheta en kuarkêh tamaño de bentana.

### Korreççionêh
- **Kabêçera kon FlowLayoutPanel antikoordiná**: er títulô y çûttitulo çe apilan en un contenedor de flûho bertikâh, ebitando al 100% kuarkêh çolapamiento o rebanamiento horiçontâh de tipografía baho eçkaláô DPI (125%-150%).
- **AutoScaleMode = None**: ebitá dehfaçê de eçkalao automátiko de fuêntê çobre koordinâ fijâ.
- **Franha tricolôh dinámika**: kalkulá dinámikamente ar fondo de la kabêçera kon 3 tramos identikô.
- **Korreççiôn en tradûççiôn**: er çelettôh en modo «Español» yá indiqa «Asistente de instalación · Español» en lûgâh de duplicâh «Andaluz».
## [v1.0.0-alpha.33] — 29-10-2026

### Korreççionêh
- **Bentana mâh grande (1000x730)** y layout rekalkulao: kabêçera de 86 px (er çûttitulo yá no çe korta), chip de paçô de 150x36, tarheta de kontenío 952x384, lîtta de lôh 952x92 y botonêh de nabegaçiôn 160x46.
- **Çûttitulo korto**: «Açîtente de îttalaçiôn · Andalûh» (yá no duplika lô 6 paçô de lô chip).
- **Franha tricolôh dêntro de la kabêçera**: er tramo blanko yá kontrâtta çobre berde (antê pareçía una línea blanka çuerta).
- **Fin der rekuadro açûh der çelettôh de idioma**: `TabStop` dehattilitao y foko iniçiâh en «Çiguiente ›».
- Tipografía eçkalá: títulô 15pt, kuerpô 10pt, bâttonêh 10pt y chip 9.5pt.

## [v1.0.0-alpha.32] — 29-10-2026

### Nobedáêh
- **Intêrfâh renobá**: êttilô bîttualêh modernô (`EnableVisualStyles`), paleta unifiká (berde korporatibo/blanco/grih berdoço), bâttonêh planô kon êkkinâ redondeâ y êttáô hober, chip de paçô koloreáô (attibo berde) y tarheta de kontenío kon borde çuabe.
- **Arrankê al îttante**: la detêççiôn de hardware, er katálogo de rekûperaçionêh y la detêççiôn USB çe ehecutan trâh muêttrâh la bentana (funçiôn `Initialize-TapeOSDetection` en er ebento Shown kon timer de repôtto), eliminando la êppera kon pantaya en blanko.
- **Çîn parpadeo**: doble buffering en toô lô kontrolê der formulario.
- **Arnêh mehoráo**: kaptûra êhâtta der área de kliênte (çîn marko ni barra de título) y diânnôttiko de iniçialiçaçiôn en er log de balidáçiôn.

### Korreççionêh
- Mêkla de êttilô de bâttonêh (kláçikô + planô) eliminá: toô lô bâttonêh komparten er mîmmo lênnüahe bîttuâh.
- Fondo der formulario kon bandera a troçô (franhâ dehkalineâh trâh lô panelêh) çûttituío por fondo nêttro kon franha tricolôh de açênto baho la kabêçera.

## [v1.0.0-alpha.31] — 29-10-2026

### Korreççionêh
- **Wîçâh kompakto 900x660**: lô botonêh de nabegaçiôn y er lîtta de lôh yá no quedan kortáô en pantayâ de portátih; tô lô kontrolê kaben dentro der área de kliênte (`ClientSize`) çin çolapâh ni barra de depplaçamiento.
- **Fondo çin dehformaçionêh**: la bandera de Andalûçia çe dibuha ar tamaño êhâtto der área de kliênte en lûgâh de êttirâhla kon `Stretch`, y çe elimina er `AutoScroll` der formulario.
- **Balidáçiôn de dîppóçiçiôn**: `tools/wizard-smoke-test.ps1` komprueba ke nîn pun kontrol çe çalga der área de kliênte (`%ProgramData%\TapeOS\wizard-layout-check.log`) y guarda una kaptûra (`dist/gui-snapshot.png`).

## [v1.0.0-alpha.30] — 29-10-2026

### Nuevo
- **Wizard rediseñado a 6 pasos**: Detección → Recovery → **Aplicaciones** (software libre con explicación / Google Play con explicación) → **Medio** (.img o Live-USB) → Resumen → Ejecución.
- **Idioma dinámico completo**: el selector Andaluz/Español ahora retraduce también el resumen de detección de hardware, la recomendación de recovery, las explicaciones y el resumen final.
- **DPI-aware**: la ventana ya no se ve borrosa en pantallas de alta densidad (SetProcessDPIAware + fondo redibujado a resolución exacta + logo re-escalado con interpolación de alta calidad).

### Korreççionêh
- **Timeout de 15 s en la consulta al CDN**: si no hay internet ya no se queda atascado el paso 2; avisa y usa la versión estable del catálogo local.
- **Validación en Live-USB**: si no hay pendrive conectado, avisa y vuelve al paso Medio en lugar de avanzar a ciegas.
- Ventana compacta (920x780) para que quepan todos los controles en pantallas de portátil.

## [v1.0.0-alpha.29] — 29-10-2026

### Korreççionêh
- **Arreglao error "op_Addition" al abrir el wizard (PS 5.1)**: `New-Object System.Drawing.Point(15 + ($i * 166), 14)` no parsea el operador `+` en listas de argumentos de `New-Object` en PowerShell 5.1 (el host del EXE). Se precalcula la coordenada en variable. **El wizard nunca llegaba a mostrar la ventana.** Validado con arnés de arranque completo sin excepciones.

## [v1.0.0-alpha.28] — 29-10-2026

### Korreççionêh
- **Callback de progreço a pruebâ de balâ**: lâ âttualiçaçionêh de ETA y barra çe prekalkulan fûera de lô `Invoke` (la UI çolo açîna balorêh çimples) y tô lô callback êttán embueltô en try/catch kon log, eliminando er fallo "op_Addition" ke çerraba la app dêhde er hilo de ebentô de dehkarga.

## [v1.0.0-alpha.27] — 29-10-2026

### Nobedáêh
- **Tradûttôh EPA kon andaluh-py**: erramienta `tools/epa-translate.py` (biblioteka [andaluh-py](https://github.com/andalugeeks/andaluh-py) de AndaluGeeks) pa henerâh traduççionêh konçîttentêh a andalûh; kréditô añadíô en README (EPA y Êppanyôh).

## [v1.0.0-alpha.26] — 29-10-2026

### Nobedáêh
- **GUI reêkkrita komo wîçâh po paçô**: 1. Detêççiôn de hardware → 2. Rekomendaçiôn de rekûperaçiôn → 3. Konfiguraçiôn → 4. Reçûmen → 5. Ehekuçiôn, kon indikadôh de etapa, barra de progreço y **ETA (tiempo êttimao) propî en kada etapa** (konhûtta, dehkarga, parcheo y grabaçiôn). EPA po defêto, kon çelettôh a Êppanyôh.
- **TODO en er README** (EPA y Êppanyôh): identidá andalûça, dokumentaçiôn de âttualiçaçionêh y eliminâh referençiâ a Google.

## [v1.0.0-alpha.25] — 29-10-2026

### Nobedáêh
- **Preçentaçiôn de GitHub renobá**: çeççiôn de identidá («çîttema operatibo propio, kreao en Andalûçia, çoftware libre kon Googlêh Play ôççionalêh»), çelettôh de idioma **EPA/Êppanyôh** (`README.md` + `README.es.md`), çeççiôn de **orígenêh y kréditô** a Brunch (Sebanc) kon lâ diferençiâ (çoftware libre, rebîtâliçaçiôn de hardware y lûtta kontra er dehperdiçio teknolóhiko) y dêkripçiôn/topî der repo âttualiáô.

## [v1.0.0-alpha.24] — 29-10-2026

### Nobedáêh
- **Andamiahe der framework kompletá**: `core/build/build-framework.sh` (kernêh + initramfs + ROOTC + yabê vboot + pakete tar.gz), `core/initramfs/init` (arranka swtpm, monta ROOT-A y aplika lô parcheh), y `core/build/README.md` en EPA kon lâ îttrûççionêh. Lîtta pa kompilâh en la próççima çeçiôn.

## [v1.0.0-alpha.23] — 29-10-2026

### Nobedáêh
- **Lengua EPA (Êttandâ pal andalûh)**: er îttaladôh (GUI y CLI), lô mençâhêh de lô módulô y lô dokumentô (README, guíâ, matrî, dokumento de parcheo, plantiyâ de GitHub, CONTRIBUTING) êttán yá en andalûh. La GUI uça EPA komo idioma po defêto (kon Êppanyôh komo âttênatiba).

## [v1.0.0-alpha.22] — 29-10-2026

### Correcciones
- **Limpieza de tabla de particiones antes de grabar**: Windows re-monta automáticamente los volúmenes desmontados y sigue protegiendo las ESP. TapeOS ahora ejecuta `diskpart clean` sobre el disco destino (tras desmontar todos los volúmenes) para que no quede nada que montar/proteger, y **reintenta automáticamente** la escritura si el primer intento falla con acceso denegado.

## [v1.0.0-alpha.21] — 29-10-2026

### Correcciones
- **Desmontaje de TODOS los volúmenes antes de grabar**: Windows protege las particiones de sistema (ESP) montadas aunque no tengan letra, denegando la escritura directa del disco (error Win32 5). TapeOS ahora desmonta con `mountvol /p` todos los volúmenes del pendrive (con y sin letra) antes de escribir. Escritura directa verificada con éxito en un adaptador SSD-USB.

## [v1.0.0-alpha.20] — 29-10-2026

### Correcciones
- **Desmontaje automático de volúmenes antes de grabar**: como Windows rechaza el bloqueo de volúmenes en medios extraíbles (error 6), TapeOS ahora desmonta los puntos de montaje del pendrive con `mountvol /p` antes de la escritura directa, liberando el disco (error Win32 5 resuelto). Al terminar, basta con reconectar el dispositivo.

## [v1.0.0-alpha.19] — 29-10-2026

### Correcciones
- **Grabación en USB reescrita con `WriteFile` nativo**: en medios extraíbles Windows rechaza `FSCTL_LOCK_VOLUME` (error 6), por lo que la escritura directa se hace ahora con la API `WriteFile` de kernel32 sobre el handle del disco físico (GENERIC_READ|GENERIC_WRITE), el mismo método de dd/Win32DiskImager. Se elimina la dependencia de FileStream para el dispositivo.

## [v1.0.0-alpha.18] — 29-10-2026

### Correcciones
- **Escritura en disco físico con volúmenes montados**: antes de grabar se **bloquean y desmontan los volúmenes** del pendrive (`FSCTL_LOCK_VOLUME` + `FSCTL_DISMOUNT_VOLUME` vía `DeviceIoControl`), eliminando el "Acceso denegado" al escribir sobre un volumen montado. Al terminar se desbloquean los volúmenes.

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
