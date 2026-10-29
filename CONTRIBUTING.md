# Guía de Kontribuçiôn a TapeOS

¡Agradeçemô tu intêh en kolaborâh kon **TapeOS**! Er ôhhetibo êh kreâh la plataforma mâh uniberçâh, aççeçible y fâçîh de uçâh pa ehekutâh ChromeOS en kualkiêh ekîpo x86_64, dêhde dippoçitivô modernô de ûrtima heneraçiôn âtta ordenadorêh antiguô rehkâtáô der dehûço.

---

## 🛠️ ¿Kómo kontribuîh?

1. **Reportâh errôh u çoliçitâh hardware**:
   - Uça lô formulariô de [Issues en GitHub](../../issues).
   - Êppeçifika tu proçeçadôh, modelo de gráfika, tarheta de rê y modo de arrankê (UEFI / Legacy).
2. **Mehorâh er Îttaladôh de Windows**:
   - Lô módulô çe enkuentran en `installer/windows/modules/`.
   - Er kódiho êttá êttrûtturao pa çêh fâçîlmente êttençible: pueêh anyadîh çoporte pa nuebâ komprobaçionêh de dîkko, partiçionao u interfaçêh en WPF/WinUI.
3. **Parcheh de Kernel y Drîber**:
   - Anyade konfiguraçionêh y parcheh pa çoporte de hardware legacy en `core/patches/`.
4. **Dokumentaçiôn**:
   - Pueêh aportâh guíâ de pruebâ en modelô de portátilêh êppeçífikô u traduçîh dokumentaçiôn.

---

## 📜 Fluho de Trabaho Git

1. Âtte un Fork der repoçitorio.
2. Krea una rama dêkriptiba (`git checkout -b feature/çoporte-wifi-rtl8821ce`).
3. Realîça tû kambiô y âtte commit klârô.
4. Açegúrate de berifikâh la çîttâççî de lô êkrip (`shellcheck` en Linux / parçeo de PowerShell en Windows).
5. Abre un Pull Request dêkribiendo er impâtto y lô ekîpô probáô.
