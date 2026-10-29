# TapeOS - Prueba de humo del wizard (PS 5.1)
# Ejecuta el wizard completo con ShowDialog sustituido por Show() + validación
# de límites del área cliente + captura PNG en dist\gui-snapshot.png y cierre.
# Una trampa global captura cualquier excepción de arranque y la guarda en
# C:\ProgramData\TapeOS\wizard-trap.log con la pila completa.
# El veredicto de layout queda en C:\ProgramData\TapeOS\wizard-layout-check.log.
# Uso: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\wizard-smoke-test.ps1
$ErrorActionPreference = 'Stop'

$adminOk = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $adminOk) {
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"") -Verb RunAs -Wait
    exit
}

trap {
    Set-Content -Path "$env:ProgramData\TapeOS\wizard-trap.log" -Encoding UTF8 -Force -Value @"
TIME: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
EXC: $($_.Exception.ToString())
INNER: $(if ($_.Exception.InnerException) { $_.Exception.InnerException.ToString() } else { '(none)' })
STACK: $($_.ScriptStackTrace)
"@
    Remove-Item -LiteralPath 'G:\TapeOS\installer\windows\tmp-wizard-harness-run.ps1' -Force -ErrorAction SilentlyContinue
    break
}

$wiz = Get-Content 'G:\TapeOS\installer\windows\TapeOS-Installer.ps1'
$probe = @'
$null = $form.Show()
$form.Refresh()
Start-Sleep -Milliseconds 1500
try {
    $cw = $form.ClientSize.Width
    $ch = $form.ClientSize.Height
    $desb = @()
    foreach ($c in $form.Controls) {
        if (($c.Left + $c.Width) -gt $cw -or ($c.Top + $c.Height) -gt $ch) {
            $desb += ("{0}: Left={1} Top={2} Right={3} Bottom={4}" -f $c.Name, $c.Left, $c.Top, ($c.Left + $c.Width), ($c.Top + $c.Height))
        }
    }
    $veredicto = if ($desb.Count -eq 0) { 'OK' } else { 'OVERFLOW' }
    $lineas = @("TIME: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')", ("CLIENT: " + $cw + "x" + $ch), ("VERDICT: " + $veredicto))
    $lineas += $desb
    Set-Content -Path "$env:ProgramData\TapeOS\wizard-layout-check.log" -Encoding UTF8 -Force -Value $lineas
    $snapDir = 'G:\TapeOS\dist'
    if (-not (Test-Path -LiteralPath $snapDir)) { New-Item -ItemType Directory -Path $snapDir -Force | Out-Null }
    try {
        $bmp = New-Object System.Drawing.Bitmap($cw, $ch)
        $rect = New-Object System.Drawing.Rectangle(0, 0, $cw, $ch)
        $form.DrawToBitmap($bmp, $rect)
        $bmp.Save((Join-Path $snapDir 'gui-snapshot.png'), [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
    } catch {
        $lineas += ("SNAPSHOT-FALLIDO: " + $_.Exception.Message)
        Set-Content -Path "$env:ProgramData\TapeOS\wizard-layout-check.log" -Encoding UTF8 -Force -Value $lineas
    }
} catch {
    Set-Content -Path "$env:ProgramData\TapeOS\wizard-layout-check.log" -Encoding UTF8 -Force -Value @("TIME: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')", ("EXC: " + $_.Exception.ToString()))
}
Start-Sleep -Seconds 1
$form.Close()
'@
$modifiedText = ($wiz -join "`r`n").Replace('[void]$form.ShowDialog()', $probe)
$tmp = 'G:\TapeOS\installer\windows\tmp-wizard-harness-run.ps1'
Set-Content -Path $tmp -Value $modifiedText -Encoding UTF8
& $tmp
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
'trap-log existe: ' + (Test-Path "$env:ProgramData\TapeOS\wizard-trap.log")
if (Test-Path "$env:ProgramData\TapeOS\wizard-trap.log") { Get-Content "$env:ProgramData\TapeOS\wizard-trap.log" -Encoding UTF8 }
'layout-log existe: ' + (Test-Path "$env:ProgramData\TapeOS\wizard-layout-check.log")
if (Test-Path "$env:ProgramData\TapeOS\wizard-layout-check.log") { Get-Content "$env:ProgramData\TapeOS\wizard-layout-check.log" -Encoding UTF8 }
'snapshot existe: ' + (Test-Path 'G:\TapeOS\dist\gui-snapshot.png')
