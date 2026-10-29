<#
.SYNOPSIS
    Gestor de Configuraciones de Arranque para TapeOS
.DESCRIPTION
    Genera el menu GRUB de TapeOS (normal / verbose / seguro / instalacion
    a disco duro / recovery original / consola / apagar) e inyecta el menu y
    el initramfs del framework en la particion EFI (ESP) del pendrive tras
    la grabacion. No modifica el arranque de Windows.
#>

function New-TapeOSGrubConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,

        # Ruta del kernel dentro de la particion donde vive GRUB.
        # Recovery ChromeOS: /syslinux/vmlinuz.A
        # Framework propio:  /boot/vmlinuz
        [string]$KernelPath = "/syslinux/vmlinuz.A",

        [string]$InitrdPath = "/tapeos/initramfs.img",

        # PARTUUID de ROOT-A para la entrada de recovery original.
        # Si se omite, la entrada de recovery no se genera.
        [string]$RootPartuuid = "",

        # kern_b_hash= del kernel firmado del recovery original.
        [string]$KernelHash = "",

        [bool]$EnableGoogleApps = $true,
        [string[]]$FrameworkOptions = @(),
        [int]$Timeout = 15
    )

    $parent = Split-Path -Path $OutputPath -Parent
    if (-not (Test-Path $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }

    $optsList = @("enable_updates")
    if (-not $EnableGoogleApps) { $optsList += "no_google_play" }
    foreach ($opt in $FrameworkOptions) { if ($opt) { $optsList += $opt } }
    $optionsStr = $optsList -join ","

    $base = "init=/init boot=local root=/dev/ram0 cros_debug options=$optionsStr console=tty0 loglevel=7"
    $verboseExtra = "verbose ignore_loglevel earlyprintk=efi,keep initcall_debug log_buf_len=2M noquiet console=ttyS0,115200n8"
    $safeExtra = "verbose ignore_loglevel nomodeset i915.modeset=0 amdgpu.modeset=0"
    $installExtra = "verbose install=1"

    $recoveryEntry = ""
    if ($RootPartuuid) {
        $hashParam = if ($KernelHash) { "kern_b_hash=$KernelHash" } else { "" }
        $recoveryEntry = @"
menuentry "5. Arrancar el recovery original de ChromeOS" --class os {
    linux $KernelPath init=/sbin/init rootwait ro noresume loglevel=7 noinitrd console=tty0 ramoops.ecc=1 tpm_tis.force=0 intel_pmc_core.warn_on_s0ix_failures=1 xdomain=0 intel_iommu=on i915.modeset=1 cros_efi root=PARTUUID=$RootPartuuid $hashParam
}

"@
    }

    $grubTemplate = @"
# ===================================================================
# TapeOS - Menu de arranque
# Generado automaticamente por el instalador de TapeOS
#
#   1 = arranque normal con el framework TapeOS
#   2 = diagnostico verbose: mensajes del kernel en pantalla
#   3 = modo seguro: sin aceleracion grafica (nomodeset)
#   4 = INSTALACION EN DISCO DURO (borra el disco destino)
#
# Configuracion original del fabricante guardada como grub.cfg.bak
# ===================================================================
set timeout=$Timeout
set default=0
set pager=1
set color_normal=white/black
set color_highlight=black/light-gray
terminal_output console

menuentry "1. Arrancar TapeOS - modo normal" --class os {
    if [ -f $InitrdPath ]; then
        linux $KernelPath $base
        initrd $InitrdPath
    else
        echo "ERROR: falta $InitrdPath en la particion EFI."
        echo "El framework TapeOS no esta instalado en este medio."
        sleep 15
    fi
}

menuentry "2. Arrancar TapeOS - Diagnostico verbose (ver mensajes)" --class os {
    if [ -f $InitrdPath ]; then
        linux $KernelPath $base $verboseExtra
        initrd $InitrdPath
    else
        echo "ERROR: falta $InitrdPath en la particion EFI."
        sleep 15
    fi
}

menuentry "3. Arrancar TapeOS - Modo seguro (sin graficos)" --class os {
    if [ -f $InitrdPath ]; then
        linux $KernelPath $base $safeExtra
        initrd $InitrdPath
    else
        echo "ERROR: falta $InitrdPath en la particion EFI."
        sleep 15
    fi
}

menuentry "4. Instalar TapeOS en un disco duro" --class os {
    if [ -f $InitrdPath ]; then
        linux $KernelPath $base $installExtra
        initrd $InitrdPath
    else
        echo "ERROR: falta $InitrdPath en la particion EFI."
        echo "No se puede iniciar el instalador sin el framework TapeOS."
        sleep 15
    fi
}

$recoveryEntry
menuentry "6. Consola de comandos GRUB" --class settings {
    commandline
}

menuentry "7. Apagar el equipo" --class halt {
    halt
}
"@

    Set-Content -Path $OutputPath -Value $grubTemplate -Encoding ASCII
    Write-Host "[TapeOS BootManager] Menu GRUB generado en '$OutputPath'." -ForegroundColor Green
}

function Write-TapeOSGrubToEsp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$DiskNumber,

        [string]$KernelPath = "/syslinux/vmlinuz.A",
        [int]$Timeout = 15,

        # Ruta (en Windows) del initramfs del framework a inyectar como
        # \tapeos\initramfs.img. Si no existe, el menu se inyecta igual
        # pero las entradas del framework avisaran de que falta el initramfs.
        [string]$InitramfsPath = "",
        [bool]$EnableGoogleApps = $true,
        [string[]]$FrameworkOptions = @()
    )

    Import-Module Storage -ErrorAction Stop

    try { Update-Disk -Number $DiskNumber -ErrorAction SilentlyContinue | Out-Null } catch { }
    Start-Sleep -Milliseconds 800

    $esp = Get-Partition -DiskNumber $DiskNumber -ErrorAction SilentlyContinue |
        Where-Object { $_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' } |
        Select-Object -First 1
    if (-not $esp) { throw "No se encontro la particion EFI (ESP) en el disco $DiskNumber." }

    $letter = $null
    $assigned = $false
    if ($esp.DriveLetter) {
        $letter = [string]$esp.DriveLetter
    } else {
        foreach ($candidate in @('Z','Y','X','W','V','U','T')) {
            if (-not (Test-Path "${candidate}:\")) { $letter = $candidate; break }
        }
        if (-not $letter) { throw "No hay letra de unidad libre para montar la ESP del disco $DiskNumber." }
        Set-Partition -DiskNumber $DiskNumber -PartitionNumber $esp.PartitionNumber -NewDriveLetter $letter -ErrorAction Stop
        $assigned = $true
        Start-Sleep -Milliseconds 1200
    }

    try {
        $cfgPath = Join-Path "${letter}:" 'efi\boot\grub.cfg'
        if (-not (Test-Path -LiteralPath (Split-Path $cfgPath))) { throw "La ESP del disco $DiskNumber no contiene la carpeta efi\boot." }

        $rootPartuuid = ""
        $kernelHash = ""
        if (Test-Path -LiteralPath $cfgPath) {
            $original = Get-Content -LiteralPath $cfgPath -Raw
            $m = [regex]::Match($original, 'root=PARTUUID=([0-9A-Fa-f\-]+)')
            if ($m.Success) { $rootPartuuid = $m.Groups[1].Value }
            $h = [regex]::Match($original, 'kern_b_hash=([0-9A-Fa-f]+)')
            if ($h.Success) { $kernelHash = $h.Groups[1].Value }
            Copy-Item -LiteralPath $cfgPath -Destination ($cfgPath + '.bak') -Force
        }

        New-TapeOSGrubConfig -OutputPath $cfgPath -KernelPath $KernelPath `
            -RootPartuuid $rootPartuuid -KernelHash $kernelHash `
            -EnableGoogleApps $EnableGoogleApps -FrameworkOptions $FrameworkOptions `
            -Timeout $Timeout | Out-Null

        $initramfsInjected = $false
        if ($InitramfsPath -and (Test-Path -LiteralPath $InitramfsPath)) {
            $tapeosDir = Join-Path "${letter}:" 'tapeos'
            if (-not (Test-Path -LiteralPath $tapeosDir)) { New-Item -ItemType Directory -Path $tapeosDir -Force | Out-Null }
            Copy-Item -LiteralPath $InitramfsPath -Destination (Join-Path $tapeosDir 'initramfs.img') -Force
            $initramfsInjected = $true
        }

        Write-Host "[TapeOS BootManager] Menu inyectado en $cfgPath (PARTUUID=$rootPartuuid, initramfs=$initramfsInjected)." -ForegroundColor Green
        return [PSCustomObject]@{
            EspDrive          = "${letter}:"
            ConfigPath        = $cfgPath
            RootPartuuid      = $rootPartuuid
            KernelHash        = $kernelHash
            InitramfsInjected = $initramfsInjected
        }
    } finally {
        if ($assigned) {
            try { Remove-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $esp.PartitionNumber -AccessPath "${letter}:\" -ErrorAction SilentlyContinue } catch { }
        }
    }
}

Export-ModuleMember -Function New-TapeOSGrubConfig, Write-TapeOSGrubToEsp