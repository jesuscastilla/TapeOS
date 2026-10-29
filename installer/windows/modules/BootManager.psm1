<#
.SYNOPSIS
    Gestor de Configuraciones de Arranque para TapeOS
.DESCRIPTION
    Genera configuraciones personalizadas de GRUB para medios Live-USB e
    instalador (UEFI x64/ia32 y BIOS Legacy). No modifica el arranque de Windows.
#>

function New-TapeOSGrubConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,

        [Parameter(Mandatory=$true)]
        [string]$KernelType, # modern, legacy-5.10, legacy-5.4, legacy-4.19

        [bool]$LegacyBIOS = $false,
        [bool]$IA32UEFI = $false,
        [bool]$EnableGoogleApps = $true,
        [string[]]$FrameworkOptions = @(),
        [string[]]$CustomKernelParams = @()
    )

    $parent = Split-Path -Path $OutputPath -Parent
    if (-not (Test-Path $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }

    # Parámetros por defecto de TapeOS (opciones de framework)
    $kernelFrameworkOptions = @("enable_updates")
    if (-not $EnableGoogleApps) { $kernelFrameworkOptions += "no_google_play" }
    foreach ($opt in $FrameworkOptions) {
        if ($opt) { $kernelFrameworkOptions += $opt }
    }
    $cmdline = @("cros_debug", ("options=" + ($kernelFrameworkOptions -join ",")))

    if ($LegacyBIOS) {
        $cmdline += "cros_legacy"
        $cmdline += "nomodeset_bootsplash"
    }

    if ($IA32UEFI) {
        $cmdline += "efi=noruntime"
    }

    if ($KernelType -match 'legacy') {
        $cmdline += "legacy_audio"
        $cmdline += "i915.modeset=1"
        $cmdline += "radeon.modeset=1"
    }

    if ($CustomKernelParams) {
        $cmdline += $CustomKernelParams
    }

    $cmdlineStr = ($cmdline -join " ")
    $normalTitle = if ($EnableGoogleApps) { "TapeOS (ChromeOS) - Normal Boot" } else { "TapeOS (ChromeOS) - Sin Google Play / APK + Aurora" }

    $grubTemplate = @"
# ===================================================================
# Archivo de Configuración de Arranque de TapeOS
# Generado automáticamente por TapeOS Windows Installer
# ===================================================================

set default=0
set timeout=5

# Cargar fuentes e interfaz gráfica
if [ -s `$prefix/grubenv ]; then
  load_env
fi

insmod part_gpt
insmod part_msdos
insmod ext2
insmod all_video

menuentry "$normalTitle" --class chromeos --class gnu-linux {
    echo "Iniciando TapeOS..."
    search --no-floppy --set=root -l ROOT-A
    linux /boot/vmlinuz init=/init boot=local root=/dev/ram0 $cmdlineStr
    initrd /boot/initramfs.img
}

menuentry "TapeOS (Configuración y Diagnóstico / Settings)" --class settings {
    echo "Iniciando menú de configuración de TapeOS..."
    search --no-floppy --set=root -l ROOT-A
    linux /boot/vmlinuz init=/init boot=local root=/dev/ram0 cros_debug options=setup
    initrd /boot/initramfs.img
}

menuentry "TapeOS (Modo Seguro / Fallback - Kernel Legacy)" --class recovery {
    echo "Iniciando TapeOS en modo seguro..."
    search --no-floppy --set=root -l ROOT-A
    linux /boot/vmlinuz init=/init boot=local root=/dev/ram0 cros_debug cros_legacy nomodeset
    initrd /boot/initramfs.img
}
"@

    Set-Content -Path $OutputPath -Value $grubTemplate -Encoding UTF8
    Write-Host "[TapeOS BootManager] Konfiguraçiôn de GRUB guâddá en '$OutputPath'." -ForegroundColor Green
}

Export-ModuleMember -Function New-TapeOSGrubConfig
