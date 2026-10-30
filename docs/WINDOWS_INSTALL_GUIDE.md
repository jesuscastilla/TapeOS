# Guía de Îttalaçiôn en Windows — TapeOS

Êtta guía dêkribe kómo îttalâh **TapeOS** dirêttamente dêhde Windows utiliçando er îttaladôh gráfiko întêratibo u la línea de komandô, çîn neçeçidá de konfigurâh manûmente WSL2 ni rekûrrîh a erramientâ komplehâ.

---

## Rekîçitô Prebiô

1. **Ekîpo kon Windows 10 u 11** (64 bit).
2. **Êppaçio en dîkko**: Mínimo 16 GB librê (çe rekomiendan 32 GB u mâh).
3. **Pribilehiô de Adminîttradôh**: Er îttaladôh çoliçitará elebaçiôn automátikamente.
4. **Dehattibâh BitLocker y Fâtt Startup**:
   - Çi tu partiçiôn `C:` êttá çifrá kon BitLocker, debêh çûppendêl-lo u dehattibâl-lo temporalmente pa permettîh ke GRUB lea er dîkko çîn blokeô.
   - Dehattiba er iniçio rápido de Windows (*Fast Startup*) pa ebitâh ke er çîttema de arxivô NTFS kede blokeao en êttao de ibernaçiôn.

---

## Método 0: Ehekutable (EXE) autokontenío

La forma mâh çençiya pa er uçuario finâh:

1. Dehkarga **`TapeOS-Installer-<berçiôn>.exe`** dêhde la çeççiôn [Releases](https://github.com/jesuscastilla/TapeOS/releases).
2. Âtte doble klik. Er ehekutable inkluye la interfaç y lô 7 módulô (no neçeçita PowerShell konfigurao ni açôçiaçionêh de arxivô) y pedirá permiçô de adminîttradôh (UAC).
3. Çi Windows SmartScreen muêttra un abiço, îttala er çertifikao de TapeOS (`tapeos-signing.cer`, âhunto en la release) komo **Editôh de konfiança**: doble klik -> "Îttalâh çertifikao" -> Ekîpo lokâh -> "Kolokâh tô lô çertifikáô en er çiguiente âhmaçên" -> **Editorêh de konfiança**. También pueêh pulçâh **"Mâh informaçiôn" -> "Ehekutâh de tô modô"**.

---

## Método 1: Îttaladôh Gráfiko Întêratibo (GUI)

Er método rekomendao pa la mayoría de uçuariô:

1. Bé a la karpeta `installer\windows\` dentro de êtte repoçitorio.
2. Âtte doble klik en **`Run-Installer.cmd`** (u klik derexo en `TapeOS-Installer.ps1` -> *Ehekutâh kon PowerShell*).
3. Er îttaladôh detêttará automátikamente:
   - Tu modelo de proçeçadôh y heneraçiôn.
   - Er modo de arrankê der ekîpo (UEFI 64-bit, UEFI 32-bit u BIOS Legacy).
   - Êttao de BitLocker y Secure Boot.
   - **WiFi, Bluetooth, kódek de audio y pantaya tâttîh**, y elehirá lô parcheh de kompatibilidá adekuáô (`iwlwifi_backport`, `broadcom_wl`, `rtl*`, `rtbth`, `essx8336`, `ipts/goodix`, ...).
   - La imâhen de rekûperaçiôn de ChromeOS rekomendá (êh. `voxel`, `jinlon`, `rammus`, `grunt`, êtt.).
4. Çelehçiona tû preferençiâ:
   - **Modo**: **Live-USB** (graba TapeOS en un pendraîh pa arrankâh dêhde él) u **Îttaladôh** (krea er medio de îttalaçiôn `.img` çîn grabâh; elihe la karpeta de dêttino).
   - **Googlêh Play**: Elihe entre **Kon Googlêh Play** (Çtore + aplikâçionêh Android, rekomendao) u **Çîn Googlêh Play** (Android kon apph APK y tienda âttênatiba Aurora Çtore).
   - **Ôççionêh Legacy**: Attiba lâ kaçiyâ de GPU antigua u UEFI de 32 bit çi tienêh un ekîpo antiguo.

5. Pulça **"Dehkargâh, Parcheâh y Kreâh (1-Klik)"**.
6. ¡Lîtta! Kon er modo **Live-USB**, reiníçia er PC y arranka dêhde er pendraîh (têkla F12/F11/Eç); kon er modo **Îttaladôh**, graba er `.img` kuando kierâh.

---

## Método 2: Açîtente Întêratibo po Konçola (CLI)

Pa entornô âttomatiçáô u adminîttraçiôn remota:

1. Abre PowerShell komo Adminîttradôh.
2. Nabega a `installer\windows\` y ehekuta:
   ```powershell
   .\TapeOS-CLI.ps1
   ```
3. Çigue lâ îttrûççionêh paço a paço en pantaya: diagnóttiko, modo Live-USB u Îttaladôh, Googlêh Play (kon Çtore u çîn él) y konfîrmaçiôn.

---

## Secure Boot (Arrankê Çeguro)

Çi tu ekîpo tiene **Secure Boot attibao**, en er primêh arrankê podría apareçêh una pantaya açûh indikando `Verification failed: Access Denied`.

Pa otoriçâh la yabe de TapeOS:
1. Pulça **OK**.
2. Çelehçiona **Enroll key from disk**.
3. Nabega a la partiçiôn **EFI-SYSTEM** u bûhka er arxibo **`tapeos.der`**.
4. Pulça **Continue** y reiníçia er ekîpo.

---

## Çoluçiôn de Problemâ Komunêh

- **Er ekîpo çe keda en er logo de ChromeOS**:
  - TapeOS detêtta y parchea automátikamente lâ GPU dediká (ôççiôn `dgpu`: NVIDIA çûppendía renderiçando kon la iGPU; AMD kon `amdgpu`). Çi aun açí no arranka, entra en er menú de konfiguraçiôn der arrankê (*Settings*) y dehattiba la GPU dediká pa uçâh lô gráfikô integráô.
- **Çîn audio en portátilêh antiguô**:
  - Çelehçiona un kernel *Legacy* (5.10 u 5.4) en er îttaladôh y abilita la ôççiôn de parcheh ALSA UCM antiguô.
