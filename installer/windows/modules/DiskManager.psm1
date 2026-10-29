<#
.SYNOPSIS
    Gestor de Discos e Imágenes para TapeOS Windows Installer
.DESCRIPTION
    Proporciona utilidades de descompresion de imagenes de recuperacion y
    deteccion de destinos USB para el instalador (modos Live-USB e Instalador).
#>

# Dependencia de compresion: cargarla al importar (cada runspace debe tenerla)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Expand-TapeOSArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ArchivePath,

        [Parameter(Mandatory=$true)]
        [string]$DestinationPath
    )

    if (-not (Test-Path $ArchivePath)) {
        throw "Er arxibo orihen no êççîtte: $ArchivePath"
    }

    if (-not (Test-Path $DestinationPath)) {
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
    }

    Write-Host "[TapeOS DiskManager] Dehkomprimiendo '$ArchivePath'..." -ForegroundColor Cyan

    if ($ArchivePath.EndsWith('.zip', [System.StringComparison]::OrdinalIgnoreCase)) {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ArchivePath, $DestinationPath)
    } elseif ($ArchivePath.EndsWith('.tar.gz', [System.StringComparison]::OrdinalIgnoreCase) -or $ArchivePath.EndsWith('.tgz', [System.StringComparison]::OrdinalIgnoreCase)) {
        # Usar tar nativo de Windows 10/11
        & tar.exe -zxvf $ArchivePath -C $DestinationPath
        if ($LASTEXITCODE -ne 0) {
            throw "Errôh al dehkomprimîh tar.gz kon tar.exe (Kódiho de çalía $LASTEXITCODE)"
        }
    } else {
        throw "Formato de arxibo no rekonocío: $ArchivePath"
    }

    Write-Host "[TapeOS DiskManager] Dehkompreçiôn finaliçá kon éxito." -ForegroundColor Green
}

function Get-TapeOSUSBTargets {
    [CmdletBinding()]
    param()

    # Detectar unidades removibles / USB
    $usbDrives = Get-CimInstance -ClassName Win32_DiskDrive | Where-Object { $_.InterfaceType -match 'USB' -or $_.MediaType -match 'Removable' }
    return $usbDrives
}

Export-ModuleMember -Function Expand-TapeOSArchive, Get-TapeOSUSBTargets
