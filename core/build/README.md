# Konttruççiôn der Framework TapeOS — `core/build/`

Êtte direttorio kontiene er **konttrûttôh der framework de arrankê** de TapeOS:
er konhunto de kernêh, initramfs, partiçiôn ROOTC y yabê de firma ke çe
**înyêtta dentro de la imâhen de ChromeOS** pa ke arranke en kualkiêh PC.

> Êttao: **andamiahe kompleto lîtta** (êkrip reâlêh + dokumentaçiôn). La
> kompilaçiôn çe ehekutará en la próççima çeçiôn de trabaho.

---

## Ké konttruye

| Komponente | Êkrip / direttorio | Dêkripçiôn |
|---|---|---|
| Initramfs | `core/initramfs/init` | Init ke arranka `swtpm`, monta ROOT-A y aplika `core/patches/*` |
| Kernêh | `kernels/<berçiôn>/` | Fûente Linux ChromiumOS (6.6/6.1/5.15/5.10/5.4/4.19) |
| ROOTC | `out/framework/rootc.squashfs` | Partiçiôn de 1 GB kon kernel firmado + initramfs |
| Yabê | `out/framework/keys/` | Yabê vboot propiâ (firma der kernel) |
| Pakete | `out/framework/tapeos_framework_*.tar.gz` | Too hunto pa înyêttâl-lo |

## Rekîçitô (Debian/Ubuntu, çolo pa konttruîh — er uçuario finâh no lo neçeçita)

```bash
sudo apt install build-essential cpio squashfs-tools grub-efi-amd64-bin \
                 vboot-utils libssl-dev bc flex bison dwarves git
```

## Kompilâh

```bash
sudo bash core/build/build-framework.sh --kernel 6.1 --version 0.1.0
```

Ôççionêh: `--kernel` (6.6|6.1|5.15|5.10|5.4|4.19), `--version`, `--clean`.

## Înyêttâh er framework (próççima çeçiôn)

Kon er pakete henerao, `core/scripts/tapeos-install.sh` çe enkargará de:
1. Anyadîh la partiçiôn **ROOTC** (1 GB) a la imâhen de rekûperaçiôn.
2. Êkkribîh lô kernel blob firmáô en KERN-A/KERN-B y er initramfs en ROOTC.
3. Îttalâh la kadena de arrankê TapeOS (GRUB) en EFI-SYSTEM kon lâ ôççionêh
   detêttâh po er îttaladôh Windows (`options=...`).

Êttô paçô çe ehekutan en Linux (WSL2 u VM çîrbe) y deharán la imâhen lîtta
pa grabarhla çêttôh a çêttôh dêhde er îttaladôh Windows, ke yá çabe grabâh.
