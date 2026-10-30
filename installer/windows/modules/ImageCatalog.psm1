<#
.SYNOPSIS
    Catalogo de imagenes TapeOS servidas por HTTP (NAS propio, URL configurable).
.DESCRIPTION
    Descarga la imagen preconstruida (.img.gz) de la board elegida, verifica su
    SHA256 y la descomprime. NO necesita WSL en el equipo destino.
#>

function Get-TapeOSImagesBaseUrl {
    $candidates = @(
        (Join-Path $PSScriptRoot "..\assets\tapeos-config.json"),
        "C:\TapeOS\tapeos-config.json",
        "G:\TapeOS\tapeos-config.json"
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) {
            try {
                $cfg = Get-Content -LiteralPath $c -Raw | ConvertFrom-Json
                if ($cfg.imagesBaseUrl) { return $cfg.imagesBaseUrl.TrimEnd('/') + '/'}
            } catch { }
        }
    }
    return "https://pelotxo.synology.me/tapeos/"
}

function Set-TapeOSTlsDefault { try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::SystemDefault } catch { } }

function Get-TapeOSImageCatalog {
    param([string]$BaseUrl)
    Set-TapeOSTlsDefault
    try {
        $r = Invoke-WebRequest -Uri ($BaseUrl + "images.json") -UseBasicParsing -TimeoutSec 25
        $content = [System.Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
        $content = $content.TrimStart([char]0xFEFF)
        return ($content | ConvertFrom-Json)
    } catch { return $null }
}

function Get-TapeOSRemoteImage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Codename,
        [string]$BaseUrl,
        [string]$Version = "full",
        [string]$DestDir = "C:\TapeOS\images",
        [scriptblock]$ProgressCallback = $null
    )
    if (-not $BaseUrl) { $BaseUrl = Get-TapeOSImagesBaseUrl }
    $cat = Get-TapeOSImageCatalog -BaseUrl $BaseUrl
    if (-not $cat -or -not $cat.images) { throw "No se pudo obtener el catalogo de imagenes de $BaseUrl"}
    $entry = $cat.images | Where-Object { $_.version -eq $Version -and $_.board -eq $Codename } | Select-Object -First 1
    if (-not $entry) { throw "No hay imagen para la board '$Codename'en el catalogo."}
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    $gzPath = Join-Path $DestDir $entry.file
    $imgPath = $gzPath -replace '\.gz$', ''
    if (Test-Path -LiteralPath $imgPath) { return $imgPath }
    if (-not (Test-Path -LiteralPath $gzPath)) {
        Set-TapeOSTlsDefault
        $url = $BaseUrl + $entry.file
        Write-Host "[TapeOS] Descargando $url ..."
        $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
        if ($curl) {
            & curl.exe -sS -L -o $gzPath $url
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $gzPath)) { throw "Descarga fallida (curl exit $LASTEXITCODE)"}
        } else {
            $script:dlDone = $false
            $wc = New-Object System.Net.WebClient
            $wc.add_DownloadProgressChanged({
                param($s, $e)
                if ($ProgressCallback) {
                    $mb = [math]::Round($e.BytesReceived / 1MB, 0)
                    $tot = [math]::Round($e.TotalBytesToReceive / 1MB, 0)
                    & $ProgressCallback ([math]::Round($e.ProgressPercentage, 0)) $mb $tot
                }
            })
            $wc.add_DownloadFileCompleted({ $script:dlDone = $true })
            $wc.DownloadFileAsync($url, $gzPath)
            while (-not $script:dlDone) { Start-Sleep -Milliseconds 300 }
            $wc.Dispose()
        }
    }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $gzPath).Hash.ToLower()
    if ($hash -ne $entry.sha256.ToLower()) { Remove-Item -LiteralPath $gzPath -Force; throw "SHA256 de $($entry.file) no coincide: $hash"}
    Write-Host "[TapeOS] Descomprimiendo $($entry.file) ..."
    $in = [System.IO.File]::OpenRead($gzPath)
    $out = [System.IO.File]::Create($imgPath)
    $gz = New-Object System.IO.Compression.GZipStream($in, [System.IO.Compression.CompressionMode]::Decompress)
    $gz.CopyTo($out)
    $gz.Dispose(); $out.Dispose(); $in.Dispose()
    Remove-Item -LiteralPath $gzPath -Force -ErrorAction SilentlyContinue
    return $imgPath
}

# =============================================================================
# Base del sistema Free: build segun CPU y generacion automatica de la imagen
# =============================================================================

function Get-TapeOSBaseBuild {
    param([object]$HwReport)
    # 'apu' para CPUs AMD, 'iris' para Intel (u otras): la build de la base se
    # elige por la plataforma de la CPU, no por la GPU dedicada.
    $mfr = ''
    if ($HwReport) {
        if ($HwReport.CPU) { $mfr = [string]$HwReport.CPU.Manufacturer }
        elseif ($HwReport.PSObject.Properties['CpuManufacturer']) { $mfr = [string]$HwReport.CpuManufacturer }
    }
    if ($mfr -eq 'AMD') { return 'apu' }
    return 'iris'
}

function Get-TapeOSBaseBuildName {
    param([string]$Build)
    if ($Build -eq 'apu') { return 'APU' }
    return 'Iris'
}

function Get-TapeOSFreeImageLocal {
    # Imagen Free ya generada para este build (la mas reciente).
    param([string]$Build)
    $name = Get-TapeOSBaseBuildName -Build $Build
    $dirs = @('C:\TapeOS\images', 'G:\TapeOS\dist', (Join-Path $PSScriptRoot '..\assets'))
    foreach ($d in $dirs) {
        $c = Get-ChildItem -Path (Join-Path $d ("TapeOS-Free-*" + $name + "*.img")) -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($c) { return $c.FullName }
    }
    return $null
}

function Get-TapeOSBaseBin {
    # .bin de la base ya descomprimido (en C:\TapeOS\work o dist).
    param([string]$Build)
    $dirs = @('C:\TapeOS\work', 'G:\TapeOS\dist')
    foreach ($d in $dirs) {
        $c = Get-ChildItem -Path $d -Recurse -Filter ("FydeOS_for_PC_" + $Build + "_*bin") -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($c) { return $c.FullName }
    }
    return $null
}

function Get-TapeOSBaseZip {
    # .zip de la base (descargado o colocado por el usuario).
    param([string]$Build)
    $dirs = @('C:\TapeOS\downloads', 'C:\TapeOS\work', 'G:\TapeOS\dist')
    foreach ($d in $dirs) {
        $c = Get-ChildItem -Path $d -Recurse -Filter ("FydeOS_for_PC_" + $Build + "_*.zip") -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($c) { return $c.FullName }
    }
    return $null
}

function Expand-TapeOSBaseZip {
    param([string]$ZipPath, [string]$DestDir)
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
    if ($tar) {
        & tar.exe -xf $ZipPath -C $DestDir
        if ($LASTEXITCODE -ne 0) { throw "tar.exe fallo al descomprimir $ZipPath" }
    } else {
        Expand-Archive -LiteralPath $ZipPath -DestinationPath $DestDir -Force
    }
    $bin = Get-ChildItem -Path $DestDir -Filter '*.bin' -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $bin) { throw "No se encontro el .bin dentro de $ZipPath" }
    return $bin.FullName
}

function Test-TapeOSWslRoot {
    try {
        $out = (& wsl.exe -u root -e id -u 2>$null | Out-String).Trim()
        return ($out -eq '0')
    } catch { return $false }
}

function ConvertTo-TapeOSWslPath {
    param([string]$WinPath)
    $full = [System.IO.Path]::GetFullPath($WinPath)
    $drive = $full.Substring(0, 1).ToLower()
    $rest = $full.Substring(2).Replace('\', '/')
    return "/mnt/$drive$rest"
}

function Invoke-TapeOSFreeImageBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$BinPath,
        [string]$Options = 'no_google_play',
        [Parameter(Mandatory=$true)][string]$OutImgPath,
        [scriptblock]$ProgressCallback = $null
    )
    if (-not (Test-TapeOSWslRoot)) { throw "WSL no esta disponible con acceso root: no se puede generar la imagen." }
    $scriptPath = $null
    foreach ($c in @('G:\TapeOS\core\free\apply-free.sh', (Join-Path $PSScriptRoot '..\..\..\core\free\apply-free.sh'))) {
        if (Test-Path -LiteralPath $c) { $scriptPath = $c; break }
    }
    if (-not $scriptPath) { throw "No se encontro core/free/apply-free.sh." }
    $wslBin = ConvertTo-TapeOSWslPath -WinPath $BinPath
    $wslOut = ConvertTo-TapeOSWslPath -WinPath $OutImgPath
    $wslScript = ConvertTo-TapeOSWslPath -WinPath $scriptPath

    # Fases del script -> porcentaje aproximado para la barra
    $phaseMap = [ordered]@{
        'Copiando imagen de trabajo' = 6
        'Extrayendo el rootfs'        = 22
        'Recreando ROOT-A'            = 42
        'Copiando el rootfs'          = 55
        'Aplicando capa'              = 75
        'Sin logo de arranque'        = 88
        'Verificando'                 = 92
        'TAPEOS-FREE-LISTA'           = 100
    }
    $phases = @($phaseMap.Keys)

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'wsl.exe'
    $psi.Arguments = "-u root -e bash `"$wslScript`" `"$wslBin`" `"$Options`" `"$wslOut`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)

    $action = {
        $line = [string]$EventArgs.Data
        if ($line -and $ProgressCallback) {
            $pct = -1
            foreach ($k in $phases) {
                if ($line -match [regex]::Escape($k)) { $pct = $phaseMap[$k]; break }
            }
            & $ProgressCallback $pct $line
        }
    }
    $cb = Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -Action $action
    $null = $proc.BeginOutputReadLine()
    $null = $proc.BeginErrorReadLine()
    $proc.WaitForExit()
    Start-Sleep -Milliseconds 300
    Unregister-Event -SourceIdentifier $cb.Name -ErrorAction SilentlyContinue
    if ($proc.ExitCode -ne 0) { throw "La generacion de la imagen Free fallo (exit $($proc.ExitCode))." }
    if (-not (Test-Path -LiteralPath $OutImgPath)) { throw "No se genero la imagen de salida: $OutImgPath" }
    return $OutImgPath
}

Export-ModuleMember -Function Get-TapeOSImagesBaseUrl, Get-TapeOSImageCatalog, Get-TapeOSRemoteImage,
    Get-TapeOSBaseBuild, Get-TapeOSBaseBuildName, Get-TapeOSFreeImageLocal,
    Get-TapeOSBaseBin, Get-TapeOSBaseZip, Expand-TapeOSBaseZip,
    Test-TapeOSWslRoot, ConvertTo-TapeOSWslPath, Invoke-TapeOSFreeImageBuild