<#
.SYNOPSIS
    Gestor de Discos e Imágenes para TapeOS Windows Installer
.DESCRIPTION
    Proporciona utilidades de descompresion de imagenes de recuperacion y
    deteccion de destinos USB para el instalador (modos Live-USB e Instalador).
#>

function Expand-TapeOSArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ArchivePath,

        [Parameter(Mandatory=$true)]
        [string]$DestinationPath
    )

    if (-not (Test-Path $ArchivePath)) {
        throw "El archivo origen no existe: $ArchivePath"
    }

    if (-not (Test-Path $DestinationPath)) {
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
    }

    Write-Host "[TapeOS DiskManager] Descomprimiendo '$ArchivePath'..." -ForegroundColor Cyan

    if ($ArchivePath.EndsWith('.zip', [System.StringComparison]::OrdinalIgnoreCase)) {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ArchivePath, $DestinationPath)
    } elseif ($ArchivePath.EndsWith('.tar.gz', [System.StringComparison]::OrdinalIgnoreCase) -or $ArchivePath.EndsWith('.tgz', [System.StringComparison]::OrdinalIgnoreCase)) {
        # Usar tar nativo de Windows 10/11
        & tar.exe -zxvf $ArchivePath -C $DestinationPath
        if ($LASTEXITCODE -ne 0) {
            throw "Error al descomprimir tar.gz con tar.exe (Código de salida $LASTEXITCODE)"
        }
    } else {
        throw "Formato de archivo no reconocido: $ArchivePath"
    }

    Write-Host "[TapeOS DiskManager] Descompresión finalizada con éxito." -ForegroundColor Green
}

function Get-TapeOSUSBTargets {
    [CmdletBinding()]
    param()

    # Detectar unidades removibles / USB
    $usbDrives = Get-CimInstance -ClassName Win32_DiskDrive | Where-Object { $_.InterfaceType -match 'USB' -or $_.MediaType -match 'Removable' }
    return $usbDrives
}

Export-ModuleMember -Function Expand-TapeOSArchive, Get-TapeOSUSBTargets
