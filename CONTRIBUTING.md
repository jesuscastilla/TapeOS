# Guía de Contribución a TapeOS

¡Agradecemos tu interés en colaborar con **TapeOS**! El objetivo es crear la plataforma más universal, accesible y fácil de usar para ejecutar ChromeOS en cualquier equipo x86_64, desde dispositivos modernos de última generación hasta ordenadores antiguos rescatados del desuso.

---

## 🛠️ ¿Cómo contribuir?

1. **Reportar errores o solicitar hardware**:
   - Usa los formularios de [Issues en GitHub](../../issues).
   - Especifica tu procesador, modelo de gráfica, tarjeta de red y modo de arranque (UEFI / Legacy).
2. **Mejorar el Instalador de Windows**:
   - Los módulos se encuentran en `installer/windows/modules/`.
   - El código está estructurado para ser fácilmente extensible: puedes añadir soporte para nuevas comprobaciones de disco, particionado o interfaces en WPF/WinUI.
3. **Parches de Kernel y Drivers**:
   - Añade configuraciones y parches para soporte de hardware legacy en `core/patches/`.
4. **Documentación**:
   - Puedes aportar guías de prueba en modelos de portátiles específicos o traducir documentación.

---

## 📜 Flujo de Trabajo Git

1. Haz un Fork del repositorio.
2. Crea una rama descriptiva (`git checkout -b feature/soporte-wifi-rtl8821ce`).
3. Realiza tus cambios y haz commits claros.
4. Asegúrate de verificar la sintaxis de los scripts (`shellcheck` en Linux / parseo de PowerShell en Windows).
5. Abre un Pull Request describiendo el impacto y los equipos probados.
