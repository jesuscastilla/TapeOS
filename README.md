<div align="center">

<img src="tools/assets/diplotech-logo.png" alt="DiploTech" width="180" />

# 🟩⬜🟩 TapeOS
### Çîttema operatibo baçao en XromiumÔ, con identidá andalûh y ôççión de îttalaçión çin çerbiçiô de terçerô.(Ediçiôn Moderna & Legacy EFI)
**Detêtta tu hardware, dehkarga la ûrtima berçiôn ofiçiâh de ChromeOS, aplika parcheh retro y la graba dirêttamente en tu pendraîh.**

[![License: GPL v3](https://img.shields.io/badge/License-GPL_v3-blue.svg)](LICENSE)
[![Platform: Windows / Linux](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-brightgreen.svg)]()
[![Hardware: Modern & Legacy](https://img.shields.io/badge/Hardware-Modern%20%26%20Legacy%20EFI-orange.svg)]()
[![Google CDN: Realtime API](https://img.shields.io/badge/ChromeOS-Chromium%20Dash%20API-informational.svg)]()
[![GitHub Issues](https://img.shields.io/github/issues/jesuscastilla/TapeOS?color=red)](../../issues)

[Biçiôn Henerâh](#-biçiôn-henerâh) •
[Piplîne Âttomatiçao](#-piplîne-âttomatiçao-en-1-klik) •
[Çoporte pa Hardware Legacy](#-chromeos-âttualiçao-en-ekîpô-antiguô) •
[Îttaladôh Windows](#-îttaladôh-întêratibo-pa-windows) •
[Arkîtêttûra de Parcheh](#-arkîtêttûra-de-parcheh) •
[Êttrûttûra](#-êttrûttûra-der-proyêtto)

---

</div>

> **Idioma / Lengua:** [Andalûh (EPA)](README.md) · [Español](README.es.md)

---

## 🏴🏳️ Un Çîttema Operatibo Propio, Kreao en Andalûçia

**TapeOS** êh un **çîttema operatibo propio** naçío en Andalûçia, publikao komo **çoftware libre** (GPLv3). Çe baça en la teknolohía de **ChromeOS** y **ChromiumOS**, kon una diferençia fundamentâh: la berçiôn **çîn Googlêh Play êh 100% libre** (çîn çerbiçiô de Google), mientrâ ke la berçiôn kompleta permite îttalâh lâ **Googlêh Play** çi er uçuario lo elihe.

Tô lô komponentêh propiô de TapeOS (îttaladôh, parcheh, initramfs y erramientâ) çon **çoftware libre** baho GPLv3; lô komponentêh de Google Çtore çon **ôççionalêh** y çolo çe añaden kuando tú lo pîêh.

---

## 📖 Biçiôn Henerâh

**TapeOS** êh un framework propio de arrankê konçebío pa çûperâh lâ limitaçionêh îttórikâ de îttalaçiôn y kompatibilidá de ChromeOS en PC.

Permite îttalâh una **berçiôn ofiçiâh y kompletamente âttualiçá de ChromeOS** (v120–v149+, kon **Google Play Çtore**, nabegaçiôn wê moderna y çoporte de kontenedorêh) en **ordenadorêh antiguô ke kuenten kon EFI**, açí komo en PC y portátilêh de ûrtima heneraçiôn.

### ¿Ké âçe úniko a TapeOS?
En lâ erramientâ tradiçionalêh, er uçuario debía îttalâh WSL2, manehâh manûmente komandô de konçola Linux (`pv`, `cgpt`, `tar`, `unzip`), bûhkâh y dehkargâh a mano imâhenêh binariâ hîgantêh de çitiô wê êtternô, konfigurâh kargadorêh de terçerô y çufrîh kuelgêh u pantayâ en negro en PC anteriôh a 2018.

**TapeOS âttomatiça er 100% de êtte proçeço de prinçipio a fîn dêhde Windows:**
1. 🔍 **Ehkanea tu hardware**: CPU, GPU, modo de firmware (UEFI x64 u UEFI 32-bit `ia32`) y BitLocker.
2. 🌐 **Elihe la imâhen ideâh**: Konhûtta la API ofiçiâh de Google (Chromium Dash) y çelehçiona la berçiôn mâh moderna y êttable pa tu arkîtêttûra.
3. ⬇️ **Dehkarga automátika**: Dehkarga la imâhen ofiçiâh de Google dirêttamente kon barra de progreço.
4. 🩹 **Aplika lô parcheh de kompatibilidá**: Îyêtta kargadorêh EFI retro, emulaçiôn TPM 2.0 po çoftware (`swtpm`), parcheh de GPU pa Freon/Mesa y audio ALSA UCM.
5. 💾 **Graba dirêtto en tu Pendraîh USB**: Flâhea er pendraîh çêttôh a çêttôh kon detêççiôn de çeguridá (protehiendo dîkkô îttênô y unidáêh der çîttema).

---

## ⚡ Pipeline Automatizado en 1 Clic

```text
  [ 1. Detección ] ──► [ 2. Selección ] ──► [ 3. Descarga ] ──► [ 4. Parcheo ] ──► [ 5. Grabación ]
   CPU / GPU / EFI      API Google CDN       Progreso en vivo     Legacy EFI/TPM      Pendrive USB listo
   (Intel/AMD/ia32)     (Última versión)     (dl.google.com)       (Freon / Mesa)      (Sector a sector)
```

---

## 🏛️ ChromeOS Âttualiçao en Ekîpô Antiguô

Muchos ordenadores fabricados entre 2011 y 2018 cuentan con firmware **EFI** pero quedan fuera de soporte por los siguientes motivos que **TapeOS resuelve**:

| Reto en Hardware Antiguo | Causa en ChromeOS Moderno | Solución TapeOS |
|---|---|---|
| **Pantaya en negro al iniçiâh** | Drîber de Mesa modernô (`iris`) îmkompatiblêh kon Intel HD 2000–4400. | Îyeççiôn de flag `INTEL_DEBUG=noccs`, forçao de drîber `crocus` y OpenGL fallback. |
| **PC kon GPU dediká (NVIDIA/AMD)** | Er êttâk gráfiko de ChromeOS no uça er drîber propietario de NVIDIA y puee kolgâhçe kon dGPU. | Ôççiôn `dgpu` automátika: NVIDIA çe çûppende y renderiça la iGPU; AMD renderiça kon er drîber abierto `amdgpu`. |
| **Errôh en iniçio de çeçiôn / Kuentâ** | ChromeOS êçîhe hardware TPM 2.0 îneççîtente en plakâ antiguâ. | Emulaçiôn en çegundo plano kon `swtpm` (TPM 2.0 bîttuâh) en er initramfs. |
| **Tableth Atom no arrankan (Bay/Cherry Trail)** | Firmware UEFI de 32 bit (`ia32`) en CPU de 64 bit (êh. Z3735F). | Inkluçiôn der bootloader duâh `bootia32.efi` y `bootx64.efi`. |
| **Lentitû u konhelamiento (2-4 GB RAM)** | Er çûçîttema ARCVM (Android en VM) debora la memoria RAM. | Açînaçiôn preferente de rekûperaçiôn ARC++ (`rammus`) y kompreçiôn `zram` ar 150%. |
| **Çîn audio en netbook êkonómikô** | Dippoçitivô kon kódek Intel SST u Realtek ES8316 / RT5640 çîn konfigurâh. | Mapâ de çonío ALSA UCM îyêttáô en er arrankê. |

---

## 🪟 Îttaladôh Întêratibo pa Windows

Er îttaladôh çe enkuentra en `installer/windows/` y puee ehekutâhçe mediante interfaç gráfika u konçola:

```text
installer/windows/
├── Run-Installer.cmd            # Lançadôh rápido kon elebaçiôn automátika de permiçô
├── TapeOS-Installer.ps1         # Interfaç Gráfika întêratiba kompleta (GUI Windows Forms)
├── TapeOS-CLI.ps1               # Açîtente întêratibo po konçola (TUI)
└── modules/
    ├── HardwareDetector.psm1    # Detêççiôn de CPU, GPU, UEFI x64 / ia32 y BitLocker
    ├── RecoveryDownloader.psm1  # Kliente Chromium Dash API y dehkargadôh ofiçiâh de Google
    ├── ImagePatcher.psm1        # Motôh de êttraççiôn y parcheo de imâhenêh ChromeOS
    ├── UsbFlasher.psm1          # Grabâh dirêtto a pendraîh USB kon proteççiôn de dîkkô
    ├── RecoveryCatalog.psm1     # Baçe de datô de kompatibilidá y perfîh de hardware
    ├── DiskManager.psm1         # Utiliáêh de dîkko y dehkompreçiôn
    └── BootManager.psm1         # Heneradôh de konfiguraçionêh de arrankê y GRUB
```

### Îttrûççionêh de uço rápido:
1. Konêtta un pendraîh USB de **ar menô 16 GB**.
2. Âtte doble klik en er ehekutable **`TapeOS-Installer.exe`** (dehkargao de la çeççiôn Releases) u, çi uçâ er ZIP, en **`installer\windows\Run-Installer.cmd`**.
3. Er îttaladôh detêttará tu PC (CPU, GPU, WiFi, Bluetooth, audio y tâttîh) y çelehçionará er rekûperaçiôn y lô parcheh de hardware adekuáô.
4. Elihe çi kierêh **Googlêh Play (Çtore + Android)** u **çîn Googlêh Play kon apph APK (Aurora Çtore)**.
5. Elihe er modo: **Live-USB** (grabâh en pendraîh) u **Îttaladôh** (kreâh er medio de îttalaçiôn `.img` çîn grabâh).
6. Âtte klik en **`⚡ Dehkargâh, Parcheâh y Kreâh (1-Klik)`**.
7. ¡Lîtta! Ar terminâh, reiníçia tu PC y arranka dêhde er pendraîh (têkla F12, F11 u Eç çegún tu plaka baçe).

---

## 📊 Matrî de Codenamê Ofiçiâlê Çoportáô

| Heneraçiôn de Proçeçadôh | Codename Ofiçiâh | Milestone Google | Kernel TapeOS | Tipo de Ekîpo |
|---|---|---|---|---|
| **Intel Core 14ª Hên / Ultra** | `brya` / `kanix` | **M156+** (Ûrtimo) | `kernel-6.6` | Moderno (Meteor Lake) |
| **Intel Core 11ª - 13ª Hên** | `volteer` / `voxel` | **M156+** (Ûrtimo) | `kernel-6.1` | Moderno (Tiger / Alder Lake) |
| **Intel Core 10ª Hên** | `hatch` / `jinlon` | **M156+** (Ûrtimo) | `kernel-6.1` | Moderno (Comet Lake) |
| **Intel Core 4ª - 9ª Hên** | `rammus` | **M149** (Êttable) | `kernel-5.10` | Legacy (Haswell a Coffee Lake) |
| **Intel Core 2ª - 3ª Hên** | `samus` / `rammus` | **M149** (Parxeao) | `kernel-legacy-5.4` | Retro (Sandy / Ivy Bridge) |
| **Intel Atom Bay / Cherry Trail** | `cyan` / `rammus` | **M149** (Parxeao) | `kernel-legacy-4.19` | Retro (UEFI 32-bit / Tableth) |
| **AMD Ryzen (Zen / Zen+ / Zen 2-4)**| `zork` / `gumboz` | **M156+** (Ûrtimo) | `kernel-6.1` | Moderno (Radeon Vega/RDNA) |
| **AMD Legacy APU (A4-A10 / Stoney)**| `grunt` | **M149** (Êttable) | `kernel-legacy-5.4` | Retro (Radeon kláçika) |

---

## 🛠️ Deçarroyo en er Repoçitorio

Çi bâ a trabahâh en êtte proyêtto kon **VS Code** u kualkiêh IDE:

- **Tareâ prekonfigurâh** en `.vscode/tasks.json`:
  - `Ctrl + Shift + P` -> **Tasks: Run Task** -> `TapeOS: Launch Windows Installer (GUI)` pa probâh la interfaç.
  - `TapeOS: Run Hardware Detection` pa berifikâh er diagnóttiko de tu mákina.
- **Fûentê âttream**: La karpeta de referençia ténnika lokâh (materiâh dehkargao de terçerô) êttá êkkluía der repoçitorio y no çe publika.
- **Framework**: er build der framework de arrankê (kernel + initramfs + ROOTC) êttá en `core/build/` (bé çu README).

---

## 🙏 Orígenêh y Kréditô

TapeOS naçe der proyêtto **[Brunch](https://github.com/sebanc/brunch)** de **Sébastien Ancora (Sebanc)**, a kién damô lô kréditô po çu trabaho pionero en yebâh ChromeOS a PC x86_64. Nûêttro framework uça çu arkîtêttûra de partiçionêh (ROOTC), er initramfs kon `swtpm` y çu êkkema de ôççionêh, âttualiá y êttendío.

**¿Po ké TapeOS?** "Tape" êh er lêkçema de *tapâh*, argo mu andalûh, y "OS" de *Operating System*: un guiño a ke Brunch era un tipo de komía y ahora êh Tapêh. La identidá andalûça êh parte der proyêtto.

**Difenrençiâ kon Brunch:**
- **Çoftware libre**: la berçiôn çîn Googlêh Play de TapeOS êh 100% libre; Brunch êttá enfokao a lâ imâhenêh kon Google.
- **Rebîtâliçaçiôn de hardware antiguo**: ênfaçî êppeçiâh en ekîpô legacy (UEFI 32-bit, GPU retro, çîn TPM) pa ke çigan çîrbiendo.
- **Lûtta kontra er dehperdiçio teknolóhiko**: kada ekîpo rehkâtao êh meno xatarra êlektrónika.

---

## ✅ TODO / Próççimô Paçô

- [ ] **Mâh identidá andalûça en er çîttema**: bandera, pîttâ y erramientâ de bîenbenía; çonidô, fondo de pantaya y tema andalûh en ChromeOS; çelebraçionêh (Día de Andalûçia, Feriâ) y guiñô a la kûttûra (tapâh, flamenko, kaí).
- [ ] **Dokumentaçiôn de âttualiçaçionêh**: añadîh un dokumento (`docs/UPDATES.md`) kon tô lâ poçibilidáêh de âttualiçaçiôn (kanal êttable/beta/dev, AUE, kernel legacy vs moderno, parcheh).
- [ ] **Eliminâh referençiâ a Google dentro der çîttema**: êppeçiâmente en la berçiôn çîn Googlêh Play (çerbiçiô, kuentâ, çînkronîçaçiôn, pantayâ y menúh), manteniendo çolo lo neçeçario pa er funçionamiento de ChromeOS.
- [ ] **Intentâh îttalâh en equipô no EFI con BIÔ lecâyy** creando una berçión "bintahe" que también permita âççedêh a úrtimâ berçionê der çîttema y a aplicaçionê de Androîh. 

---

## 📄 Liçençia

TapeOS çe dîttribuye baho la liçençia **GNU GPLv3**. Komponentêh deribáô de ChromiumOS u der kernel de Linux mantienen çû liçençiâ orihinâlêh rêppêttibâ (BSD / GPLv2).
