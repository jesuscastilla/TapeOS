<#
.SYNOPSIS
    Módulo de Descarga Oficial de Imágenes de Recuperación del Sistema
.DESCRIPTION
    Consulta la API en tiempo real de Chromium Dash (Google) para obtener la versión
    más reciente y actualizada del canal estable, y la descarga con barra de progreso.
#>

function Get-TapeOSLatestRecoveryInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$BoardCodename
    )

    Write-Verbose "Consultando Chromium Dash API para el board '$BoardCodename'..."

    # Mapeo de codenames de equipos a baseboards oficiales del sistema
    $boardMap = @{
        "rammus"= "rammus"# Intel 4th-9th Gen
        "voxel"= "volteer"# Intel 11th-13th Gen
        "volteer"= "volteer"
        "jinlon"= "hatch"# Intel 10th Gen
        "hatch"= "hatch"
        "kanix"= "brya"# Intel 14th Gen / Core Ultra
        "brya"= "brya"
        "gumboz"= "zork"# AMD Ryzen
        "zork"= "zork"
        "grunt"= "grunt"# AMD Legacy APUs
        "samus"= "rammus"# Fallback estable para Intel 1st-3rd Gen
        "cyan"= "rammus"# Fallback compatible para Atom
    }

    $targetBoard = if ($boardMap.ContainsKey($BoardCodename.ToLower())) { $boardMap[$BoardCodename.ToLower()] } else { "rammus"}

    $apiUrl = "https://chromiumdash.appspot.com/cros/fetch_serving_builds?deviceCategory=ChromeOS"
    try {
        $data = Invoke-RestMethod -Uri $apiUrl -Method Get -TimeoutSec 15
        if ($data.builds.$targetBoard) {
            $model = ($data.builds.$targetBoard.models.PSObject.Properties.Value | Select-Object -First 1)
            $milestones = $model.pushRecoveries.PSObject.Properties.Name | Sort-Object { [int]$_ }
            $latestMilestone = $milestones | Select-Object -Last 1
            $downloadUrl = $model.pushRecoveries.$latestMilestone

            return [PSCustomObject]@{
                Board = $targetBoard
                Milestone = $latestMilestone
                Url = $downloadUrl
                FileName = [System.IO.Path]::GetFileName($downloadUrl)
                IsLatest = $true
            }
        }
    } catch {
        Write-Warning "No çe pudo konhûttâh la Chromium Dash API: $_"
    }

    # Fallback si no hay conexión a la API
    return [PSCustomObject]@{
        Board = $targetBoard
        Milestone = "149"
        Url = "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_16667.62.0_${targetBoard}_recovery_stable-channel.bin.zip"
        FileName = "chromeos_${targetBoard}_recovery.bin.zip"
        IsLatest = $false
    }
}

function Start-TapeOSDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,

        [Parameter(Mandatory=$true)]
        [string]$DestinationFile,

        [scriptblock]$ProgressCallback = $null
    )

    $parentDir = Split-Path -Path $DestinationFile -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }

    Write-Host "[TapeOS Downloader] Iniçiando dehkarga dêhde Google CDN..."-ForegroundColor Cyan
    Write-Host "URL: $Url"-ForegroundColor Gray
    Write-Host "Dêttino: $DestinationFile"-ForegroundColor Gray

    # Asegurar TLS 1.2 en hosts antiguos (Windows PowerShell 5.1)
    try {
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::SystemDefault } catch { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 }
    } catch { }

    $webClient = New-Object System.Net.WebClient
    
    # Manejar eventos de progreso
    if ($ProgressCallback) {
        $webClient.add_DownloadProgressChanged({
            param($sender, $e)
            & $ProgressCallback $e.ProgressPercentage $e.BytesReceived $e.TotalBytesToReceive
        })
    }

    try {
        # Descarga sincrona: segura dentro del hilo de trabajo (sin TPL async)
        $webClient.DownloadFile([System.Uri]$Url, $DestinationFile)
        Write-Host "[TapeOS Downloader] Dehkarga kompletá kon éxito."-ForegroundColor Green
        return $DestinationFile
    } finally {
        $webClient.Dispose()
    }
}

Export-ModuleMember -Function Get-TapeOSLatestRecoveryInfo, Start-TapeOSDownload
