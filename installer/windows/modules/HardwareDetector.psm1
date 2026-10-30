<#
.SYNOPSIS
    Módulo de Detección de Hardware para TapeOS
.DESCRIPTION
    Detecta arquitectura de CPU, generación, firmware (UEFI/BIOS), BitLocker,
    almacenamiento y recomienda el perfil óptimo de ChromeOS / TapeOS.
#>

function Get-TapeOSWifiOption {
    <#
    .SYNOPSIS
        Mapea un adaptador WiFi (nombre + vendor ID) a la opción de framework
        de TapeOS que lo parchea (iwlwifi_backport, broadcom_wl, rtl*, ...).
    #>
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$VendorId
    )

    $vid = $VendorId.ToUpper()
    $n = $Name.ToLower()

    if ($vid -eq '14E4') {
        # Broadcom: chips FullMAC modernos (4360/4352/...) usan brcmfmac; los antiguos usan wl
        if ($n -match '436|435') { return 'brcmfmac'}
        return 'broadcom_wl'
    }
    if ($vid -eq '8086') { return 'iwlwifi_backport'}

    switch -Regex ($n) {
        '8188eu'{ return 'rtl8188eu'}
        '8188fu'{ return 'rtl8188fu'}
        '8192eu'{ return 'rtl8192eu'}
        '8723bs'{ return 'rtl8723bs'}
        '8723bu'{ return 'rtl8723bu'}
        '8723de'{ return 'rtl8723de'}
        '8723du'{ return 'rtl8723du'}
        '8812au'{ return 'rtl8812au'}
        '8814au'{ return 'rtl8814au'}
        '8821ce'{ return 'rtl8821ce'}
        '8821cu'{ return 'rtl8821cu'}
        '8851|8852'{ return 'rtl885xxx'}
        'b82c|8822bu|8811bu'{ return 'rtl88x2bu'}
    }

    # Qualcomm Atheros / MediaTek / Ralink: soportados por el kernel TapeOS sin parche extra
    return ''
}

function Get-TapeOSHardwareReport {
    [CmdletBinding()]
    param()

    Write-Verbose "Analizando hardware del sistema..."

    # 1. Detección de CPU
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $cpuName = $cpu.Name.Trim()
    $cpuArch = $cpu.Architecture # 0=x86, 9=x64, 12=ARM64
    $cpuManufacturer = if ($cpu.Manufacturer -match 'Intel') { 'Intel'} elseif ($cpu.Manufacturer -match 'AMD') { 'AMD'} else { 'Other'}

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
        if ($cpuName -match 'Atom.*Z3'-or ($cpuArch -eq 0) -or (Test-Path "$env:SystemRoot\System32\bootia32.efi")) {
            $firmwareType = "UEFI_IA32"
        } else {
            $firmwareType = "UEFI_X64"
        }
    } elseif ($fwEnv -match 'Legacy'-or $fwEnv -match 'BIOS') {
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
        if ($blDrives | Where-Object { $_.ProtectionStatus -eq 'On'}) {
            $bitLockerActive = $true
        }
    } catch {
        $bitLockerActive = $false
    }

    # 5. Detección de GPU
    $gpuList = @()
    $gpus = Get-CimInstance -ClassName Win32_VideoController
    foreach ($g in $gpus) {
        $gpuVid = ''
        $m = [regex]::Match([string]$g.PNPDeviceID, 'VEN_([0-9A-Fa-f]{4})')
        if ($m.Success) { $gpuVid = $m.Groups[1].Value.ToUpper() }
        $gpuList += [PSCustomObject]@{
            Name = $g.Name
            VendorId = $gpuVid
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

    # 7. Red inalámbrica (WiFi)
    $wifiAdapters = @()
    Get-PnpDevice -Class Net -PresentOnly -ErrorAction SilentlyContinue | ForEach-Object {
        $pnp = $_
        $vm = [regex]::Match($pnp.InstanceId, 'VEN_([0-9A-Fa-f]{4})|VID_([0-9A-Fa-f]{4})')
        $vid = ''
        if ($vm.Success) { $vid = (($vm.Groups[1].Value) + ($vm.Groups[2].Value)).ToUpper() }
        $friendly = [string]$pnp.FriendlyName
        if ($friendly -match 'wi-?fi|wireless|802\.11|wlan'-and $friendly -notmatch 'virtual|direct') {
            $wifiAdapters += [PSCustomObject]@{
                Name            = $friendly
                VendorId        = $vid
                FrameworkOption = Get-TapeOSWifiOption -Name $friendly -VendorId $vid
            }
        }
    }

    # 8. Bluetooth
    $bluetoothAdapters = @()
    Get-PnpDevice -Class Bluetooth -PresentOnly -ErrorAction SilentlyContinue | ForEach-Object {
        $pnp = $_
        $vm = [regex]::Match($pnp.InstanceId, 'VEN_([0-9A-Fa-f]{4})|VID_([0-9A-Fa-f]{4})')
        $vid = ''
        if ($vm.Success) { $vid = (($vm.Groups[1].Value) + ($vm.Groups[2].Value)).ToUpper() }
        $friendly = [string]$pnp.FriendlyName
        $opt = ''
        if ($friendly -match 'RT3290|RT3298') { $opt = 'rtbth'}
        if ($friendly -notmatch 'enumerador|enumerator|protocolo|protocol|RFCOMM') {
            $bluetoothAdapters += [PSCustomObject]@{
                Name            = $friendly
                VendorId        = $vid
                FrameworkOption = $opt
            }
        }
    }

    # 9. Audio (códecs con parche ALSA UCM)
    $audioDevices = @()
    Get-PnpDevice -Class MEDIA -PresentOnly -ErrorAction SilentlyContinue | ForEach-Object {
        $friendly = [string]$_.FriendlyName
        $opt = ''
        if ($friendly -match 'ES8336|ESSX8336|Everest') { $opt = 'essx8336'}
        elseif ($friendly -match 'RT5640|RT5645|RT5651|RT5670|ES8316|CX2072|CX2073|ALC269|ALC283|ALC256|Smart Sound|SST') { $opt = 'legacy_audio_ucm'}
        if ($opt) {
            $audioDevices += [PSCustomObject]@{ Name = $friendly; FrameworkOption = $opt }
        }
    }

    # 10. Pantalla táctil (Surface IPTS/iTHC, Goodix)
    $touchDevices = @()
    Get-PnpDevice -Class HIDClass -PresentOnly -ErrorAction SilentlyContinue | ForEach-Object {
        $friendly = [string]$_.FriendlyName
        $opt = ''
        if ($friendly -match 'IPTS|iPTS') { $opt = 'ipts_touchscreen'}
        elseif ($friendly -match 'ITHC|iTHC') { $opt = 'ithc_touchscreen'}
        elseif ($friendly -match 'Goodix|GDIX') { $opt = 'goodix'}
        if ($opt) {
            $touchDevices += [PSCustomObject]@{ Name = $friendly; FrameworkOption = $opt }
        }
    }

    # 11. GPU dedicada (dGPU): NVIDIA siempre; AMD cuando el equipo es Intel+AMD
    #     o hay mas de una GPU (Optimus/switchable). AMD APU + AMD CPU no lo necesita.
    $dgpuOption = ''
    $hasNvidia = @($gpuList | Where-Object { $_.VendorId -eq '10DE'}).Count -gt 0
    $hasAmd = @($gpuList | Where-Object { $_.VendorId -eq '1002'}).Count -gt 0
    $amdNeedsDgpu = $hasAmd -and ($cpuManufacturer -eq 'Intel'-or @($gpuList).Count -gt 1)
    if ($hasNvidia -or $amdNeedsDgpu -or @($gpuList).Count -gt 1) { $dgpuOption = 'dgpu'}

    $macbookOption = ''
    try {
        $csManufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
        if ($csManufacturer -match 'Apple') { $macbookOption = 'macbook_trackpad'}
    } catch {
        $macbookOption = ''
    }

    # 12. Agregar parches de framework detectados (sin duplicados)
    $frameworkPatches = @()
    foreach ($w in $wifiAdapters) { if ($w.FrameworkOption) { $frameworkPatches += [PSCustomObject]@{ Option = $w.FrameworkOption; Component = "WiFi: $($w.Name)"} } }
    foreach ($b in $bluetoothAdapters) { if ($b.FrameworkOption) { $frameworkPatches += [PSCustomObject]@{ Option = $b.FrameworkOption; Component = "Bluetooth: $($b.Name)"} } }
    foreach ($a in $audioDevices) { $frameworkPatches += [PSCustomObject]@{ Option = $a.FrameworkOption; Component = "Audio: $($a.Name)"} }
    foreach ($t in $touchDevices) { $frameworkPatches += [PSCustomObject]@{ Option = $t.FrameworkOption; Component = "Tâttîh: $($t.Name)"} }
    if ($dgpuOption) {
        $dgpuDesc = if ($hasNvidia) { 'dGPU NVIDIA (renderiça la iGPU)'} elseif ($hasAmd) { 'dGPU AMD (renderiça kon amdgpu)'} else { 'dGPU (çwîtcheable)'}
        $frameworkPatches += [PSCustomObject]@{ Option = $dgpuOption; Component = $dgpuDesc }
    }
    if ($macbookOption) { $frameworkPatches += [PSCustomObject]@{ Option = $macbookOption; Component = 'MacBook (trâkpa Apple)'} }
    $frameworkPatches = @($frameworkPatches | Sort-Object Option -Unique)

    # Construir objeto resumen de hardware
    return [PSCustomObject]@{
        CPU = [PSCustomObject]@{
            Name = $cpuName
            Manufacturer = $cpuManufacturer
            Architecture = if ($cpuArch -eq 9) { "x64"} elseif ($cpuArch -eq 0) { "x86"} else { "Other"}
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
        BitLocker = [PSCustomObject]@{
            Status = if ($bitLockerActive) { 'Activo'} else { 'Inactivo'}
        }
        GPU = $gpuList
        Network = [PSCustomObject]@{
            WiFi = $wifiAdapters
            Bluetooth = $bluetoothAdapters
        }
        Audio = $audioDevices
        Touchscreen = $touchDevices
        FrameworkPatches = $frameworkPatches
        Storage = [PSCustomObject]@{
            PhysicalDisks = $disks
            Volumes = $volumes
        }
        Recommendations = [PSCustomObject]@{
            RecoveryCodename = $recommendedRecovery
            Kernel = $recommendedKernel
            RequiresLegacyPatches = $legacyDevice
            BootloaderProfile = if ($firmwareType -eq "BIOS_LEGACY") { "MBR_GRUB_I386"} elseif ($firmwareType -eq "UEFI_IA32") { "UEFI_IA32_GRUB"} else { "UEFI_X64_GRUB"}
        }
    }
}

Export-ModuleMember -Function Get-TapeOSHardwareReport
