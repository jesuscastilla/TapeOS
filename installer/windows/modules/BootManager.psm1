<#
.SYNOPSIS
    Gestor de Arranque y Dual-Boot para TapeOS
.DESCRIPTION
    Genera configuraciones personalizadas de GRUB para UEFI (x64/ia32) y BIOS Legacy (MBR).
    Configura la integración en el Administrador de Arranque de Windows (BCD).
#>

function New-TapeOSGrubConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,

        [Parameter(Mandatory=$true)]
        [string]$KernelType, # modern, legacy-5.10, legacy-5.4, legacy-4.19

        [string]$ImgPath = "C:\TapeOS\chromeos.img",
        [bool]$LegacyBIOS = $false,
        [bool]$IA32UEFI = $false,
        [string[]]$CustomKernelParams = @()
    )

    $parent = Split-Path -Path $OutputPath -Parent
    if (-not (Test-Path $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }

    # Parámetros por defecto de TapeOS
    $cmdline = @("cros_debug", "options=enable_updates")

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

    $grubTemplate = @"
# ===================================================================
# Archivo de Configuración de Arranque de TapeOS (Brunch Evolution)
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
insmod ntfs
insmod all_video

menuentry "TapeOS (ChromeOS) - Normal Boot" --class chromeos --class gnu-linux {
    echo "Iniciando TapeOS Framework..."
    search --no-floppy --file --set=root /TapeOS/chromeos.img
    loopback loop /TapeOS/chromeos.img
    linux (loop,3)/kernel init=/init boot=local root=/dev/ram0 loop.max_part=16 loop=/TapeOS/chromeos.img $cmdlineStr
    initrd (loop,3)/initramfs.img
}

menuentry "TapeOS (Configuración y Diagnóstico / Settings)" --class settings {
    echo "Iniciando menú de configuración de TapeOS..."
    search --no-floppy --file --set=root /TapeOS/chromeos.img
    loopback loop /TapeOS/chromeos.img
    linux (loop,3)/kernel init=/init boot=local root=/dev/ram0 loop.max_part=16 loop=/TapeOS/chromeos.img $cmdlineStr options=setup
    initrd (loop,3)/initramfs.img
}

menuentry "TapeOS (Modo Seguro / Fallback - Kernel Legacy)" --class recovery {
    echo "Iniciando TapeOS en modo seguro..."
    search --no-floppy --file --set=root /TapeOS/chromeos.img
    loopback loop /TapeOS/chromeos.img
    linux (loop,3)/kernel init=/init boot=local root=/dev/ram0 loop.max_part=16 loop=/TapeOS/chromeos.img cros_debug cros_legacy nomodeset
    initrd (loop,3)/initramfs.img
}

menuentry "Windows Boot Manager" --class windows {
    echo "Retornando a Windows..."
    search --no-floppy --set=root --file /EFI/Microsoft/Boot/bootmgfw.efi
    chainloader /EFI/Microsoft/Boot/bootmgfw.efi
}
"@

    Set-Content -Path $OutputPath -Value $grubTemplate -Encoding UTF8
    Write-Host "[TapeOS BootManager] Configuración de GRUB guardada en '$OutputPath'." -ForegroundColor Green
}

function Register-TapeOSInWindowsBCD {
    [CmdletBinding()]
    param(
        [string]$Description = "TapeOS (ChromeOS)",
        [string]$EfiPath = "\EFI\TapeOS\grubx64.efi"
    )

    Write-Host "[TapeOS BootManager] Configurando entrada en Windows BCD (Dual-Boot)..." -ForegroundColor Cyan

    try {
        # Crear entrada en el Administrador de Arranque de Windows
        $createResult = & bcdedit.exe /create /d "$Description" /application path 2>&1
        $guidMatch = [regex]::Match($createResult, '\{[a-fA-F0-9\-]+\}')
        
        if ($guidMatch.Success) {
            $guid = $guidMatch.Value
            & bcdedit.exe /set $guid device boot | Out-Null
            & bcdedit.exe /set $guid path $EfiPath | Out-Null
            & bcdedit.exe /displayorder $guid /addlast | Out-Null
            & bcdedit.exe /timeout 10 | Out-Null
            Write-Host "[TapeOS BootManager] Entrada BCD creada con éxito ($guid)." -ForegroundColor Green
            return $guid
        } else {
            Write-Warning "No se pudo crear automáticamente la entrada BCD. Es posible que se requiera permisos de Administrador."
            return $null
        }
    } catch {
        Write-Warning "Fallo al ejecutar bcdedit: $_"
        return $null
    }
}

Export-ModuleMember -Function New-TapeOSGrubConfig, Register-TapeOSInWindowsBCD
