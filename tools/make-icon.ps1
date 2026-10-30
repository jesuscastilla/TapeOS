#Requires -Version 5.1
<#
.SYNOPSIS
    Genera un archivo .ico multi-tamano a partir de un PNG.
.DESCRIPTION
    Lee un PNG (preferiblemente cuadrado de 256x256 o mas) y genera un ICO con
    los tamanos 256, 64, 48, 32 y 16 px (datos PNG comprimidos, 32 bpp).
    Compatible con Windows PowerShell 5.1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePng,

    [Parameter(Mandatory = $true)]
    [string]$OutputIco
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
if (-not (Test-Path $SourcePng)) { throw "PNG no encontrado: $SourcePng" }

$src = [System.Drawing.Image]::FromFile((Resolve-Path $SourcePng).Path)
$sizes = @(256, 64, 48, 32, 16)

# 1a pasada: escalar y guardar cada tamano como PNG en memoria
$pngs = @()
foreach ($s in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap($src, [int]$s, [int]$s)
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngs += , $ms.ToArray()
    $ms.Dispose()
    $bmp.Dispose()
}
$src.Dispose()

# 2a pasada: escribir el ICO (cabecera + directorio + datos)
$out = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($out)
$bw.Write([uint16]0)              # reservado
$bw.Write([uint16]1)              # tipo: icono
$bw.Write([uint16]$pngs.Count)    # numero de imagenes
$offset = 6 + (16 * $pngs.Count)
for ($i = 0; $i -lt $pngs.Count; $i++) {
    $s = $sizes[$i]
    $dim = if ($s -ge 256) { 0 } else { $s }
    $bw.Write([byte]$dim)         # ancho
    $bw.Write([byte]$dim)         # alto
    $bw.Write([byte]0)            # paleta de colores
    $bw.Write([byte]0)            # reservado
    $bw.Write([uint16]1)          # planos de color
    $bw.Write([uint16]32)         # bits por pixel
    $bw.Write([uint32]$pngs[$i].Length)
    $bw.Write([uint32]$offset)
    $offset += $pngs[$i].Length
}
foreach ($p in $pngs) { $bw.Write($p) }
$bw.Flush()
[System.IO.File]::WriteAllBytes($OutputIco, $out.ToArray())
$bw.Dispose()
$out.Dispose()

Write-Host ("ICO generado: " + (Resolve-Path $OutputIco).Path + " (" + $pngs.Count + " tamanos)")