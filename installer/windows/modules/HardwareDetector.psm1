<#
.SYNOPSIS
    Módulo de Detección de Hardware para TapeOS
.DESCRIPTION
    Detecta arquitectura de CPU, generación, firmware (UEFI/BIOS), BitLocker,
    almacenamiento y recomienda el perfil óptimo de ChromeOS / TapeOS.
#>

function Get-TapeOSHardwareReport {
    [CmdletBinding()]
    param()

    Write-Verbose "Analizando hardware del sistema..."

    # 1. Detección de CPU
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $cpuName = $cpu.Name.Trim()
    $cpuArch = $cpu.Architecture # 0=x86, 9=x64, 12=ARM64
    $cpuManufacturer = if ($cpu.Manufacturer -match 'Intel') { 'Intel' } elseif ($cpu.Manufacturer -match 'AMD') { 'AMD' } else { 'Other' }

    # Determinar generación de CPU y arquitectura
    $cpuGen = "Unknown"
    $recommendedRecovery = "rammus"
    $recommendedKernel = "modern"
    $legacyDevice = $false

    if ($cpuManufacturer -eq 'Intel') {
        if ($cpuName -match 'Core.*Ultra|i[3579]-1[4-9]\d{2,3}') {
            $cpuGen = "Intel 14th Gen / Core Ultra (Meteor Lake / Arrow Lake)"
            $recommendedRecovery = "kanix"
            $recommendedKernel = "kernel-6.6"
        } elseif ($cpuName -match 'i[3579]-1[123]\d{2,3}') {
            $cpuGen = "Intel 11th-13th Gen (Tiger Lake / Alder Lake / Raptor Lake)"
            $recommendedRecovery = "voxel"
            $recommendedKernel = "kernel-6.1"
        } elseif ($cpuName -match 'i[3579]-10\d{2,3}') {
            $cpuGen = "Intel 10th Gen (Comet Lake / Ice Lake)"
            $recommendedRecovery = "jinlon"
            $recommendedKernel = "kernel-6.1"
        } elseif ($cpuName -match 'i[3579]-[89]\d{2,3}') {
            $cpuGen = "Intel 8th-9th Gen (Coffee Lake / Whiskey Lake)"
            $recommendedRecovery = "rammus"
            $recommendedKernel = "kernel-5.15"
        } elseif ($cpuName -match 'i[3579]-[4567]\d{2,3}') {
            $cpuGen = "Intel 4th-7th Gen (Haswell / Broadwell / Skylake / Kaby Lake)"
            $recommendedRecovery = "rammus"
            $recommendedKernel = "kernel-5.10"
            $legacyDevice = $true
        } elseif ($cpuName -match 'i[3579]-[23]\d{2,3}|Core.*2|Pentium|Celeron') {
            $cpuGen = "Intel Legacy (Sandy Bridge / Ivy Bridge / Pre-Haswell)"
            $recommendedRecovery = "samus"
            $recommendedKernel = "kernel-legacy-5.4"
            $legacyDevice = $true
        } elseif ($cpuName -match 'Atom.*(Z3|x5|x7)|Celeron.*(N2|N3)') {
            $cpuGen = "Intel Atom / Celeron Low-Power (Bay Trail / Cherry Trail / Braswell)"
            $recommendedRecovery = "cyan"
            $recommendedKernel = "kernel-legacy-4.19"
            $legacyDevice = $true
        } else {
            $cpuGen = "Intel Genérico"
            $recommendedRecovery = "rammus"
            $recommendedKernel = "kernel-5.10"
        }
    } elseif ($cpuManufacturer -eq 'AMD') {
        if ($cpuName -match 'Ryzen') {
            $cpuGen = "AMD Ryzen (Zen / Zen+ / Zen 2 / Zen 3 / Zen 4)"
            $recommendedRecovery = "gumboz"
            $recommendedKernel = "kernel-6.1"
        } elseif ($cpuName -match 'A[4689]|Athlon|FX-|E[12]-') {
            $cpuGen = "AMD Legacy APU (Stoney Ridge / Carrizo / Excavator)"
            $recommendedRecovery = "grunt"
            $recommendedKernel = "kernel-legacy-5.4"
            $legacyDevice = $true
        } else {
            $cpuGen = "AMD Genérico"
            $recommendedRecovery = "grunt"
            $recommendedKernel = "kernel-legacy-5.4"
            $legacyDevice = $true
        }
    }

    # 2. Detección de Firmware (UEFI vs BIOS)
    $firmwareType = "Unknown"
    $fwEnv = $env:firmware_type

    if ($fwEnv -match 'UEFI') {
        # Comprobar posibles tablets con UEFI de 32 bits (Atom Z3735F, etc.)
        if ($cpuName -match 'Atom.*Z3' -or ($cpuArch -eq 0) -or (Test-Path "$env:SystemRoot\System32\bootia32.efi")) {
            $firmwareType = "UEFI_IA32"
        } else {
            $firmwareType = "UEFI_X64"
        }
    } elseif ($fwEnv -match 'Legacy' -or $fwEnv -match 'BIOS') {
        $firmwareType = "BIOS_LEGACY"
        $legacyDevice = $true
    } else {
        # Fallback de detección si la variable no está definida
        try {
            $bcdPath = ((bcdedit.exe /enum '{current}') -match 'path')[0]
            if ($bcdPath -match '\.efi') {
                $firmwareType = "UEFI_X64"
            } elseif ($bcdPath -match '\.exe') {
                $firmwareType = "BIOS_LEGACY"
                $legacyDevice = $true
            }
        } catch {
            if (Test-Path "$env:SystemRoot\System32\bootmgfw.efi") {
                $firmwareType = "UEFI_X64"
            } else {
                $firmwareType = "BIOS_LEGACY"
                $legacyDevice = $true
            }
        }
    }

    # 3. Estado de Secure Boot
    $secureBootEnabled = $false
    try {
        $sb = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
        if ($sb -eq $true) { $secureBootEnabled = $true }
    } catch {
        # Secure Boot no disponible (probablemente BIOS Legacy o desactivado)
        $secureBootEnabled = $false
    }

    # 4. Estado de BitLocker
    $bitLockerActive = $false
    try {
        $blDrives = Get-BitLockerVolume -ErrorAction SilentlyContinue
        if ($blDrives | Where-Object { $_.ProtectionStatus -eq 'On' }) {
            $bitLockerActive = $true
        }
    } catch {
        $bitLockerActive = $false
    }

    # 5. Detección de GPU
    $gpuList = @()
    $gpus = Get-CimInstance -ClassName Win32_VideoController
    foreach ($g in $gpus) {
        $gpuList += [PSCustomObject]@{
            Name = $g.Name
            DriverVersion = $g.DriverVersion
            AdapterRAM_MB = [math]::Round(($g.AdapterRAM / 1MB), 0)
        }
    }

    # 6. Almacenamiento y Unidades
    $disks = @()
    $physicalDisks = Get-CimInstance -ClassName Win32_DiskDrive
    foreach ($d in $physicalDisks) {
        $disks += [PSCustomObject]@{
            DeviceID = $d.DeviceID
            Model = $d.Model
            InterfaceType = $d.InterfaceType
            Size_GB = [math]::Round(($d.Size / 1GB), 1)
            IsRemovable = ($d.InterfaceType -match 'USB')
        }
    }

    $volumes = @()
    $logicalVolumes = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3 or DriveType=2"
    foreach ($v in $logicalVolumes) {
        $volumes += [PSCustomObject]@{
            DriveLetter = $v.DeviceID
            VolumeName = $v.VolumeName
            FileSystem = $v.FileSystem
            Total_GB = [math]::Round(($v.Size / 1GB), 1)
            Free_GB = [math]::Round(($v.FreeSpace / 1GB), 1)
        }
    }

    # Construir objeto resumen de hardware
    return [PSCustomObject]@{
        CPU = [PSCustomObject]@{
            Name = $cpuName
            Manufacturer = $cpuManufacturer
            Architecture = if ($cpuArch -eq 9) { "x64" } elseif ($cpuArch -eq 0) { "x86" } else { "Other" }
            Generation = $cpuGen
            IsLegacy = $legacyDevice
        }
        Firmware = [PSCustomObject]@{
            Type = $firmwareType # UEFI_X64, UEFI_IA32, BIOS_LEGACY
            SecureBoot = $secureBootEnabled
            IsLegacyBIOS = ($firmwareType -eq "BIOS_LEGACY")
            IsIA32UEFI = ($firmwareType -eq "UEFI_IA32")
        }
        Security = [PSCustomObject]@{
            BitLockerActive = $bitLockerActive
        }
        GPU = $gpuList
        Storage = [PSCustomObject]@{
            PhysicalDisks = $disks
            Volumes = $volumes
        }
        Recommendations = [PSCustomObject]@{
            RecoveryCodename = $recommendedRecovery
            Kernel = $recommendedKernel
            RequiresLegacyPatches = $legacyDevice
            BootloaderProfile = if ($firmwareType -eq "BIOS_LEGACY") { "MBR_GRUB_I386" } elseif ($firmwareType -eq "UEFI_IA32") { "UEFI_IA32_GRUB" } else { "UEFI_X64_GRUB" }
        }
    }
}

Export-ModuleMember -Function Get-TapeOSHardwareReport
