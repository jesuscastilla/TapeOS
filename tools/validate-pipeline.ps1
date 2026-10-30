<#
.SYNOPSIS
    Validador del pipeline de instalacion (scripts embebidos en here-strings).
.DESCRIPTION
    1. Falla si hay dobles CR (bug de continuaciones de linea).
    2. Extrae $pipelineScript y lo parsea aislado (el parse del archivo no lo cubre).
    3. Falla si las llamadas clave no tienen sus argumentos obligatorios.
    4. Prueba el BINDING de Invoke-TapeOSImagePatch (debe fallar por archivo
       inexistente, nunca por "faltan los parametros obligatorios").
Uso: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\validate-pipeline.ps1
#>
$ErrorActionPreference = 'Stop'
$root = (Split-Path -Parent $PSScriptRoot)
$wiz = Join-Path $root 'installer\windows\TapeOS-Installer.ps1'
$fail = 0

# 1) dobles CR (rompen las continuaciones de linea con backtick)
$t = [System.IO.File]::ReadAllText($wiz)
$dcr = ([regex]::Matches($t, "`r`r")).Count
if ($dcr -gt 0) { "FALLO: $dcr dobles CR en TapeOS-Installer.ps1"; $fail++ } else { 'OK: sin dobles CR' }

# 2) pipeline aislado
$q = [char]39
$pat = "(?s)\$pipelineScript = @$q(.*?)$q@"
$m = [regex]::Match($t, $pat)
if (-not $m.Success) { 'FALLO: no se pudo extraer $pipelineScript'; $fail++; exit 1 }
$err = $null
$null = [System.Management.Automation.Language.Parser]::ParseInput($m.Groups[1].Value, [ref]$null, [ref]$err)
if ($err.Count -gt 0) { "FALLO: $($err.Count) errores en el pipeline"; $err | Select-Object -First 5 | ForEach-Object { $_.Message }; $fail++ } else { 'OK: pipeline parsea aislado' }

# 3) argumentos de las llamadas clave
$p = $m.Groups[1].Value
if ($p -notmatch '(?s)Invoke-TapeOSImagePatch\s+`\s*\r?\n\s*-RecoveryZipPath\s+\$destZip') { 'FALLO: Invoke-TapeOSImagePatch sin -RecoveryZipPath $destZip'; $fail++ } else { 'OK: Invoke-TapeOSImagePatch con argumentos' }
if ($p -notmatch '(?s)Start-TapeOSUsbFlash\s+`\s*\r?\n\s*-ImageFilePath') { 'FALLO: Start-TapeOSUsbFlash sin -ImageFilePath'; $fail++ } else { 'OK: Start-TapeOSUsbFlash con argumentos' }

# 4) binding real (sin flashear)
Import-Module (Join-Path $root 'installer\windows\modules\ImagePatcher.psm1') -Force
$bindingOk = $false
$bindingMsg = ''
try { $null = Invoke-TapeOSImagePatch -RecoveryZipPath 'C:\noexiste.bin' -OutputDir 'C:\noexiste-out' -ErrorAction Stop }
catch { $bindingMsg = $_.Exception.Message; if ($bindingMsg -notmatch 'par.+?metro|parameter|obligatorios') { $bindingOk = $true } }
if ($bindingOk) { "OK: binding correcto ($bindingMsg)" } else { "FALLO: binding invalido: $bindingMsg"; $fail++ }

# 5) seleccion de build por CPU (Intel -> iris, AMD -> apu)
Import-Module (Join-Path $root 'installer\windows\modules\ImageCatalog.psm1') -Force
$fakeIntel = [PSCustomObject]@{ CPU = [PSCustomObject]@{ Manufacturer = 'Intel' } }
$fakeAmd = [PSCustomObject]@{ CPU = [PSCustomObject]@{ Manufacturer = 'AMD' } }
if ((Get-TapeOSBaseBuild -HwReport $fakeIntel) -ne 'iris') { 'FALLO: Intel no resuelve a iris'; $fail++ } else { 'OK: Intel -> iris' }
if ((Get-TapeOSBaseBuild -HwReport $fakeAmd) -ne 'apu') { 'FALLO: AMD no resuelve a apu'; $fail++ } else { 'OK: AMD -> apu' }

if ($fail -gt 0) { "RESULTADO: $fail fallos"; exit 1 }
'RESULTADO: VALIDACION-OK'