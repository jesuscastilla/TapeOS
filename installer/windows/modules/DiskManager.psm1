<#
.SYNOPSIS
    Gestor de Discos e Imágenes para TapeOS Windows Installer
.DESCRIPTION
    Crea archivos de imagen de disco (chromeos.img / VHDX), gestiona particiones,
    descomprime archivos de recuperación y prepara discos USB.
#>

function New-TapeOSDiskImage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [int]$SizeGB
    )

    $parentDir = Split-Path -Path $Path -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }

    Write-Host "[TapeOS DiskManager] Creando imagen de disco vacía de $SizeGB GB en '$Path'..." -ForegroundColor Cyan

    # Crear archivo con tamaño preasignado de forma rápida usando FileStream
    $totalBytes = [int64]$SizeGB * 1024L * 1024L * 1024L
    $fs = [System.IO.File]::Create($Path)
    try {
        $fs.SetLength($totalBytes)
    } finally {
        $fs.Close()
    }

    Write-Host "[TapeOS DiskManager] Imagen creada satisfactoriamente ($SizeGB GB)." -ForegroundColor Green
    return $Path
}

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

Export-ModuleMember -Function New-TapeOSDiskImage, Expand-TapeOSArchive, Get-TapeOSUSBTargets
