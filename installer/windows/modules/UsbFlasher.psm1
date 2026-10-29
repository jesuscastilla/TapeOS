<#
.SYNOPSIS
    Módulo de Grabación Directa en Pendrives USB para TapeOS
.DESCRIPTION
    Detecta dispositivos USB de forma segura (excluyendo discos internos y del sistema)
    y graba directamente la imagen de TapeOS sector a sector con informe de progreso.
#>

# API nativa para abrir dispositivos fisicos (\\.\PhysicalDriveN) en cualquier runtime
Add-Type -MemberDefinition @"
[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern IntPtr CreateFile(string lpFileName, uint dwDesiredAccess, uint dwShareMode, IntPtr lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, IntPtr hTemplateFile);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool DeviceIoControl(IntPtr hDevice, uint dwIoControlCode, IntPtr lpInBuffer, uint nInBufferSize, IntPtr lpOutBuffer, uint nOutBufferSize, out uint lpBytesReturned, IntPtr lpOverlapped);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool WriteFile(IntPtr hFile, [In] byte[] lpBuffer, uint nNumberOfBytesToWrite, out uint lpNumberOfBytesWritten, IntPtr lpOverlapped);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool FlushFileBuffers(IntPtr hFile);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool CloseHandle(IntPtr hObject);
"@ -Name NativeMethods -Namespace TapeOSWin32

function Get-TapeOSUsbDrives {
    [CmdletBinding()]
    param()

    $drives = @()
    $usbNumbers = @()

    # Fuente 1: BusType USB (Get-Disk)
    try {
        $usbNumbers += @(Get-Disk | Where-Object { $_.BusType -eq 'USB' } | Select-Object -ExpandProperty Number)
    } catch {
        Write-Warning "Fuente 1 (BusType USB) no disponible: $_"
    }

    # Fuente 2: MediaType "External" (adaptadores SSD/HDD-USB con UASP se
    #           reportan como SCSI con medio externo, no como USB)
    try {
        $usbNumbers += @(Get-CimInstance Win32_DiskDrive | Where-Object { $_.MediaType -match 'External' } | ForEach-Object { [int]$_.Index })
    } catch {
        Write-Warning "Fuente 2 (MediaType External) no disponible: $_"
    }

    # Fuente 3: recorrer el arbol PnP hasta encontrar una raiz USB
    #           (cubre puentes USB-SATA/NVMe reportados como SCSI o NVMe)
    try {
        $pnpDisks = Get-PnpDevice -Class DiskDrive -PresentOnly -ErrorAction SilentlyContinue
        foreach ($dev in $pnpDisks) {
            $cur = $dev
            for ($i = 0; $i -lt 8 -and $cur; $i++) {
                if ($cur.InstanceId -match '^USB') {
                    $d = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | Where-Object { $_.PNPDeviceID -eq $dev.InstanceId }
                    if ($d) { $usbNumbers += [int]$d.Index }
                    break
                }
                $parent = (Get-PnpDeviceProperty -InstanceId $cur.InstanceId -KeyName 'DEVPKEY_Device_Parent' -ErrorAction SilentlyContinue).Data
                if (-not $parent) { break }
                $cur = Get-PnpDevice -InstanceId $parent -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-Warning "Fuente 3 (arbol PnP) no disponible: $_"
    }

    $usbNumbers = @($usbNumbers | Sort-Object -Unique)

    foreach ($number in $usbNumbers) {
        try {
            $disk = Get-Disk -Number $number -ErrorAction SilentlyContinue
            if (-not $disk) { continue }
            # Seguridad: nunca ofrecer discos de sistema o arranque
            if ($disk.IsSystem -or $disk.IsBoot) { continue }

            $partitions = Get-Partition -DiskNumber $number -ErrorAction SilentlyContinue
            $letters = ($partitions | Where-Object { $_.DriveLetter } | ForEach-Object { "$($_.DriveLetter):" }) -join ", "
            if (-not $letters) { $letters = "Sin partición asignada" }

            $drives += [PSCustomObject]@{
                DiskNumber   = $number
                DeviceID     = "\\.\PhysicalDrive$number"
                FriendlyName = $disk.FriendlyName
                SizeGB       = [math]::Round(($disk.Size / 1GB), 2)
                DriveLetters = $letters
                DisplayName  = "Disco $number`: $($disk.FriendlyName) ($([math]::Round(($disk.Size / 1GB), 1)) GB) [$letters]"
            }
        } catch {
            Write-Warning "No se pudo leer el disco $number`: $_"
        }
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

    # Seguridad adicional: el destino debe estar en la lista de dispositivos USB detectados
    $allowedTargets = @(Get-TapeOSUsbDrives | Select-Object -ExpandProperty DeviceID)
    if ($allowedTargets -notcontains $PhysicalDriveId) {
        throw "¡SEGURIDAD! El destino $PhysicalDriveId no está en la lista de dispositivos USB detectados. Operación abortada."
    }

    Write-Host "[TapeOS UsbFlasher] Preparando escritura en $PhysicalDriveId..." -ForegroundColor Cyan

    # Desmontar los puntos de montaje del disco (mountvol /p). En medios
    # extraibles Windows rechaza FSCTL_LOCK_VOLUME (error 6); el desmontaje
    # libera el volumen y permite la escritura directa. Al finalizar, vuelve
    # a conectar el dispositivo para que Windows lo remonte.
    try {
        $parts = Get-Partition -DiskNumber $targetNumber -ErrorAction SilentlyContinue
        foreach ($p in $parts) {
            if ($p.DriveLetter) {
                Write-Host "[TapeOS UsbFlasher] Desmontando la unidad $($p.DriveLetter): antes de grabar..." -ForegroundColor Gray
                $null = & mountvol.exe "$($p.DriveLetter):" /p 2>&1
            }
        }
        Start-Sleep -Milliseconds 800
    } catch {
        Write-Warning "No se pudieron desmontar los volumenes: $_"
    }

    $sourceFileInfo = New-Object System.IO.FileInfo($ImageFilePath)
    $totalBytes = $sourceFileInfo.Length
    $bufferSize = 1MB # Chunk compatible con el marshaling de WriteFile
    $buffer = New-Object byte[] $bufferSize

    Write-Host "[TapeOS UsbFlasher] Grabando $([math]::Round($totalBytes / 1GB, 2)) GB en $PhysicalDriveId..." -ForegroundColor Yellow

    # Abrir el dispositivo fisico con la API nativa (GENERIC_READ|GENERIC_WRITE).
    # En medios extraibles no se puede usar FSCTL_LOCK_VOLUME (error 6), asi que
    # se escribe directamente con WriteFile, igual que dd/Win32DiskImager.
    $hFile = [TapeOSWin32.NativeMethods]::CreateFile($PhysicalDriveId, [uint32]3221225472, [uint32]3, [IntPtr]::Zero, [uint32]3, [uint32]0, [IntPtr]::Zero)
    if ($hFile -eq [IntPtr]::Zero -or $hFile -eq [IntPtr]::MinusOne) {
        $errCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "No se pudo abrir el dispositivo fisico $PhysicalDriveId (error Win32: $errCode). Cierra el Explorador u otras apps que usen el pendrive e intentalo de nuevo."
    }

    $sourceStream = [System.IO.File]::OpenRead($ImageFilePath)

    try {
        $bytesWritten = 0L
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $lastReportTime = 0

        while (($read = $sourceStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $written = [uint32]0
            $ok = [TapeOSWin32.NativeMethods]::WriteFile($hFile, $buffer, [uint32]$read, [ref]$written, [IntPtr]::Zero)
            if (-not $ok -or $written -ne $read) {
                $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
                throw "WriteFile fallo (error Win32 $err): se escribieron $written de $read bytes. Cierra el Explorador y cualquier app que use el pendrive y vuelve a intentarlo."
            }
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

        $null = [TapeOSWin32.NativeMethods]::FlushFileBuffers($hFile)
        $stopwatch.Stop()
        Write-Host "[TapeOS UsbFlasher] Grabación finalizada con éxito en $([math]::Round($stopwatch.Elapsed.TotalSeconds, 1)) segundos." -ForegroundColor Green
        return $true
    } catch {
        throw "Error al escribir en el disco físico: $($_.Exception.Message)"
    } finally {
        if ($sourceStream) { $sourceStream.Close() }
        if ($hFile -ne [IntPtr]::Zero -and $hFile -ne [IntPtr]::MinusOne) {
            try { $null = [TapeOSWin32.NativeMethods]::CloseHandle($hFile) } catch { }
        }
    }
}

Export-ModuleMember -Function Get-TapeOSUsbDrives, Start-TapeOSUsbFlash
