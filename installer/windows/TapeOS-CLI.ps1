<#
.SYNOPSIS
    TapeOS Interactive Command Line Wizard (TUI)
.DESCRIPTION
    Asistente por consola para Windows: Detección -> Descarga de Recovery -> Parcheo -> Grabación en USB.
#>

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"") -Verb RunAs
    exit
}

$moduleDir = Join-Path $PSScriptRoot "modules"
Import-Module (Join-Path $moduleDir "HardwareDetector.psm1") -Force
Import-Module (Join-Path $moduleDir "RecoveryCatalog.psm1") -Force
Import-Module (Join-Path $moduleDir "RecoveryDownloader.psm1") -Force
Import-Module (Join-Path $moduleDir "ImagePatcher.psm1") -Force
Import-Module (Join-Path $moduleDir "UsbFlasher.psm1") -Force
Import-Module (Join-Path $moduleDir "DiskManager.psm1") -Force

Clear-Host
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "       TapeOS End-to-End Automated ChromeOS USB Creator           " -ForegroundColor White
Write-Host "   Detecta -> Descarga Oficial -> Parchea Legacy -> Graba en USB  " -ForegroundColor Gray
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Detección
Write-Host "[1/4] Analizando hardware del equipo..." -ForegroundColor Yellow
$hw = Get-TapeOSHardwareReport
$rec = $hw.Recommendations

Write-Host "  • CPU:        $($hw.CPU.Name)" -ForegroundColor Green
Write-Host "  • Firmware:   $($hw.Firmware.Type)" -ForegroundColor Green
Write-Host "  • GPU:        $(($hw.GPU | ForEach-Object { "$($_.Name) $(if ($_.VendorId -eq '10DE') { '(NVIDIA)' } elseif ($_.VendorId -eq '1002') { '(AMD)' } elseif ($_.VendorId -eq '8086') { '(Intel)' } else { '' })" }) -join ', ')" -ForegroundColor Green
Write-Host "  • WiFi:       $(if ($hw.Network.WiFi.Count -gt 0) { (($hw.Network.WiFi | ForEach-Object { $_.Name }) -join ', ') } else { 'No detectado' })" -ForegroundColor Green
Write-Host "  • Bluetooth:  $(if ($hw.Network.Bluetooth.Count -gt 0) { (($hw.Network.Bluetooth | ForEach-Object { $_.Name }) -join ', ') } else { 'No detectado' })" -ForegroundColor Green
$hwPatchesStr = (($hw.FrameworkPatches | ForEach-Object { $_.Option }) -join ', ')
if ($hwPatchesStr) { Write-Host "  • Parches hardware detectados: $hwPatchesStr" -ForegroundColor Magenta }
Write-Host "  • Sugerido:   Recovery [$($rec.RecoveryCodename.ToUpper())] con Kernel [$($rec.Kernel)]" -ForegroundColor Magenta
Write-Host ""

# 2. Consulta y Descarga
Write-Host "[2/4] Consultando última versión oficial en Google Chromium Dash..." -ForegroundColor Yellow
$recoveryInfo = Get-TapeOSLatestRecoveryInfo -BoardCodename $rec.RecoveryCodename
Write-Host "  • Board:      $($recoveryInfo.Board)" -ForegroundColor Cyan
Write-Host "  • Versión:    Milestone $($recoveryInfo.Milestone) (Última versión oficial estable)" -ForegroundColor Cyan
Write-Host "  • Archivo:    $($recoveryInfo.FileName)" -ForegroundColor Gray
Write-Host ""

# 3. Destino de instalación
Write-Host ""
Write-Host "[3/4] Destino de instalación" -ForegroundColor Yellow
Write-Host "  [1] Grabar directamente en un pendrive USB"
Write-Host "  [2] Solo crear archivo de imagen (.img) — sin grabar en ningún pendrive"
$destChoice = Read-Host "Elige destino (1/2)"
if ($destChoice -ne '1' -and $destChoice -ne '2') { $destChoice = '1' }

$targetUsb = $null
$imageDestDir = $null

if ($destChoice -eq '1') {
    Write-Host ""
    Write-Host "[3/4] Detectando pendrives USB conectados..." -ForegroundColor Yellow
    $usbDrives = Get-TapeOSUsbDrives
    if ($usbDrives.Count -eq 0) {
        Write-Warning "No se detectó ningún pendrive USB. Por favor conecta uno y reinicia este asistente."
        pause
        exit
    }

    for ($i = 0; $i -lt $usbDrives.Count; $i++) {
        Write-Host "  [$i] $($usbDrives[$i].DisplayName)" -ForegroundColor White
    }

    $choice = Read-Host "Selecciona el pendrive destino [0-$($usbDrives.Count - 1)]"
    $targetUsb = $usbDrives[[int]$choice]

    Write-Host ""
    Write-Host "⚠️ ATENCIÓN: El pendrive $($targetUsb.DisplayName) SERÁ BORRADO POR COMPLETO." -ForegroundColor Red
    $confirm = Read-Host "¿Confirmas que deseas descargar, parchear y grabar TapeOS en este USB? (s/N)"
    if ($confirm -ne 's' -and $confirm -ne 'S' -and $confirm -ne 'si' -and $confirm -ne 'yes') {
        Write-Host "Operación cancelada." -ForegroundColor Gray
        exit
    }
} else {
    Write-Host ""
    Write-Host "[3/4] Modo solo imagen: no se grabará en ningún pendrive." -ForegroundColor Cyan
    $imageDestDir = Read-Host "Carpeta donde guardar el archivo .img [C:\TapeOS\images]"
    if (-not $imageDestDir.Trim()) { $imageDestDir = "C:\TapeOS\images" }
    $confirm = Read-Host "¿Confirmas que deseas descargar y parchear la imagen? (s/N)"
    if ($confirm -ne 's' -and $confirm -ne 'S' -and $confirm -ne 'si' -and $confirm -ne 'yes') {
        Write-Host "Operación cancelada." -ForegroundColor Gray
        exit
    }
}

# 3b. Modo Google Apps (Play Store)
Write-Host ""
Write-Host "[3b/4] Modo Google Apps" -ForegroundColor Yellow
Write-Host "  • SÍ (recomendado): ChromeOS con Play Store y aplicaciones Android."
Write-Host "  • NO: ChromeOS ligero sin Google Apps (solo navegador y aplicaciones web)."
$gaChoice = Read-Host "¿Instalar Google Apps (Play Store)? (S/n)"
$enableGoogleApps = -not ($gaChoice -match '^[nN]')

# 4. Pipeline Completo
Write-Host ""
Write-Host "[Paso A] Descargando imagen oficial..." -ForegroundColor Cyan
$downloadDir = "C:\TapeOS\downloads"
$zipPath = Join-Path $downloadDir $recoveryInfo.FileName
Start-TapeOSDownload -Url $recoveryInfo.Url -DestinationFile $zipPath | Out-Null

Write-Host ""
Write-Host "[Paso B] Descomprimiendo y aplicando parches TapeOS (Legacy EFI + swtpm + GPU; Google Apps: $(if ($enableGoogleApps) { 'SÍ' } else { 'NO' }))..." -ForegroundColor Cyan
$patched = Invoke-TapeOSImagePatch `
    -RecoveryZipPath $zipPath `
    -OutputDir "C:\TapeOS\patched" `
    -EnableIA32 ($hw.Firmware.IsIA32UEFI) `
    -EnableLegacyGPU $true `
    -EnableSwtpm $true `
    -EnableGoogleApps $enableGoogleApps `
    -AdditionalFrameworkOptions @($hw.FrameworkPatches | ForEach-Object { $_.Option })

if ($destChoice -eq '1') {
    Write-Host ""
    Write-Host "[Paso C] Grabando en pendrive USB $($targetUsb.DeviceID)..." -ForegroundColor Cyan
    Start-TapeOSUsbFlash -ImageFilePath $patched.PatchedImagePath -PhysicalDriveId $targetUsb.DeviceID -ProgressCallback {
        param($pct, $speedMBs, $written, $total)
        Write-Progress -Activity "Grabando TapeOS en pendrive USB ($speedMBs MB/s)" -Status "$pct% completado" -PercentComplete $pct
    }

    Write-Progress -Activity "Grabando TapeOS en pendrive USB" -Completed
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Green
    Write-Host "   ¡PROCESO COMPLETADO! Tu pendrive TapeOS está listo para arrancar " -ForegroundColor White
    Write-Host "==================================================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[Paso C] Guardando imagen parcheada como archivo .img (sin grabar)..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $imageDestDir -Force | Out-Null
    $imgName = "TapeOS-$($recoveryInfo.Board)-M$($recoveryInfo.Milestone)-$(if ($enableGoogleApps) { 'googleapps' } else { 'lite' }).img"
    $imgPath = Join-Path $imageDestDir $imgName
    Copy-Item -Path $patched.PatchedImagePath -Destination $imgPath -Force
    if (Test-Path $patched.ConfigFile) { Copy-Item -Path $patched.ConfigFile -Destination (Join-Path $imageDestDir "grub.cfg") -Force }
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Green
    Write-Host "   ¡IMAGEN CREADA! Ruta: $imgPath" -ForegroundColor White
    Write-Host "   Grábala cuando quieras con Rufus, Win32DiskImager o con TapeOS" -ForegroundColor Gray
    Write-Host "   (modo USB). Incluye grub.cfg de arranque en la misma carpeta." -ForegroundColor Gray
    Write-Host "==================================================================" -ForegroundColor Green
}

Write-Host "Presiona cualquier tecla para salir..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
