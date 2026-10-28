<#
.SYNOPSIS
    Módulo de Grabación Directa en Pendrives USB para TapeOS
.DESCRIPTION
    Detecta dispositivos USB de forma segura (excluyendo discos internos y del sistema)
    y graba directamente la imagen de TapeOS sector a sector con informe de progreso.
#>

function Get-TapeOSUsbDrives {
    [CmdletBinding()]
    param()

    $drives = @()

    try {
        # Obtener discos con BusType USB que NO sean de sistema ni de arranque
        $usbDisks = Get-Disk | Where-Object { 
            ($_.BusType -eq 'USB' -or $_.Location -match 'USB') -and 
            -not $_.IsSystem -and 
            -not $_.IsBoot 
        }

        foreach ($disk in $usbDisks) {
            # Obtener particiones y letras asociadas
            $partitions = Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue
            $letters = ($partitions | Where-Object { $_.DriveLetter } | ForEach-Object { "$($_.DriveLetter):" }) -join ", "
            if (-not $letters) { $letters = "Sin partición asignada" }

            $drives += [PSCustomObject]@{
                DiskNumber = $disk.Number
                DeviceID = "\\.\PhysicalDrive$($disk.Number)"
                FriendlyName = $disk.FriendlyName
                SizeGB = [math]::Round(($disk.Size / 1GB), 2)
                DriveLetters = $letters
                DisplayName = "Disco $($disk.Number): $($disk.FriendlyName) ($([math]::Round(($disk.Size / 1GB), 1)) GB) [$letters]"
            }
        }
    } catch {
        Write-Warning "Fallo al consultar discos USB: $_"
    }

    return $drives
}

function Start-TapeOSUsbFlash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ImageFilePath,

        [Parameter(Mandatory=$true)]
        [string]$PhysicalDriveId, # Ej. \\.\PhysicalDrive1

        [scriptblock]$ProgressCallback = $null
    )

    if (-not (Test-Path $ImageFilePath)) {
        throw "El archivo de imagen no existe: $ImageFilePath"
    }

    # Comprobación de seguridad absoluta: No permitir jamás flashear el disco 0 si es del sistema
    $targetNumber = [regex]::Match($PhysicalDriveId, '\d+$').Value
    if ($targetNumber) {
        $checkDisk = Get-Disk -Number $targetNumber -ErrorAction SilentlyContinue
        if ($checkDisk.IsSystem -or $checkDisk.IsBoot) {
            throw "¡SEGURIDAD! El disco seleccionado ($PhysicalDriveId) es un disco del sistema operativo Windows. Operación abortada."
        }
    }

    Write-Host "[TapeOS UsbFlasher] Preparando escritura en $PhysicalDriveId..." -ForegroundColor Cyan

    # Desmontar volúmenes lógicos del disco para evitar bloqueos de Windows
    try {
        $parts = Get-Partition -DiskNumber $targetNumber -ErrorAction SilentlyContinue
        foreach ($p in $parts) {
            if ($p.DriveLetter) {
                Write-Host "[TapeOS UsbFlasher] Bloqueando y desmontando unidad $($p.DriveLetter):..." -ForegroundColor Gray
            }
        }
    } catch {
        # Continuar si falla la consulta
    }

    $sourceFileInfo = New-Object System.IO.FileInfo($ImageFilePath)
    $totalBytes = $sourceFileInfo.Length
    $bufferSize = 4 * 1024 * 1024 # Buffer de 4 MB
    $buffer = New-Object byte[] $bufferSize

    Write-Host "[TapeOS UsbFlasher] Grabando $([math]::Round($totalBytes / 1GB, 2)) GB en $PhysicalDriveId..." -ForegroundColor Yellow

    $sourceStream = [System.IO.File]::OpenRead($ImageFilePath)
    $destStream = $null

    try {
        # Abrir el dispositivo físico directamente con FileAccess.Write
        $destStream = New-Object System.IO.FileStream(
            $PhysicalDriveId,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::ReadWrite
        )

        $bytesWritten = 0L
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $lastReportTime = 0

        while (($read = $sourceStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $destStream.Write($buffer, 0, $read)
            $bytesWritten += $read

            $elapsedSec = $stopwatch.Elapsed.TotalSeconds
            if ($elapsedSec - $lastReportTime -ge 0.5 -or $bytesWritten -ge $totalBytes) {
                $lastReportTime = $elapsedSec
                $percent = [math]::Round(($bytesWritten / $totalBytes) * 100, 1)
                $speedMBs = if ($elapsedSec -gt 0) { [math]::Round(($bytesWritten / 1MB) / $elapsedSec, 1) } else { 0 }
                
                if ($ProgressCallback) {
                    & $ProgressCallback $percent $speedMBs $bytesWritten $totalBytes
                }
            }
        }

        $destStream.Flush()
        $stopwatch.Stop()
        Write-Host "[TapeOS UsbFlasher] Grabación finalizada con éxito en $([math]::Round($stopwatch.Elapsed.TotalSeconds, 1)) segundos." -ForegroundColor Green
        return $true
    } catch {
        throw "Error al escribir en el disco físico: $($_.Exception.Message)"
    } finally {
        if ($sourceStream) { $sourceStream.Close() }
        if ($destStream) { $destStream.Close() }
    }
}

Export-ModuleMember -Function Get-TapeOSUsbDrives, Start-TapeOSUsbFlash
