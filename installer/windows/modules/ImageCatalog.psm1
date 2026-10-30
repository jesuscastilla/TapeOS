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
                if ($cfg.imagesBaseUrl) { return $cfg.imagesBaseUrl.TrimEnd('/') + '/' }
            } catch { }
        }
    }
    return "https://pelotxo.synology.me/tapeos/"
}

function Get-TapeOSImageCatalog {
    param([string]$BaseUrl)
    try {
        $r = Invoke-WebRequest -Uri ($BaseUrl + "images.json") -UseBasicParsing -TimeoutSec 25
        return ($r.Content | ConvertFrom-Json)
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
    if (-not $cat -or -not $cat.images) { throw "No se pudo obtener el catalogo de imagenes de $BaseUrl" }
    $entry = $cat.images | Where-Object { $_.version -eq $Version } | Where-Object { if ($Version -eq "free") { $true } else { $_.board -eq $Codename } } | Select-Object -First 1
    if (-not $entry) { throw "No hay imagen para la board '$Codename' en el catalogo." }
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    $gzPath = Join-Path $DestDir $entry.file
    $imgPath = $gzPath -replace '\.gz$', ''
    if (Test-Path -LiteralPath $imgPath) { return $imgPath }
    if (-not (Test-Path -LiteralPath $gzPath)) {
        $url = $BaseUrl + $entry.file
        Write-Host "[TapeOS] Descargando $url ..."
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
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $gzPath).Hash.ToLower()
    if ($hash -ne $entry.sha256.ToLower()) { Remove-Item -LiteralPath $gzPath -Force; throw "SHA256 de $($entry.file) no coincide: $hash" }
    Write-Host "[TapeOS] Descomprimiendo $($entry.file) ..."
    $in = [System.IO.File]::OpenRead($gzPath)
    $out = [System.IO.File]::Create($imgPath)
    $gz = New-Object System.IO.Compression.GZipStream($in, [System.IO.Compression.CompressionMode]::Decompress)
    $gz.CopyTo($out)
    $gz.Dispose(); $out.Dispose(); $in.Dispose()
    Remove-Item -LiteralPath $gzPath -Force -ErrorAction SilentlyContinue
    return $imgPath
}

Export-ModuleMember -Function Get-TapeOSImagesBaseUrl, Get-TapeOSImageCatalog, Get-TapeOSRemoteImage