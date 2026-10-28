# Matriz de Compatibilidad de Hardware (Legacy & Moderno) — TapeOS

TapeOS está diseñado específicamente para rescatar y revitalizar equipos antiguos (*legacy*), a la vez que ofrece soporte de vanguardia para arquitecturas modernas.

---

## 📊 Tabla General de Compatibilidad

| Generación / Familia de CPU | Recuperación Recomendada | Kernel Recomendado | Subsistema Android | Notas de Compatibilidad |
|---|---|---|---|---|
| **Intel 14ª Gen / Core Ultra** | `kanix` | `kernel-6.6` | ARCVM (Android 13/14) | Requiere UEFI x64. Gráficos Intel Arc soportados. |
| **Intel 11ª - 13ª Gen** | `voxel` | `kernel-6.1` | ARCVM (Android 11) | Gráficos Iris Xe nativos. Soporte completo. |
| **Intel 10ª Gen** | `jinlon` | `kernel-6.1` | ARCVM (Android 11) | Comet Lake / Ice Lake. Gran estabilidad. |
| **Intel 8ª - 9ª Gen** | `rammus` | `kernel-5.15` / `5.10` | ARC++ / ARCVM | Soporte completo para laptops y sobremesas. |
| **Intel 4ª - 7ª Gen** (Haswell, Skylake, Kaby Lake) | `rammus` | `kernel-5.10` | ARC++ (Android 9 Pie) | Excelente rendimiento y bajo consumo. |
| **Intel 2ª - 3ª Gen** (Sandy Bridge, Ivy Bridge) | `samus` / `rammus` | `kernel-legacy-5.4` | ARC++ | Activar parámetro `i915.modeset=1`. Rendimiento fluido. |
| **Intel Atom Bay Trail / Cherry Trail** | `cyan` | `kernel-legacy-4.19` | ARC++ | **Soporta UEFI de 32 bits (`ia32`)**. Ideal para tablets 2 en 1 (ej. Asus Transformer T100). |
| **AMD Ryzen (Zen / Zen+ / Zen 2/3/4)** | `gumboz` | `kernel-6.1` | ARCVM (Android 11/13) | Gráficos Radeon Vega y RDNA con aceleración Mesa. |
| **AMD Legacy APUs** (A4/A6/A8/A10, Stoney Ridge) | `grunt` | `kernel-legacy-5.4` | ARC++ | Activar parámetro `radeon.modeset=1`. |
| **Equipos BIOS Legacy / MBR** (Sin UEFI) | `rammus` / `samus` | `kernel-legacy-5.10` / `5.4` | ARC++ | Arranca vía cargador de arranque MBR híbrido. |

---

## 🕹️ Soporte Gráfico Legacy

- **Intel HD Graphics 2000 / 3000 / 4000**:
  - Habilitado mediante parches de kernel con retrocompatibilidad para `i915`.
  - Desactivación de extensiones Vulkan modernas para forzar backend OpenGL ES 3.0 estable en ChromeOS.
- **AMD Radeon TeraScale / GCN 1.0**:
  - Uso del módulo `radeon` clásico con firmware redistribuido integrado.
- **Gráficos Híbridos (Nvidia Optimus)**:
  - TapeOS prioriza automáticamente la tarjeta integrada para la interfaz de ChromeOS, evitando pantallas en negro al suspender o reanudar.

---

## 📶 Conectividad y Audio en Dispositivos Antiguos

- **Wi-Fi Broadcom**: Inclusión de módulos compilados para `bcmwl` y `brcmfmac` (BCM4313, BCM43142, BCM43228).
- **Wi-Fi Realtek**: Controladores incluidos para chipsets USB y PCI-E conflictivos (`rtl8723de`, `rtl8821ce`, `rtl8188eu`).
- **Audio Intel SST**: Perfiles de ALSA UCM específicos para dispositivos Atom Z3735F / Braswell.
