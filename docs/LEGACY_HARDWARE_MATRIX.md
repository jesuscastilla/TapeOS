# Matrî de Kompatibilidá de Hardware (Legacy & Moderno) — TapeOS

TapeOS êttá diçeñao êppeçífikamente pa rehkâtâh y rebitâliçâh ekîpô antiguô (*legacy*), a la bêh ke ofreçe çoporte de banguardia pa arkîtêttûrâ modernâ.

---

## 📊 Tabla Henerâh de Kompatibilidá

| Heneraçiôn / Família de CPU | Rekûperaçiôn Rekomendá | Kernel Rekomendao | Çûçîttema Android | Notâ de Kompatibilidá |
|---|---|---|---|---|
| **Intel 14ª Hên / Core Ultra** | `kanix` | `kernel-6.6` | ARCVM (Android 13/14) | Rekiere UEFI x64. Gráfikô Intel Arc çoportáô. |
| **Intel 11ª - 13ª Hên** | `voxel` | `kernel-6.1` | ARCVM (Android 11) | Gráfikô Iris Xe natibô. Çoporte kompleto. |
| **Intel 10ª Hên** | `jinlon` | `kernel-6.1` | ARCVM (Android 11) | Comet Lake / Ice Lake. Gran êttabilidá. |
| **Intel 8ª - 9ª Hên** | `rammus` | `kernel-5.15` / `5.10` | ARC++ / ARCVM | Çoporte kompleto pa portátilêh y çobremeçâh. |
| **Intel 4ª - 7ª Hên** (Haswell, Skylake, Kaby Lake) | `rammus` | `kernel-5.10` | ARC++ (Android 9 Pie) | Êhçelente rendimiento y baho konçumo. |
| **Intel 2ª - 3ª Hên** (Sandy Bridge, Ivy Bridge) | `samus` / `rammus` | `kernel-legacy-5.4` | ARC++ | Attibâh er parámetro `i915.modeset=1`. Rendimiento fluío. |
| **Intel Atom Bay Trail / Cherry Trail** | `cyan` | `kernel-legacy-4.19` | ARC++ | **Çoporta UEFI de 32 bit (`ia32`)**. Ideâh pa tableth 2 en 1 (êh. Asus Transformer T100). |
| **AMD Ryzen (Zen / Zen+ / Zen 2/3/4)** | `gumboz` | `kernel-6.1` | ARCVM (Android 11/13) | Gráfikô Radeon Vega y RDNA kon açeleraçiôn Mesa. |
| **AMD Legacy APU** (A4/A6/A8/A10, Stoney Ridge) | `grunt` | `kernel-legacy-5.4` | ARC++ | Attibâh er parámetro `radeon.modeset=1`. |
| **Ekîpô BIOS Legacy / MBR** (Çîn UEFI) | `rammus` / `samus` | `kernel-legacy-5.10` / `5.4` | ARC++ | Arranka bía kargadôh de arrankê MBR íbrio. |

---

## 🕹️ Çoporte Gráfiko Legacy

- **Intel HD Graphics 2000 / 3000 / 4000**:
  - Abilitao mediante parcheh de kernel kon retrokompatibilidá pa `i915`.
  - Dehattibaçiôn de êttençionêh Vulkan modernâ pa forçâh er backend OpenGL ES 3.0 êttable en ChromeOS.
- **AMD Radeon TeraScale / GCN 1.0**:
  - Uço der módulo `radeon` kláçiko kon firmware redîttribuío integrao.
- **Gráfikô Íbriô (Nvidia Optimus)**:
  - TapeOS prioriça automátikamente la tarheta integra pa la interfaç de ChromeOS, ebitando pantayâ en negro al çûppendêh u reanudâh.

---

## 📶 Konektibilidá y Audio en Dippoçitivô Antiguô

- **Wi-Fi Broadcom**: Inkluçiôn de módulô kompiláô pa `bcmwl` y `brcmfmac` (BCM4313, BCM43142, BCM43228).
- **Wi-Fi Realtek**: Kontroladorêh inkluíô pa çîppê USB y PCI-E konflîttibô (`rtl8723de`, `rtl8821ce`, `rtl8188eu`).
- **Audio Intel SST**: Perfilêh de ALSA UCM êppeçífikô pa dippoçitivô Atom Z3735F / Braswell.
