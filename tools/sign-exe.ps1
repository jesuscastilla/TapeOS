#Requires -Version 5.1
<#
.SYNOPSIS
    Firma con Authenticode un EXE de TapeOS usando un certificado de firma de codigo.
.DESCRIPTION
    Usa signtool.exe (Windows SDK) si esta disponible; si no, usa
    Set-AuthenticodeSignature de PowerShell. Sella con servidor de tiempo
    (DigiCert) para que la firma siga siendo valida tras la caducidad del certificado.
.NOTES
    Certificado auto-firmado de uso personal: para eliminar los avisos de
    SmartScreen instala el archivo .cer como "Editor de confianza" en cada equipo.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExePath,

    [string]$PfxPath,
    [string]$PfxPassword
)

$ErrorActionPreference = "Stop"

function Get-SignTool {
    $kits = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
    foreach ($k in $kits) {
        $candidate = Join-Path $k.FullName "x64\signtool.exe"
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

# En CI: el PFX llega por variables de entorno (secretos)
if (-not $PfxPath -and $env:SIGNING_PFX_BASE64) {
    $PfxPath = Join-Path $env:TEMP ("tapeos-signing-" + [guid]::NewGuid().ToString("N") + ".pfx")
    [System.IO.File]::WriteAllBytes($PfxPath, [Convert]::FromBase64String($env:SIGNING_PFX_BASE64))
    if (-not $PfxPassword) { $PfxPassword = $env:SIGNING_PFX_PASSWORD }
}

if (-not $PfxPath -or -not (Test-Path $PfxPath)) {
    # Ultimo recurso: certificado local de firma de codigo con asunto TapeOS
    $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Where-Object { $_.Subject -match 'TapeOS' } | Select-Object -First 1
    if (-not $cert) { throw "No se encontro certificado de firma TapeOS ni archivo PFX." }
    Write-Host "[TapeOS] Firmando con certificado local: $($cert.Subject)"
    Set-AuthenticodeSignature -FilePath $ExePath -Certificate $cert -TimestampServer "http://timestamp.digicert.com" | Out-Null
} else {
    $signtool = Get-SignTool
    if ($signtool) {
        Write-Host "[TapeOS] Firmando con signtool: $signtool"
        $signtoolArgs = @("sign", "/f", $PfxPath, "/p", $PfxPassword, "/fd", "SHA256", "/tr", "http://timestamp.digicert.com", "/td", "SHA256", $ExePath)
        & $signtool @signtoolArgs
        if ($LASTEXITCODE -ne 0) { throw "signtool fallo con codigo $LASTEXITCODE" }
    } else {
        Write-Host "[TapeOS] signtool no disponible; usando Set-AuthenticodeSignature."
        $sec = ConvertTo-SecureString $PfxPassword -AsPlainText -Force
        $cert = Import-PfxCertificate -FilePath $PfxPath -Password $sec -CertStoreLocation Cert:\CurrentUser\My
        Set-AuthenticodeSignature -FilePath $ExePath -Certificate $cert -TimestampServer "http://timestamp.digicert.com" | Out-Null
    }
}

$sig = Get-AuthenticodeSignature -FilePath $ExePath
Write-Host "[TapeOS] Firma aplicada: Status=$($sig.Status) Signer=$($sig.SignerCertificate.Subject) Timestamp=$($sig.TimeStamperCertificate.Subject)" -ForegroundColor Green