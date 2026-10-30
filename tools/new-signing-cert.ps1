#Requires -Version 5.1
<#
.SYNOPSIS
    Crea el certificado de firma de codigo de TapeOS (uso personal).
.DESCRIPTION
    Genera un certificado auto-firmado CodeSigning, lo guarda en el almacen
    personal y exporta:
      - PFX (clave privada + certificado): SOLO para el pipeline de build (CI).
        NUNCA debe subirse a git.
      - CER (clave publica): para instalar como "Editor de confianza" en los
        equipos donde se quiera ejecutar el EXE sin avisos de SmartScreen.
#>
[CmdletBinding()]
param(
    [string]$Name = "TapeOS Code Signing",
    [string]$OutDir
)

$ErrorActionPreference = "Stop"
if (-not $OutDir) { $OutDir = Join-Path (Split-Path -Parent $PSScriptRoot) ".signing" }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$cert = New-SelfSignedCertificate `
    -Type CodeSigningCert `
    -Subject "CN=$Name" `
    -KeyUsage DigitalSignature `
    -CertStoreLocation Cert:\CurrentUser\My `
    -NotAfter (Get-Date).AddYears(10)

$pfxPass = -join ((48..57 + 65..90 + 97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })
$sec = ConvertTo-SecureString $pfxPass -AsPlainText -Force

$pfxPath = Join-Path $OutDir "tapeos-signing.pfx"
$cerPath = Join-Path $OutDir "tapeos-signing.cer"

Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $sec | Out-Null
Export-Certificate -Cert $cert -FilePath $cerPath -Force | Out-Null
[System.IO.File]::WriteAllText((Join-Path $OutDir "password.txt"), $pfxPass)

Write-Host "[TapeOS] Certificado de firma creado:"
Write-Host ("  Huella: " + $cert.Thumbprint)
Write-Host ("  PFX (privada, NO subir a git): " + $pfxPath)
Write-Host ("  CER (publica, puede distribuirse): " + $cerPath)
Write-Host ("  Password guardada en: " + (Join-Path $OutDir "password.txt"))