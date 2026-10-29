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
Write-Host "   Detêtta -> Dehkarga Ofiçiâh -> Parchea Legacy -> Graba en USB   " -ForegroundColor Gray
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Deteççiôn
Write-Host "[1/4] Analiçando er hardware der ekîpo..." -ForegroundColor Yellow
$hw = Get-TapeOSHardwareReport
$rec = $hw.Recommendations

Write-Host "  • CPU:        $($hw.CPU.Name)" -ForegroundColor Green
Write-Host "  • Firmware:   $($hw.Firmware.Type)" -ForegroundColor Green
Write-Host "  • GPU:        $(($hw.GPU | ForEach-Object { "$($_.Name) $(if ($_.VendorId -eq '10DE') { '(NVIDIA)' } elseif ($_.VendorId -eq '1002') { '(AMD)' } elseif ($_.VendorId -eq '8086') { '(Intel)' } else { '' })" }) -join ', ')" -ForegroundColor Green
Write-Host "  • WiFi:       $(if ($hw.Network.WiFi.Count -gt 0) { (($hw.Network.WiFi | ForEach-Object { $_.Name }) -join ', ') } else { 'No detêttao' })" -ForegroundColor Green
Write-Host "  • Bluetooth:  $(if ($hw.Network.Bluetooth.Count -gt 0) { (($hw.Network.Bluetooth | ForEach-Object { $_.Name }) -join ', ') } else { 'No detêttao' })" -ForegroundColor Green
$hwPatchesStr = (($hw.FrameworkPatches | ForEach-Object { $_.Option }) -join ', ')
if ($hwPatchesStr) { Write-Host "  • Parcheh de hardware detêttáô: $hwPatchesStr" -ForegroundColor Magenta }
Write-Host "  • Çuherío:    Rekûperaçiôn [$($rec.RecoveryCodename.ToUpper())] kon Kernel [$($rec.Kernel)]" -ForegroundColor Magenta
Write-Host ""

# 2. Konhûtta y Dehkarga
Write-Host "[2/4] Konhûttando la ûrtima berçiôn ofiçiâh en Google Chromium Dash..." -ForegroundColor Yellow
$recoveryInfo = Get-TapeOSLatestRecoveryInfo -BoardCodename $rec.RecoveryCodename
Write-Host "  • Board:      $($recoveryInfo.Board)" -ForegroundColor Cyan
Write-Host "  • Berçiôn:    Milestone $($recoveryInfo.Milestone) (Ûrtima berçiôn ofiçiâh êttable)" -ForegroundColor Cyan
Write-Host "  • Arxibo:     $($recoveryInfo.FileName)" -ForegroundColor Gray
Write-Host ""

# 3. Dêttino de îttalaçiôn
Write-Host ""
Write-Host "[3/4] Dêttino de îttalaçiôn" -ForegroundColor Yellow
Write-Host "  [1] Live-USB: grabâh en un pendraîh USB y arrankâh dêhde él"
Write-Host "  [2] Îttaladôh: kreâh er medio de îttalaçiôn (.img) çîn grabâh"
$destChoice = Read-Host "Elihe er dêttino (1/2)"
if ($destChoice -ne '1' -and $destChoice -ne '2') { $destChoice = '1' }

$targetUsb = $null
$imageDestDir = $null

if ($destChoice -eq '1') {
    Write-Host ""
    Write-Host "[3/4] Detêttando lô pendraîh USB konêttáô..." -ForegroundColor Yellow
    $usbDrives = Get-TapeOSUsbDrives
    if ($usbDrives.Count -eq 0) {
        Write-Warning "No çe detêttó nîn pun pendraîh USB. Po fabor, konêtta uno y reiníçia êtte açîtente."
        pause
        exit
    }

    for ($i = 0; $i -lt $usbDrives.Count; $i++) {
        Write-Host "  [$i] $($usbDrives[$i].DisplayName)" -ForegroundColor White
    }

    $choice = Read-Host "Çelehçiona er pendraîh dêttino [0-$($usbDrives.Count - 1)]"
    $targetUsb = $usbDrives[[int]$choice]

    Write-Host ""
    Write-Host "⚠️ OHO: Er pendraîh $($targetUsb.DisplayName) ÇE BORRARÁ PO KOMPLETO." -ForegroundColor Red
    $confirm = Read-Host "¿Konfîrmah ke kierêh dehkargâh, parcheâh y grabâh TapeOS en êtte USB? (s/N)"
    if ($confirm -ne 's' -and $confirm -ne 'S' -and $confirm -ne 'si' -and $confirm -ne 'yes') {
        Write-Host "Operaçiôn kançelá." -ForegroundColor Gray
        exit
    }
} else {
    Write-Host ""
    Write-Host "[3/4] Modo Îttaladôh: çe kreará er .img çîn grabâh en nîn pun pendraîh." -ForegroundColor Cyan
    $imageDestDir = Read-Host "Karpeta pa guâddâh er medio de îttalaçiôn (.img) [C:\TapeOS\images]"
    if (-not $imageDestDir.Trim()) { $imageDestDir = "C:\TapeOS\images" }
    $confirm = Read-Host "¿Konfîrmah ke kierêh dehkargâh y parcheâh la imâhen pa kreâh er medio de îttalaçiôn? (s/N)"
    if ($confirm -ne 's' -and $confirm -ne 'S' -and $confirm -ne 'si' -and $confirm -ne 'yes') {
        Write-Host "Operaçiôn kançelá." -ForegroundColor Gray
        exit
    }
}

# 3b. Modo Googlêh Play (Çtore)
Write-Host ""
Write-Host "[3b/4] Modo Googlêh Play" -ForegroundColor Yellow
Write-Host "  • ÇÍ (rekomendao): ChromeOS kon Play Çtore y aplikâçionêh Android."
Write-Host "  • NO: Çîn Googlêh Play — Android kon apph APK (Aurora Çtore, çîn kuenta de Google)."
$gaChoice = Read-Host "¿Îttalâh Googlêh Play (Çtore)? (S/n)"
$enableGoogleApps = -not ($gaChoice -match '^[nN]')

# 4. Piplîne Kompleto
Write-Host ""
Write-Host "[Paço A] Dehkargando la imâhen ofiçiâh..." -ForegroundColor Cyan
$downloadDir = "C:\TapeOS\downloads"
$zipPath = Join-Path $downloadDir $recoveryInfo.FileName
Start-TapeOSDownload -Url $recoveryInfo.Url -DestinationFile $zipPath | Out-Null

Write-Host ""
Write-Host "[Paço B] Dehkomprimiendo y aplikando parcheh TapeOS (Legacy EFI + swtpm + GPU; Googlêh Play: $(if ($enableGoogleApps) { 'ÇÍ' } else { 'NO (APK/Aurora)' }))..." -ForegroundColor Cyan
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
    Write-Host "[Paço C] Grabando en er pendraîh USB $($targetUsb.DeviceID)..." -ForegroundColor Cyan
    Start-TapeOSUsbFlash -ImageFilePath $patched.PatchedImagePath -PhysicalDriveId $targetUsb.DeviceID -ProgressCallback {
        param($pct, $speedMBs, $written, $total)
        Write-Progress -Activity "Grabando TapeOS en er pendraîh USB ($speedMBs MB/s)" -Status "$pct% kompletao" -PercentComplete $pct
    }

    Write-Progress -Activity "Grabando TapeOS en er pendraîh USB" -Completed
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Green
    Write-Host "   ¡PROÇEÇO KOMPLETAO! Tu pendraîh TapeOS êttá lîtta pa arrankâh  " -ForegroundColor White
    Write-Host "==================================================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[Paço C] Kreando er medio de îttalaçiôn (.img) çîn grabâh..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $imageDestDir -Force | Out-Null
    $imgName = "TapeOS-$($recoveryInfo.Board)-M$($recoveryInfo.Milestone)-$(if ($enableGoogleApps) { 'googleapps' } else { 'aurora' }).img"
    $imgPath = Join-Path $imageDestDir $imgName
    Copy-Item -Path $patched.PatchedImagePath -Destination $imgPath -Force
    if (Test-Path $patched.ConfigFile) { Copy-Item -Path $patched.ConfigFile -Destination (Join-Path $imageDestDir "grub.cfg") -Force }
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Green
    Write-Host "   ¡MEDIO DE ÎTTALAÇIÔN KREAO! Rûtta: $imgPath" -ForegroundColor White
    Write-Host "   Grábalo kuando kierâh kon Rufû, Win32DiskImager u kon TapeOS" -ForegroundColor Gray
    Write-Host "   (modo Live-USB). Inkluye grub.cfg de arrankê en la mîmma karpeta." -ForegroundColor Gray
    Write-Host "==================================================================" -ForegroundColor Green
}

Write-Host "Pulça kualkiêh têkla pa çalîh..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
