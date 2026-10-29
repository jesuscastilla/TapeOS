#Requires -Version 5.1
<#
.SYNOPSIS
    Genera el ejecutable autocontenido TapeOS-Installer-<version>.exe con ps2exe.
.DESCRIPTION
    Empaqueta la GUI (TapeOS-Installer.ps1) y los 7 modulos de PowerShell en un
    unico .exe portable. El EXE no depende de asociaciones de archivos ni de la
    configuracion de PowerShell del equipo destino: extrae los scripts a
    %TEMP%\TapeOS-App y lanza la interfaz grafica.
.NOTES
    Requiere Windows PowerShell 5.1 (NO PowerShell 7): ps2exe usa el compilador
    C# de .NET Framework (CodeDOM), no disponible en PowerShell Core.
    ps2exe (MScholtes/PS2EXE) se distribuye bajo Microsoft Public License (Ms-PL).
#>
[CmdletBinding()]
param(
    [string]$Version = "0.0.0-alpha",
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"

# --- 1. Resolver rutas ---
if (-not $OutputDir) { $OutputDir = Join-Path (Split-Path -Parent $PSScriptRoot) "dist" }
$root = (Split-Path -Parent $PSScriptRoot)
$winDir = Join-Path $root "installer\windows"
$modDir = Join-Path $winDir "modules"
$assetDir = Join-Path $PSScriptRoot "assets"
if (-not (Test-Path $assetDir)) { New-Item -ItemType Directory -Path $assetDir -Force | Out-Null }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
$OutputDir = (Resolve-Path $OutputDir).Path

# --- 2. Icono (generarlo si no existe) ---
$iconPath = Join-Path $assetDir "tapeos.ico"
if (-not (Test-Path $iconPath)) {
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object System.Drawing.Bitmap(32, 32)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::FromArgb(26, 115, 232))
    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $dark = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(16, 60, 120))
    $g.FillEllipse($white, 5, 6, 10, 10)
    $g.FillEllipse($white, 17, 6, 10, 10)
    $g.FillEllipse($dark, 8, 9, 4, 4)
    $g.FillEllipse($dark, 20, 9, 4, 4)
    $g.FillRectangle($white, 5, 19, 22, 5)
    $g.Dispose()
    $hIcon = $bmp.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($hIcon)
    $fs = [System.IO.File]::Create($iconPath)
    $icon.Save($fs)
    $fs.Close()
    $icon.Dispose()
    $bmp.Dispose()
    Write-Host "[TapeOS] Icono generado: $iconPath"
}

# --- 3. Generar bundle autocontenido (GUI + modulos en base64) ---
function Get-Base64 {
    param([string]$Path)
    return [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path))
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('$ErrorActionPreference = ''Stop''')
[void]$sb.AppendLine('$appDir = Join-Path $env:TEMP ''TapeOS-App''')
[void]$sb.AppendLine('$modDir = Join-Path $appDir ''modules''')
[void]$sb.AppendLine('New-Item -ItemType Directory -Force -Path $modDir | Out-Null')
[void]$sb.AppendLine('')

Get-ChildItem -Path $modDir -Filter *.psm1 | Sort-Object Name | ForEach-Object {
    $b64 = Get-Base64 -Path $_.FullName
    [void]$sb.AppendLine("[System.IO.File]::WriteAllBytes((Join-Path `$modDir '$($_.Name)'), [Convert]::FromBase64String('$b64'))")
}

$mainPath = Join-Path $winDir "TapeOS-Installer.ps1"
$mainB64 = Get-Base64 -Path $mainPath
[void]$sb.AppendLine('')
[void]$sb.AppendLine('$mainPath = Join-Path $appDir ''TapeOS-Installer.ps1''')
[void]$sb.AppendLine("[System.IO.File]::WriteAllBytes(`$mainPath, [Convert]::FromBase64String('$mainB64'))")

# Logo de la marca para la cabecera de la GUI
$logoPng = Join-Path $assetDir "diplotech-logo-blanco.png"
if (Test-Path $logoPng) {
    $logoB64 = Get-Base64 -Path $logoPng
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('$assetsDir = Join-Path $appDir ''assets''')
    [void]$sb.AppendLine('New-Item -ItemType Directory -Force -Path $assetsDir | Out-Null')
    [void]$sb.AppendLine("[System.IO.File]::WriteAllBytes((Join-Path `$assetsDir 'diplotech-logo-blanco.png'), [Convert]::FromBase64String('$logoB64'))")
}

# Initramfs del framework TapeOS (si existe en dist): permite al instalador
# inyectarlo en la ESP del pendrive para el arranque de TapeOS.
$initramfsFile = Join-Path (Split-Path -Parent $PSScriptRoot) "dist\tapeos-initramfs.cpio.gz"
if (Test-Path $initramfsFile) {
    $initramfsB64 = Get-Base64 -Path $initramfsFile
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('$assetsDir = Join-Path $appDir ''assets''')
    [void]$sb.AppendLine('New-Item -ItemType Directory -Force -Path $assetsDir | Out-Null')
    [void]$sb.AppendLine("[System.IO.File]::WriteAllBytes((Join-Path `$assetsDir 'tapeos-initramfs.cpio.gz'), [Convert]::FromBase64String('$initramfsB64'))")
    Write-Host "[TapeOS] Initramfs del framework incluido en el bundle ($([math]::Round((Get-Item $initramfsFile).Length / 1MB, 1)) MB)."
} else {
    Write-Host "[TapeOS] AVISO: dist\tapeos-initramfs.cpio.gz no existe; el bundle se crea sin framework de arranque."
}

# Kernel Linux de PC para el framework TapeOS (si existe en dist)
$kernelFile = Join-Path (Split-Path -Parent $PSScriptRoot) "dist\tapeos-vmlinuz"
if (Test-Path $kernelFile) {
    $kernelB64 = Get-Base64 -Path $kernelFile
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('$assetsDir = Join-Path $appDir ''assets''')
    [void]$sb.AppendLine('New-Item -ItemType Directory -Force -Path $assetsDir | Out-Null')
    [void]$sb.AppendLine("[System.IO.File]::WriteAllBytes((Join-Path `$assetsDir 'tapeos-vmlinuz'), [Convert]::FromBase64String('$kernelB64'))")
    Write-Host "[TapeOS] Kernel Linux de PC incluido en el bundle ($([math]::Round((Get-Item $kernelFile).Length / 1MB, 1)) MB)."
} else {
    Write-Host "[TapeOS] AVISO: dist\tapeos-vmlinuz no existe; el bundle se crea sin kernel de PC."
}

[void]$sb.AppendLine('& $mainPath')
[void]$sb.AppendLine('exit $LASTEXITCODE')

$bundlePath = Join-Path $env:TEMP ("tapeos-bundle-" + [guid]::NewGuid().ToString("N") + ".ps1")
[System.IO.File]::WriteAllText($bundlePath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
Write-Host "[TapeOS] Bundle generado: $bundlePath ($([math]::Round((Get-Item $bundlePath).Length/1KB,1)) KB)"

# --- 4. ps2exe ---
if (-not (Get-Command ps2exe -ErrorAction SilentlyContinue)) {
    Write-Host "[TapeOS] Instalando modulo ps2exe desde PSGallery..."
    try {
        Install-Module -Name ps2exe -Scope CurrentUser -Force -ErrorAction Stop
    } catch {
        throw "No se pudo instalar ps2exe: $_"
    }
}

# Version en formato de 4 partes (FileVersion de Windows)
$clean = ($Version -replace '[^0-9.]', '').Trim('.')
$parts = @($clean.Split('.'))
$num4 = if ($parts.Count -ge 4) { $parts[3] } else { '0' }
$fileVersion = "{0}.{1}.{2}.{3}" -f $parts[0], $parts[1], $parts[2], $num4

$exeName = "TapeOS-Installer-$Version.exe"
$outPath = Join-Path $OutputDir $exeName
$ps2exeParams = @{
    inputFile   = $bundlePath
    outputFile  = $outPath
    noConsole   = $true
    iconFile    = $iconPath
    title       = "TapeOS Installer"
    description = "Suite automatizada de instalacion de ChromeOS (TapeOS) para PCs con EFI"
    product     = "TapeOS"
    company     = "TapeOS Contributors"
    copyright   = "Copyright (c) 2026 TapeOS Contributors"
    version     = $fileVersion
}
if ((Get-Command ps2exe).Parameters.ContainsKey('requireAdmin')) {
    $ps2exeParams.requireAdmin = $true
}

ps2exe @ps2exeParams

if (Test-Path $outPath) {
    Write-Host "[TapeOS] EXE generado: $outPath ($([math]::Round((Get-Item $outPath).Length/1KB,1)) KB)" -ForegroundColor Green
} else {
    throw "ps2exe no genero el EXE esperado en $outPath"
}