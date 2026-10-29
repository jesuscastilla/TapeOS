# TapeOS - Prueba de humo del wizard (PS 5.1)
# Ejecuta el wizard completo con ShowDialog sustituido por Show() + cierre a los 4 s.
# Una trampa global captura cualquier excepción de arranque y la guarda en
# C:\ProgramData\TapeOS\wizard-trap.log con la pila completa.
# Uso: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\wizard-smoke-test.ps1
$ErrorActionPreference = 'Stop'
trap {
    Set-Content -Path "$env:ProgramData\TapeOS\wizard-trap.log" -Encoding UTF8 -Force -Value @"
TIME: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
EXC: $($_.Exception.ToString())
INNER: $(if ($_.Exception.InnerException) { $_.Exception.InnerException.ToString() } else { '(none)' })
STACK: $($_.ScriptStackTrace)
"@
    break
}

$wiz = Get-Content 'G:\TapeOS\installer\windows\TapeOS-Installer.ps1'
$modified = $wiz -replace [regex]::Escape('[void]$form.ShowDialog()'), '$null = $form.Show(); Start-Sleep -Seconds 4; $form.Close()'
$tmp = 'G:\TapeOS\installer\windows\tmp-wizard-harness-run.ps1'
$modified | Set-Content -Path $tmp -Encoding UTF8
& $tmp
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
'trap-log existe: ' + (Test-Path "$env:ProgramData\TapeOS\wizard-trap.log")
if (Test-Path "$env:ProgramData\TapeOS\wizard-trap.log") { Get-Content "$env:ProgramData\TapeOS\wizard-trap.log" -Encoding UTF8 }
