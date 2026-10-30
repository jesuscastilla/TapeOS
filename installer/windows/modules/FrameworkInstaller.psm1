<#
.SYNOPSIS
    Instalador del motor de compatibilidad TapeOS a traves de WSL para el asistente Windows.
.DESCRIPTION
    Detecta WSL, expone el disco destino con 'wsl --mount --bare' y ejecuta
        $cmd = "bash $wslScripts/install-framework-usb.sh $wslBin $devName $wslAssets ""$Options"""
    capa TapeOS: parches, Aurora Store, GRUB sin menu de configuracion).
#>

function Test-TapeOSWsl {
    try {
        $out = (& wsl.exe -l -q 2>$null | Out-String).Trim()
        return ($out.Length -gt 0)
    } catch { return $false }
}

function ConvertTo-TapeOSWslPath {
    param([string]$WinPath)
    $full = (Resolve-Path -LiteralPath $WinPath -ErrorAction Stop).Path
    $drive = $full.Substring(0, 1).ToLower()
    $rest = $full.Substring(2).Replace('\', '/')
    return "/mnt/$drive$rest"
}

function Invoke-TapeOSFrameworkInstall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ImageFilePath,   # .bin del recovery (ruta Windows)
        [Parameter(Mandatory=$true)][int]$DiskNumber,
        [Parameter(Mandatory=$true)][string]$BrunchScriptDir, # carpeta core/brunch (Windows)
        [Parameter(Mandatory=$true)][string]$BrunchAssetsDir, # carpeta con rootc.img, efi_legacy.img, tapeos-tools, AuroraStore.apk
        [string]$Options = "enable_updates"  # opciones de framework (parches automaticos segun hardware)
    )

    if (-not (Test-TapeOSWsl)) { throw "WSL no esta disponible: no se puede instalar TapeOS." }

    # Soltar volumenes del disco para que WSL pueda montarlo en exclusiva
    $parts = Get-Partition -DiskNumber $DiskNumber -ErrorAction SilentlyContinue
    foreach ($p in $parts) {
        foreach ($ap in @($p.AccessPaths)) {
            if ($ap -like '\\?\Volume{*}\') {
                & mountvol.exe "$ap" /p 2>$null | Out-Null
            }
        }
    }
    Start-Sleep -Milliseconds 500

    $wslBin = ConvertTo-TapeOSWslPath $ImageFilePath
    $wslScripts = ConvertTo-TapeOSWslPath $BrunchScriptDir
    $wslAssets = ConvertTo-TapeOSWslPath $BrunchAssetsDir
    $dev = "\\.\PhysicalDrive$DiskNumber"

    & wsl.exe --mount $dev --bare 2>$null | Out-Null
    Start-Sleep -Seconds 2
    try {
        # Identificar /dev/sdX por tamano exacto en bytes
        $winSizeBytes = [long](Get-Disk -Number $DiskNumber).Size
        $devName = ""
        $lsblk = (& wsl.exe -u root -e bash -c "lsblk -b -o NAME,SIZE,RO" 2>$null | Out-String).Trim()
        foreach ($line in ($lsblk -split "`r?`n")) {
            if ($line -match '^(sd[a-z]+)\s+(\d+)\s+\d$') {
                if ([long]$Matches[2] -eq $winSizeBytes) { $devName = "/dev/$($Matches[1])"; break }
            }
        }
        if (-not $devName) { throw "No se pudo localizar el disco $DiskNumber dentro de WSL." }

        Write-Host "[TapeOS] Disco WSL: $devName ($winSizeBytes bytes)" -ForegroundColor Cyan

        Write-Host "[TapeOS] Ejecutando: $cmd" -ForegroundColor Cyan
        & wsl.exe -u root -e bash -c $cmd
        if ($LASTEXITCODE -ne 0) { throw "La instalacion de TapeOS fallo (exit $LASTEXITCODE)." }
        Write-Host "[TapeOS] Instalacion completada en $devName." -ForegroundColor Green
    } finally {
        & wsl.exe --unmount $dev 2>$null | Out-Null
    }
    return $true
}

Export-ModuleMember -Function Test-TapeOSWsl, Invoke-TapeOSFrameworkInstall