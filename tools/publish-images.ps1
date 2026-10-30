<#
.SYNOPSIS
    Publica las imagenes TapeOS (.img.gz) y el catalogo images.json en el NAS.
.DESCRIPTION
    Genera images.json (board, milestone, firmware, sha256, sizeMB) y sube todo
    por SCP (via WSL + sshpass) a la carpeta web del NAS. La contrasena se toma
    de la variable de entorno TAPEOOS_NAS_PASS (nunca se guarda en disco).
#>
param(
    [string]$NasHost = "pelotxo.synology.me",
    [string]$NasUser = "pelotxo",
    [string]$RemoteDir = "/volume1/web/tapeos"
)
$ErrorActionPreference = "Stop"
$dist = (Resolve-Path (Join-Path $PSScriptRoot "..\dist")).Path

# 1) Catalogo
$images = @(Get-ChildItem -Path (Join-Path $dist "TapeOS-*.img.gz") | ForEach-Object {
    if ($_.Name -match '^TapeOS-([a-z0-9]+)-M(\d+)-(.*)\.img\.gz$') {
        [PSCustomObject]@{
            board    = $Matches[1]
            milestone = [int]$Matches[2]
            firmware = "hybrid"
            version  = "free"
            file     = $_.Name
            sha256   = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLower()
            sizeMB   = [math]::Round($_.Length / 1MB, 0)
        }
    }
})
if ($images.Count -eq 0) { throw "No hay imagenes TapeOS-*.img.gz en $dist" }
$cat = [PSCustomObject]@{ generated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss"); images = $images }
$catJson = $cat | ConvertTo-Json -Depth 4
$catPath = Join-Path $dist "images.json"
[System.IO.File]::WriteAllText($catPath, $catJson, (New-Object System.Text.UTF8Encoding($true)))
Write-Host "[TapeOS] Catalogo: $catPath"

# 2) Subida por WSL + sshpass
if (-not $env:TAPEOOS_NAS_PASS) { throw "Define TAPEOOS_NAS_PASS (contrasena SSH del NAS) y vuelve a ejecutar." }
$env:WSLENV = "TAPEOOS_NAS_PASS"
$wsl = @(
    "export DEBIAN_FRONTEND=noninteractive",
    "command -v sshpass >/dev/null 2>&1 || apt-get install -y sshpass >/dev/null 2>&1",
    "export SSHPASS=`"$env:TAPEOOS_NAS_PASS`"",
    "sshpass -e ssh -o StrictHostKeyChecking=accept-new -p 22 $NasUser@$NasHost `"mkdir -p $RemoteDir`"",
    "for f in images.json `$(ls /mnt/g/TapeOS/dist/*.img.gz | xargs -n1 basename); do sshpass -e scp -o StrictHostKeyChecking=accept-new -P 22 /mnt/g/TapeOS/dist/`$f $NasUser@$NasHost:$RemoteDir/ || exit 1; done",
    "echo SUBIDA-COMPLETADA"
) -join '; '
& wsl.exe -u root -e bash -c $wsl
if ($LASTEXITCODE -ne 0) { throw "La subida al NAS fallo." }
Write-Host "[TapeOS] Imagenes publicadas en $NasHost:$RemoteDir"