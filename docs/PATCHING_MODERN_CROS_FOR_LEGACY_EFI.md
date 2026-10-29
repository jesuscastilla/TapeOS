# Arkîtêttûra de Parcheh: ChromeOS Âttualiçao en Ekîpô EFI Antiguô — TapeOS

Êtte dokumento detaya la inheniería y lô mekanîmmô de parcheo ke utiliça **TapeOS** pa permetîh ke una **berçiôn moderna y âttualiçá de ChromeOS** (v120–v134+) funçione de forma fluía y êttable en **ordenadorêh antiguô kon firmware EFI**.

---

## 🎯 Er Problema kon ChromeOS Ofiçiâh en Hardware Antiguo

A medía ke Google âttualiça ChromeOS:
1. **Fîn de çoporte (AUE)**: Google retira de çoporte lô Chromebook antiguô baçáô en Intel Core de 2ª a 8ª heneraçiôn (Sandy Bridge, Ivy Bridge, Haswell, Broadwell, Skylake, Apollo Lake).
2. **Abandono de drîber gráfikô kláçikô**:
   - Er kompoçitôh de ChromeOS (**Freon**) rekiere açînaçiôn de bûffer mediante `minigbm` y çoporte DRM/KMS moderno.
   - Lâ berçionêh reçientêh de Mesa abandonaron lô kontroladorêh kláçikô `i915` e `i965`, forçando er nuebo kontroladôh `crocus` ke puee fallâh u probokâh kuelgêh en gráfikâ Intel HD 2000 / 3000 / 4000 / 4400 çi çe çoliçitan kapâçidáêh no çoportâh (Vulkan, modifikadorêh DRM abançáô, kompreçiôn de kolôh CCS).
3. **Konçumo de memoria de Android (ARCVM)**:
   - Lâ kompilaçionêh modernâ çûttituyeron lô kontenedorêh liherô de Android 9/11 (`ARC++`) po mákinâ bîttuâlêh kompleâ (`ARCVM`). En PC kon 2 GB u 4 GB de RAM, êtto agota la memoria fíçika y konhela er çîttema.
4. **Rekîçitô de çeguridá y TPM**:
   - Modern ChromeOS êçîhe hardware TPM 2.0 pa er çifrao de datô de uçuario (*cryptohome*). Lâ plakâ baçe EFI antiguâ kareçen de TPM u çolo kuentan kon TPM 1.2 ôççoleto.
5. **Firmware UEFI de 32 bit en proçeçadorêh de 64 bit (`ia32`)**:
   - Mu êttendío en tableth y netbook Intel Atom (Bay Trail Z3735F, Cherry Trail x5-Z8350, Celeron N2800). Lô kargadorêh êttándâh de 64 bit (`bootx64.efi`) çon îbbiçiblêh pa êtte firmware.

---

## 🧩 La Çoluçiôn TapeOS: Er Motôh de Parcheh en 5 Kapâ

TapeOS no utiliça una berçiôn bieha de ChromeOS dehâttualiçá; en çu lugâh, **toma la ûrtima berçiôn ofiçiâh de ChromeOS y la parchea en kâliente durante er arrankê** mediante çu partiçiôn `ROOTC` y çu `initramfs` întelihente.

```text
┌────────────────────────────────────────────────────────────────────────┐
│            1. ARRANKE EFI ÍBRIO (UEFI x64 / UEFI ia32)                │
│ • Detêtta la arkîtêttûra der firmware EFI.                            │
│ • Karga bootx64.efi u bootia32.efi kon çoporte pa EFI stub mîttto.    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     2. KERNEL MULTI-PERFÎH TAPEOS                      │
│ • Parcheao kon kompatibilidá pa GPU retro (Intel i915 / AMD).          │
│ • Flag cmdline automátikâ: i915.enable_guc=0, i915.enable_psr=0,       │
│   cros_legacy, efi=noruntime (çi çe detêtta firmware EFI bugueao).     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                 3. INITRAMFS & EMULAÇIÔN DE ÇEGURIDÁ                  │
│ • Arranka swtpm (TPM 2.0 emulao po çoftware) antê de cryptohomed.     │
│ • Permite iniçiâh çeçiôn kon kuenta de Google y çifrao kompleto.       │
│ • Aplika parcheh ar RootFS ofiçiâh de ChromeOS mediante overlayfs.     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│               4. ADAPTAÔH DE GRÁFIKÔ PA FREON / MESA                   │
│ • Îtterçêtta yamâh de minigbm pa Intel Hên 2 a 7.5.                    │
│ • Redirihe a Mesa crocus ôttimiçao (INTEL_DEBUG=noccs) u fallback      │
│   çoftware rahteriçer (llvmpipe) ebitando la pantaya en negro.         │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│             5. HÊTTIÔN EFIÇIENTE DE REKÛRÇÔ & PLAY ÇTORE              │
│ • Pa CPU antiguâ: açînaçiôn preferente de rekûperaçiôn ARC++ (rammus)  │
│ • Konfiguraçiôn agreçiba de zram (150% de RAM) y swappine pa           │
│   mantenêh la fluîêh en ekîpô kon 2 GB / 4 GB de RAM.                  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Parcheh Êppeçífikô Integráô en TapeOS

### 1. Parche Gráfiko pa Freon (Intel HD 2000 / 3000 / 4000 / 5000)
- **Fíxero**: `core/patches/10-legacy_gpu_freon.sh`
- **Funçiôn**:
  - Îyêtta bariablêh de entorno en `/etc/env.d/` pa la çeçiôn de ChromeOS:
    - `INTEL_DEBUG=noccs,norbc`: Dehattiba argorîmmô de kompreçiôn de framebuffer no çoportáô po hardware anteriôh a Skylake.
    - `MESA_LOADER_DRIVER_OVERRIDE=crocus`: Garantiça ke Mesa utiliçe er drîber moderno ôttimiçao pa Haswell/Ivy Bridge en bêh de kolapçâh.
    - `CHROME_EXTRA_FLAGS="--disable-features=Vulkan,VulkanFromANGLE --ignore-gpu-blocklist --enable-gpu-rasterization"`: Obliga a Chromium a utiliçâh er backend OpenGL ES çîn intentâh iniçialiçâh Vulkan en tarhetâ ke no lo çoportan.

### 2. Parche de Emulaçiôn TPM 2.0 (`swtpm`)
- **Fíxero**: `core/patches/20-swtpm_legacy_tpm.sh`
- **Funçiôn**:
  - Henera un dippoçitibo de karâtterêh `/dev/tpm0` bîttualiçao mediante `swtpm` y `swtpm_bios`.
  - Permite a `cryptohomed` y `chapsd` iniçialiçâh er âhmaçên çeguro de yabê çîn êçihîh un módulo TPM 2.0 fíçiko en la plaka baçe.

### 3. Parche de Audio ALSA UCM pa Xî Êkonómikô
- **Fíxero**: `core/patches/30-legacy_audio_ucm.sh`
- **Funçiôn**:
  - Karga lô mapâ de çonío UCM pa proçeçadorêh Intel Atom (Bay Trail RT5640, Cherry Trail ES8316, Braswell NAU88L25).
  - Korrihe er problema kláçiko de ChromeOS en portátilêh xinô u konbertiblêh donde no ây audio ni mikrófono.

### 4. Parche de Firmware EFI de 32 bit (ia32)
- **Fíxero**: `core/patches/15-efi_ia32_runtime.sh`
- **Funçiôn**:
  - Henera entrâh de arrankê kompatiblêh kon proçeçadorêh x86_64 ehekutando firmware EFI de 32 bit.
  - Paça er parámetro `efi=noruntime` ar kernel kuando çe detêtta ke lâ yamâh a lô çerbiçiô en tiempo de ehekuçiôn de la BIOS probokan *Kernel Panic* en tableth antiguâ.
