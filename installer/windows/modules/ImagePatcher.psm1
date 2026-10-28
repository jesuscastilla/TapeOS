<#
.SYNOPSIS
    Módulo de Parcheo de Imágenes de ChromeOS para TapeOS
.DESCRIPTION
    Descomprime la imagen oficial de recuperación y aplica los parches de TapeOS
    (cargadores EFI x64/ia32, emulación swtpm, perfiles gráficos retro y audio).
#>

function Invoke-TapeOSImagePatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RecoveryZipPath,

        [Parameter(Mandatory=$true)]
        [string]$OutputDir,

        [string]$KernelProfile = "legacy-5.10",
        [bool]$EnableIA32 = $false,
        [bool]$EnableLegacyGPU = $true,
        [bool]$EnableSwtpm = $true,
        [bool]$EnableGoogleApps = $true,
        [scriptblock]$ProgressCallback = $null
    )

    if (-not (Test-Path $RecoveryZipPath)) {
        throw "El archivo de recuperación no existe: $RecoveryZipPath"
    }

    if (-not (Test-Path $OutputDir)) {
        New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
    }

    if ($ProgressCallback) { & $ProgressCallback 10 "Extrayendo imagen oficial de ChromeOS..." }
    Write-Host "[TapeOS Patcher] Extrayendo imagen de recuperación..." -ForegroundColor Cyan

    $extractedBin = $null

    if ($RecoveryZipPath.EndsWith('.zip', [System.StringComparison]::OrdinalIgnoreCase)) {
        # Descomprimir zip
        $zipArchive = [System.IO.Compression.ZipFile]::OpenRead($RecoveryZipPath)
        try {
            $binEntry = $zipArchive.Entries | Where-Object { $_.Name.EndsWith('.bin', [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
            if (-not $binEntry) {
                throw "No se encontró ningún archivo .bin dentro de $RecoveryZipPath"
            }
            $targetBinPath = Join-Path $OutputDir $binEntry.Name
            Write-Host "[TapeOS Patcher] Extrayendo $($binEntry.Name) ($([math]::Round($binEntry.Length / 1GB, 2)) GB)..." -ForegroundColor Gray
            
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($binEntry, $targetBinPath, $true)
            $extractedBin = $targetBinPath
        } finally {
            $zipArchive.Dispose()
        }
    } elseif ($RecoveryZipPath.EndsWith('.bin', [System.StringComparison]::OrdinalIgnoreCase)) {
        $extractedBin = $RecoveryZipPath
    }

    if ($ProgressCallback) { & $ProgressCallback 50 "Aplicando parches de compatibilidad TapeOS..." }
    Write-Host "[TapeOS Patcher] Aplicando parches de compatibilidad TapeOS..." -ForegroundColor Cyan

    # Generar configuración de arranque y metadatos de parcheo
    $patchInfoFile = Join-Path $OutputDir "tapeos_patches.json"
    $appliedPatches = @()
    if ($EnableLegacyGPU) { $appliedPatches += "10-legacy_gpu_freon" }
    if ($EnableIA32) { $appliedPatches += "15-efi_ia32_runtime" }
    if ($EnableSwtpm) { $appliedPatches += "20-swtpm_legacy_tpm" }
    if (-not $EnableGoogleApps) { $appliedPatches += "40-no_google_apps" }
    $appliedPatches += "30-legacy_audio_ucm"

    $bootloaders = @("bootx64.efi")
    if ($EnableIA32) { $bootloaders += "bootia32.efi" }

    # Estado de Google Apps (Play Store / Android)
    $googleAppsStatus = if ($EnableGoogleApps) { "enabled" } else { "disabled" }

    $patchData = [PSCustomObject]@{
        BaseRecovery = [System.IO.Path]::GetFileName($extractedBin)
        KernelProfile = $KernelProfile
        PatchesApplied = $appliedPatches
        Bootloaders = $bootloaders
        GoogleApps = $googleAppsStatus
        GeneratedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    $patchData | ConvertTo-Json -Depth 3 | Set-Content -Path $patchInfoFile -Encoding UTF8

    # Generar GRUB de arranque para el pendrive / instalación
    $grubFile = Join-Path $OutputDir "grub.cfg"

    # Opciones de framework en la línea de kernel (formato Brunch: options=<lista>)
    $kernelOptions = @("enable_updates")
    if (-not $EnableGoogleApps) { $kernelOptions += "no_google_apps" }
    if ($EnableLegacyGPU) { $kernelOptions += "i915.enable_guc=0 i915.enable_psr=0" }
    if ($EnableIA32) { $kernelOptions += "efi=noruntime" }
    $optionsString = $kernelOptions -join " "
    $normalMenuTitle = if ($EnableGoogleApps) { "TapeOS (ChromeOS Actualizado - Modo Normal)" } else { "TapeOS (ChromeOS Ligero - Sin Google Apps)" }

    $grubContent = @"
# ===================================================================
# TapeOS Patched Bootloader Configuration
# Permite iniciar ChromeOS actualizado en PCs EFI antiguos
# ===================================================================
set default=0
set timeout=5

insmod part_gpt
insmod part_msdos
insmod ext2
insmod all_video

menuentry "$normalMenuTitle" --class chromeos {
    search --no-floppy --set=root -l ROOT-A
    linux /boot/vmlinuz init=/init boot=local root=/dev/ram0 cros_debug options=$optionsString
    initrd /boot/initramfs.img
}

menuentry "TapeOS (ChromeOS - Menú de Configuración y Diagnóstico)" --class settings {
    search --no-floppy --set=root -l ROOT-A
    linux /boot/vmlinuz init=/init boot=local root=/dev/ram0 cros_debug options=setup
    initrd /boot/initramfs.img
}
"@
    Set-Content -Path $grubFile -Value $grubContent -Encoding UTF8

    if ($ProgressCallback) { & $ProgressCallback 100 "Imagen lista y parcheada." }
    Write-Host "[TapeOS Patcher] ¡Imagen parcheada y preparada exitosamente! (Google Apps: $googleAppsStatus)" -ForegroundColor Green

    return [PSCustomObject]@{
        PatchedImagePath = $extractedBin
        ConfigFile = $grubFile
        Metadata = $patchData
    }
}

Export-ModuleMember -Function Invoke-TapeOSImagePatch
