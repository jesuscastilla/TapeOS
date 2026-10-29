<#
.SYNOPSIS
    TapeOS Interactive Windows Installer (GUI wizard)
.DESCRIPTION
    Açîtente por paçô: Detêççiôn -> Rekomendaçiôn de Rekûperaçiôn ->
    Konfiguraçiôn -> Reçûmen -> Ehekuçiôn, kon barra de progreço y ETA
    (tiempo êttimao) en kada etapa. EPA po defêto, kon çelettôh Êppanyôh.
#>

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"") -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# =============================================================================
# Log y captura global de errores
# =============================================================================
$script:__tapeosLogFile = Join-Path $env:ProgramData "TapeOS\tapeos-installer.log"
try { New-Item -ItemType Directory -Force -Path (Split-Path $script:__tapeosLogFile) | Out-Null } catch { }
function Write-TapeOSLog {
    param([string]$Msg)
    try { Add-Content -Path $script:__tapeosLogFile -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Msg) -Encoding UTF8 } catch { }
}
Write-TapeOSLog "=== TapeOS GUI (wizard) iniciada ==="
try {
    [System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)
    [System.Windows.Forms.Application]::add_ThreadException({
        param($sender, $e)
        Write-TapeOSLog ("UNHANDLED ThreadException: " + $e.Exception.ToString())
        try { [System.Windows.Forms.MessageBox]::Show("Errôh inepperao:`r`n$($e.Exception.Message)", "TapeOS", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null } catch { }
    })
} catch { }

# Cargar módulos
$moduleDir = Join-Path $PSScriptRoot "modules"
Import-Module (Join-Path $moduleDir "HardwareDetector.psm1") -Force
Import-Module (Join-Path $moduleDir "RecoveryCatalog.psm1") -Force
Import-Module (Join-Path $moduleDir "RecoveryDownloader.psm1") -Force
Import-Module (Join-Path $moduleDir "ImagePatcher.psm1") -Force
Import-Module (Join-Path $moduleDir "UsbFlasher.psm1") -Force
Import-Module (Join-Path $moduleDir "DiskManager.psm1") -Force
Import-Module (Join-Path $moduleDir "BootManager.psm1") -Force

# Diagnóstico inicial (rápido, en el hilo de UI)
$hwReport = Get-TapeOSHardwareReport
$catalog = Get-TapeOSCatalog
$rec = $hwReport.Recommendations

# =============================================================================
# Formulario principal
# =============================================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "TapeOS Installer — Açîtente por Paçô"
$form.Size = New-Object System.Drawing.Size(900, 860)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Fondo: bandera de Andalucía
$tapeosFlag = New-Object System.Drawing.Bitmap(600, 360)
$flagG = [System.Drawing.Graphics]::FromImage($tapeosFlag)
$greenBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, 132, 61))
$whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$flagG.FillRectangle($greenBrush, 0, 0, 600, 120)
$flagG.FillRectangle($whiteBrush, 0, 120, 600, 120)
$flagG.FillRectangle($greenBrush, 0, 240, 600, 120)
$flagG.Dispose()
$form.BackgroundImage = $tapeosFlag
$form.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Stretch

# Cabecera
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(900, 80)
$headerPanel.BackColor = [System.Drawing.Color]::FromArgb(0, 132, 61)
$form.Controls.Add($headerPanel)

$logoPath = $null
$logoCandidates = @(
    (Join-Path $PSScriptRoot "assets\diplotech-logo-blanco.png"),
    (Join-Path $PSScriptRoot "..\..\tools\assets\diplotech-logo-blanco.png")
)
foreach ($c in $logoCandidates) {
    if (Test-Path -LiteralPath $c) { $logoPath = (Resolve-Path -LiteralPath $c).Path; break }
}
if ($logoPath) {
    $logoBox = New-Object System.Windows.Forms.PictureBox
    $logoBox.Image = [System.Drawing.Image]::FromFile($logoPath)
    $logoBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $logoBox.Location = New-Object System.Drawing.Point(14, 8)
    $logoBox.Size = New-Object System.Drawing.Size(64, 64)
    $headerPanel.Controls.Add($logoBox)
}

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "TapeOS Îttaladôh Uniberçâh"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::White
$titleLabel.Location = New-Object System.Drawing.Point(92, 12)
$titleLabel.AutoSize = $true
$headerPanel.Controls.Add($titleLabel)

$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = "Açîtente por paçô: Detêççiôn -> Rekûperaçiôn -> Konfiguraçiôn -> Reçûmen -> Ehekuçiôn"
$subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$subtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(232, 240, 254)
$subtitleLabel.Location = New-Object System.Drawing.Point(93, 44)
$subtitleLabel.AutoSize = $true
$headerPanel.Controls.Add($subtitleLabel)

$cbLang = New-Object System.Windows.Forms.ComboBox
$cbLang.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cbLang.Location = New-Object System.Drawing.Point(735, 14)
$cbLang.Size = New-Object System.Drawing.Size(140, 25)
[void]$cbLang.Items.Add("Andaluz")
[void]$cbLang.Items.Add("Español")
$cbLang.SelectedIndex = 0
$headerPanel.Controls.Add($cbLang)

# =============================================================================
# Indicador de paçô (5 etapâ)
# =============================================================================
$stepIndicator = New-Object System.Windows.Forms.Panel
$stepIndicator.Location = New-Object System.Drawing.Point(20, 92)
$stepIndicator.Size = New-Object System.Drawing.Size(845, 44)
$stepIndicator.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($stepIndicator)

$stepLabels = @()
$stepNamesEPA = @("1. Detêççiôn", "2. Rekûperaçiôn", "3. Konfiguraçiôn", "4. Reçûmen", "5. Ehekuçiôn")
$stepNamesES  = @("1. Detección", "2. Recovery", "3. Configuración", "4. Resumen", "5. Ejecución")
for ($i = 0; $i -lt 5; $i++) {
    $sl = New-Object System.Windows.Forms.Label
    $sl.Text = $stepNamesEPA[$i]
    $sl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $sl.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 120)
    $sl.Location = New-Object System.Drawing.Point(15 + ($i * 166), 14)
    $sl.Size = New-Object System.Drawing.Size(160, 20)
    $stepIndicator.Controls.Add($sl)
    $stepLabels += $sl
}

# Panel de contenido (una bîtta po paço)
$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Location = New-Object System.Drawing.Point(20, 146)
$contentPanel.Size = New-Object System.Drawing.Size(845, 500)
$contentPanel.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($contentPanel)

# --- PAÇO 1: Detêççiôn de hardware ---
$pnl1 = New-Object System.Windows.Forms.Panel
$pnl1.Location = New-Object System.Drawing.Point(0, 0)
$pnl1.Size = $contentPanel.Size
$pnl1.BackColor = [System.Drawing.Color]::White

$wifiSummary = if ($hwReport.Network.WiFi.Count -gt 0) { (($hwReport.Network.WiFi | ForEach-Object { $_.Name }) -join ', ') } else { 'No detêttao' }
$btSummary = if ($hwReport.Network.Bluetooth.Count -gt 0) { (($hwReport.Network.Bluetooth | ForEach-Object { $_.Name }) -join ', ') } else { 'No detêttao' }
$audioSummary = if ($hwReport.Audio.Count -gt 0) { (($hwReport.Audio | ForEach-Object { $_.Name }) -join ', ') } else { 'Çoportao' }
$touchSummary = if ($hwReport.Touchscreen.Count -gt 0) { (($hwReport.Touchscreen | ForEach-Object { $_.Name }) -join ', ') } else { 'No detêttá' }
$patchList = (($hwReport.FrameworkPatches | ForEach-Object { $_.Option }) -join ', ')

$lblHwTitle = New-Object System.Windows.Forms.Label
$lblHwTitle.Text = "Detêççiôn de hardware"
$lblHwTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblHwTitle.Location = New-Object System.Drawing.Point(20, 15)
$lblHwTitle.AutoSize = $true
$pnl1.Controls.Add($lblHwTitle)

$lblHwInfo = New-Object System.Windows.Forms.Label
$lblHwInfo.Text = @"
• CPU: $($hwReport.CPU.Name) ($($hwReport.CPU.Generation))
• Firmware: $($hwReport.Firmware.Type)  |  Secure Boot: $(if ($hwReport.Firmware.SecureBoot) { 'Attibo' } else { 'Inattibo' })  |  BitLocker: $(if ($hwReport.Security.BitLockerActive) { 'ATTIBO ⚠️' } else { 'Inattibo ✅' })
• GPU: $(($hwReport.GPU | ForEach-Object { "$($_.Name) $(if ($_.VendorId -eq '10DE') { '(NVIDIA)' } elseif ($_.VendorId -eq '1002') { '(AMD)' } elseif ($_.VendorId -eq '8086') { '(Intel)' } else { '' })" }) -join ', ')
• WiFi: $wifiSummary   |   Bluetooth: $btSummary
• Audio: $audioSummary   |   Tâttîh: $touchSummary
• Parcheh de hardware detêttáô: $(if ($patchList) { $patchList } else { 'nîn guno neçeçario' })
"@
$lblHwInfo.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$lblHwInfo.Location = New-Object System.Drawing.Point(20, 55)
$lblHwInfo.Size = New-Object System.Drawing.Size(800, 160)
$pnl1.Controls.Add($lblHwInfo)

$pbStep1 = New-Object System.Windows.Forms.ProgressBar
$pbStep1.Location = New-Object System.Drawing.Point(20, 235)
$pbStep1.Size = New-Object System.Drawing.Size(800, 22)
$pbStep1.Value = 100
$pnl1.Controls.Add($pbStep1)

$lblEta1 = New-Object System.Windows.Forms.Label
$lblEta1.Text = "Êttimao: 0 ç (kompletao)"
$lblEta1.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$lblEta1.Location = New-Object System.Drawing.Point(20, 262)
$lblEta1.AutoSize = $true
$pnl1.Controls.Add($lblEta1)

$contentPanel.Controls.Add($pnl1)

# --- PAÇO 2: Rekomendaçiôn de rekûperaçiôn ---
$pnl2 = New-Object System.Windows.Forms.Panel
$pnl2.Location = New-Object System.Drawing.Point(0, 0)
$pnl2.Size = $contentPanel.Size
$pnl2.BackColor = [System.Drawing.Color]::White

$lblRecTitle = New-Object System.Windows.Forms.Label
$lblRecTitle.Text = "Rekomendaçiôn de rekûperaçiôn"
$lblRecTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblRecTitle.Location = New-Object System.Drawing.Point(20, 15)
$lblRecTitle.AutoSize = $true
$pnl2.Controls.Add($lblRecTitle)

$lblRecInfo = New-Object System.Windows.Forms.Label
$lblRecInfo.Text = "Çegún tu hardware, la rekûperaçiôn rekomendá êh [$($rec.RecoveryCodename.ToUpper())] kon kernel [$($rec.Kernel)]."
$lblRecInfo.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblRecInfo.Location = New-Object System.Drawing.Point(20, 55)
$lblRecInfo.Size = New-Object System.Drawing.Size(800, 40)
$pnl2.Controls.Add($lblRecInfo)

$cbRecovery = New-Object System.Windows.Forms.ComboBox
$cbRecovery.Location = New-Object System.Drawing.Point(20, 105)
$cbRecovery.Size = New-Object System.Drawing.Size(520, 25)
$cbRecovery.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
foreach ($item in $catalog) { [void]$cbRecovery.Items.Add("$($item.Codename) — $($item.DisplayName)") }
$cbRecovery.SelectedIndex = 0
for ($i = 0; $i -lt $catalog.Count; $i++) {
    if ($catalog[$i].Codename -eq $rec.RecoveryCodename) { $cbRecovery.SelectedIndex = $i; break }
}
$pnl2.Controls.Add($cbRecovery)

$btnCheckOnline = New-Object System.Windows.Forms.Button
$btnCheckOnline.Text = "🌐 Bûhkâh la Ûrtima Berçiôn"
$btnCheckOnline.Location = New-Object System.Drawing.Point(560, 103)
$btnCheckOnline.Size = New-Object System.Drawing.Size(260, 27)
$pnl2.Controls.Add($btnCheckOnline)

$lblStatusUrl = New-Object System.Windows.Forms.Label
$lblStatusUrl.Text = "Berçiôn ofiçiâh mâh reçiente: pulça 'Bûhkâh' pa konhûttâh er CDN de Google."
$lblStatusUrl.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$lblStatusUrl.Location = New-Object System.Drawing.Point(20, 145)
$lblStatusUrl.Size = New-Object System.Drawing.Size(800, 40)
$pnl2.Controls.Add($lblStatusUrl)

$pbStep2 = New-Object System.Windows.Forms.ProgressBar
$pbStep2.Location = New-Object System.Drawing.Point(20, 195)
$pbStep2.Size = New-Object System.Drawing.Size(800, 22)
$pbStep2.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
$pbStep2.Visible = $false
$pnl2.Controls.Add($pbStep2)

$lblEta2 = New-Object System.Windows.Forms.Label
$lblEta2.Text = ""
$lblEta2.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$lblEta2.Location = New-Object System.Drawing.Point(20, 222)
$lblEta2.AutoSize = $true
$pnl2.Controls.Add($lblEta2)

$contentPanel.Controls.Add($pnl2)

# --- PAÇO 3: Konfiguraçiôn ---
$pnl3 = New-Object System.Windows.Forms.Panel
$pnl3.Location = New-Object System.Drawing.Point(0, 0)
$pnl3.Size = $contentPanel.Size
$pnl3.BackColor = [System.Drawing.Color]::White

$lblCfgTitle = New-Object System.Windows.Forms.Label
$lblCfgTitle.Text = "Konfiguraçiôn"
$lblCfgTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblCfgTitle.Location = New-Object System.Drawing.Point(20, 15)
$lblCfgTitle.AutoSize = $true
$pnl3.Controls.Add($lblCfgTitle)

$radioGoogleApps = New-Object System.Windows.Forms.RadioButton
$radioGoogleApps.Text = "✅ Kon Googlêh Play — Çtore y aplikâçionêh Android (rekomendao)"
$radioGoogleApps.Location = New-Object System.Drawing.Point(20, 60)
$radioGoogleApps.AutoSize = $true
$radioGoogleApps.Checked = $true
$pnl3.Controls.Add($radioGoogleApps)

$radioNoGoogleApps = New-Object System.Windows.Forms.RadioButton
$radioNoGoogleApps.Text = "🚫 Çîn Googlêh Play — Android kon apph APK (Aurora Çtore)"
$radioNoGoogleApps.Location = New-Object System.Drawing.Point(20, 88)
$radioNoGoogleApps.AutoSize = $true
$pnl3.Controls.Add($radioNoGoogleApps)

$radioUsb = New-Object System.Windows.Forms.RadioButton
$radioUsb.Text = "💾 Live-USB — Grabâh en un pendraîh USB y arrankâh dêhde él"
$radioUsb.Location = New-Object System.Drawing.Point(20, 130)
$radioUsb.AutoSize = $true
$radioUsb.Checked = $false
$pnl3.Controls.Add($radioUsb)

$cbUsbDrives = New-Object System.Windows.Forms.ComboBox
$cbUsbDrives.Location = New-Object System.Drawing.Point(340, 128)
$cbUsbDrives.Size = New-Object System.Drawing.Size(330, 25)
$cbUsbDrives.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cbUsbDrives.Enabled = $false
$pnl3.Controls.Add($cbUsbDrives)

$btnRefreshUsb = New-Object System.Windows.Forms.Button
$btnRefreshUsb.Text = "🔄 Refrehkâh"
$btnRefreshUsb.Location = New-Object System.Drawing.Point(680, 126)
$btnRefreshUsb.Size = New-Object System.Drawing.Size(140, 27)
$btnRefreshUsb.Enabled = $false
$pnl3.Controls.Add($btnRefreshUsb)

$radioImageOnly = New-Object System.Windows.Forms.RadioButton
$radioImageOnly.Text = "📀 Îttaladôh — Kreâh er medio de îttalaçiôn (.img) çîn grabâh"
$radioImageOnly.Location = New-Object System.Drawing.Point(20, 170)
$radioImageOnly.AutoSize = $true
$pnl3.Controls.Add($radioImageOnly)
$radioImageOnly.Checked = $true

$txtImageDir = New-Object System.Windows.Forms.TextBox
$txtImageDir.Text = "C:\TapeOS\images"
$txtImageDir.Location = New-Object System.Drawing.Point(340, 168)
$txtImageDir.Size = New-Object System.Drawing.Size(330, 25)
$pnl3.Controls.Add($txtImageDir)

$btnBrowseDir = New-Object System.Windows.Forms.Button
$btnBrowseDir.Text = "📂 Ehkaminâh..."
$btnBrowseDir.Location = New-Object System.Drawing.Point(680, 166)
$btnBrowseDir.Size = New-Object System.Drawing.Size(140, 27)
$pnl3.Controls.Add($btnBrowseDir)

$lblUsbWarning = New-Object System.Windows.Forms.Label
$lblUsbWarning.Text = "⚠️ OHO: Er pendraîh çelehçionao çe formateará po kompleto pa îttalâh TapeOS."
$lblUsbWarning.ForeColor = [System.Drawing.Color]::FromArgb(180, 40, 40)
$lblUsbWarning.Location = New-Object System.Drawing.Point(20, 215)
$lblUsbWarning.Size = New-Object System.Drawing.Size(800, 25)
$pnl3.Controls.Add($lblUsbWarning)

$contentPanel.Controls.Add($pnl3)

# --- PAÇO 4: Reçûmen ---
$pnl4 = New-Object System.Windows.Forms.Panel
$pnl4.Location = New-Object System.Drawing.Point(0, 0)
$pnl4.Size = $contentPanel.Size
$pnl4.BackColor = [System.Drawing.Color]::White

$lblSumTitle = New-Object System.Windows.Forms.Label
$lblSumTitle.Text = "Reçûmen de la îttalaçiôn"
$lblSumTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblSumTitle.Location = New-Object System.Drawing.Point(20, 15)
$lblSumTitle.AutoSize = $true
$pnl4.Controls.Add($lblSumTitle)

$lblSummary = New-Object System.Windows.Forms.Label
$lblSummary.Text = "..."
$lblSummary.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblSummary.Location = New-Object System.Drawing.Point(20, 55)
$lblSummary.Size = New-Object System.Drawing.Size(800, 120)
$pnl4.Controls.Add($lblSummary)

$btnCreate = New-Object System.Windows.Forms.Button
$btnCreate.Text = "⚡ Dehkargâh, Parcheâh y Kreâh (1-Klik)"
$btnCreate.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnCreate.BackColor = [System.Drawing.Color]::FromArgb(0, 132, 61)
$btnCreate.ForeColor = [System.Drawing.Color]::White
$btnCreate.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnCreate.Location = New-Object System.Drawing.Point(250, 200)
$btnCreate.Size = New-Object System.Drawing.Size(345, 45)
$pnl4.Controls.Add($btnCreate)

$contentPanel.Controls.Add($pnl4)

# --- PAÇO 5: Ehekuçiôn ---
$pnl5 = New-Object System.Windows.Forms.Panel
$pnl5.Location = New-Object System.Drawing.Point(0, 0)
$pnl5.Size = $contentPanel.Size
$pnl5.BackColor = [System.Drawing.Color]::White

$lblPhase = New-Object System.Windows.Forms.Label
$lblPhase.Text = "Êpperando..."
$lblPhase.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblPhase.Location = New-Object System.Drawing.Point(20, 20)
$lblPhase.Size = New-Object System.Drawing.Size(800, 25)
$pnl5.Controls.Add($lblPhase)

$pbStep5 = New-Object System.Windows.Forms.ProgressBar
$pbStep5.Location = New-Object System.Drawing.Point(20, 60)
$pbStep5.Size = New-Object System.Drawing.Size(800, 30)
$pnl5.Controls.Add($pbStep5)

$lblEta5 = New-Object System.Windows.Forms.Label
$lblEta5.Text = "Êttimao: --"
$lblEta5.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Italic)
$lblEta5.Location = New-Object System.Drawing.Point(20, 100)
$lblEta5.Size = New-Object System.Drawing.Size(800, 25)
$pnl5.Controls.Add($lblEta5)

$contentPanel.Controls.Add($pnl5)

# =============================================================================
# Log, botonêh de nabegaçiôn y funçionêh der wîçâh
# =============================================================================
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(20, 656)
$logBox.Size = New-Object System.Drawing.Size(845, 95)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.BackColor = [System.Drawing.Color]::FromArgb(20, 24, 30)
$logBox.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 128)
$logBox.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$logBox.Text = "=== TapeOS Lîtta ===`r`n"
$form.Controls.Add($logBox)

$btnBack = New-Object System.Windows.Forms.Button
$btnBack.Text = "‹ Anteriôh"
$btnBack.Location = New-Object System.Drawing.Point(20, 760)
$btnBack.Size = New-Object System.Drawing.Size(150, 45)
$btnBack.Enabled = $false
$form.Controls.Add($btnBack)

$btnNext = New-Object System.Windows.Forms.Button
$btnNext.Text = "Çiguiente ›"
$btnNext.Location = New-Object System.Drawing.Point(715, 760)
$btnNext.Size = New-Object System.Drawing.Size(150, 45)
$btnNext.BackColor = [System.Drawing.Color]::FromArgb(0, 132, 61)
$btnNext.ForeColor = [System.Drawing.Color]::White
$btnNext.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($btnNext)

$stepPanels = @($pnl1, $pnl2, $pnl3, $pnl4, $pnl5)
$script:currentStep = 0

function Set-TapeOSStep {
    param([int]$StepIndex)
    $script:currentStep = $StepIndex
    for ($i = 0; $i -lt $stepPanels.Count; $i++) {
        $stepPanels[$i].Visible = ($i -eq $StepIndex)
    }
    for ($i = 0; $i -lt $stepLabels.Count; $i++) {
        if ($i -eq $StepIndex) {
            $stepLabels[$i].ForeColor = [System.Drawing.Color]::FromArgb(0, 132, 61)
            $stepLabels[$i].Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        } else {
            $stepLabels[$i].ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 120)
            $stepLabels[$i].Font = New-Object System.Drawing.Font("Segoe UI", 9)
        }
    }
    $btnBack.Enabled = ($StepIndex -gt 0 -and $StepIndex -lt 4)
    $btnNext.Visible = ($StepIndex -lt 4)
    if ($StepIndex -eq 3) {
        $sumMode = if ($radioImageOnly.Checked) { "Îttaladôh (.img) → $($txtImageDir.Text)" } else { "Live-USB → $(if ($cbUsbDrives.SelectedItem) { $cbUsbDrives.SelectedItem.ToString() } else { '(çelehçiona pendraîh)' })" }
        $lblSummary.Text = @"
• Rekûperaçiôn: $((($cbRecovery.SelectedItem.ToString()).Split(' ')[0]).ToUpper()) $(if ($script:recoveryInfo) { "- Milestone $($script:recoveryInfo.Milestone)" } else { '' })
• Googlêh Play: $(if ($radioGoogleApps.Checked) { 'ÇÍ (Çtore + Android)' } else { 'NO (APK + Aurora Çtore)' })
• Modo: $sumMode
• Parcheh de hardware: $patchList
"@
    }
}

function Refresh-UsbList {
    $cbUsbDrives.Items.Clear()
    $usbList = @(Get-TapeOSUsbDrives)
    if ($usbList.Count -eq 0) {
        [void]$cbUsbDrives.Items.Add("⚠️ No çe detêttó nîn pun pendraîh USB")
        $cbUsbDrives.SelectedIndex = 0
    } else {
        foreach ($d in $usbList) { [void]$cbUsbDrives.Items.Add($d.DisplayName) }
        $cbUsbDrives.SelectedIndex = 0
    }
}

function Format-ETA {
    param([double]$Seconds)
    if ($Seconds -lt 0 -or [double]::IsInfinity($Seconds) -or [double]::IsNaN($Seconds)) { return "--" }
    if ($Seconds -lt 60) { return ("{0:N0} ç" -f $Seconds) }
    if ($Seconds -lt 3600) { return ("{0:N0} min {1:N0} ç" -f [math]::Floor($Seconds / 60), ($Seconds % 60)) }
    return ("{0:N1} orâ" -f ($Seconds / 3600))
}

function Set-TapeOSLanguage {
    param([string]$Lang)
    $isEPA = ($Lang -eq "Andaluz")
    $titleLabel.Text = if ($isEPA) { "TapeOS Îttaladôh Uniberçâh" } else { "TapeOS Universal Installer" }
    $subtitleLabel.Text = if ($isEPA) { "Açîtente por paçô: Detêççiôn -> Rekûperaçiôn -> Konfiguraçiôn -> Reçûmen -> Ehekuçiôn" } else { "Asistente por pasos: Detección -> Recovery -> Configuración -> Resumen -> Ejecución" }
    for ($i = 0; $i -lt 5; $i++) { $stepLabels[$i].Text = if ($isEPA) { $stepNamesEPA[$i] } else { $stepNamesES[$i] } }
    $lblHwTitle.Text = if ($isEPA) { "Detêççiôn de hardware" } else { "Detección de hardware" }
    $lblRecTitle.Text = if ($isEPA) { "Rekomendaçiôn de rekûperaçiôn" } else { "Recomendación de recovery" }
    $btnCheckOnline.Text = if ($isEPA) { "🌐 Bûhkâh la Ûrtima Berçiôn" } else { "🌐 Buscar Última Versión" }
    $lblStatusUrl.Text = if ($isEPA) { "Berçiôn ofiçiâh mâh reçiente: pulça 'Bûhkâh' pa konhûttâh er CDN de Google." } else { "Versión oficial más reciente: pulsa 'Buscar' para consultar el CDN de Google." }
    $lblCfgTitle.Text = if ($isEPA) { "Konfiguraçiôn" } else { "Configuración" }
    $radioGoogleApps.Text = if ($isEPA) { "✅ Kon Googlêh Play — Çtore y aplikâçionêh Android (rekomendao)" } else { "✅ Con Google Play — Store y aplicaciones Android (recomendado)" }
    $radioNoGoogleApps.Text = if ($isEPA) { "🚫 Çîn Googlêh Play — Android kon apph APK (Aurora Çtore)" } else { "🚫 Sin Google Play — Android con apps APK (Aurora Store)" }
    $radioUsb.Text = if ($isEPA) { "💾 Live-USB — Grabâh en un pendraîh USB y arrankâh dêhde él" } else { "💾 Live-USB — Grabar en un pendrive USB y arrancar desde él" }
    $btnRefreshUsb.Text = if ($isEPA) { "🔄 Refrehkâh" } else { "🔄 Refrescar" }
    $radioImageOnly.Text = if ($isEPA) { "📀 Îttaladôh — Kreâh er medio de îttalaçiôn (.img) çîn grabâh" } else { "📀 Instalador — Crear el medio de instalación (.img) sin grabar" }
    $btnBrowseDir.Text = if ($isEPA) { "📂 Ehkaminâh..." } else { "📂 Examinar..." }
    $lblUsbWarning.Text = if ($isEPA) { "⚠️ OHO: Er pendraîh çelehçionao çe formateará po kompleto pa îttalâh TapeOS." } else { "⚠️ ATENCIÓN: El pendrive seleccionado será formateado por completo para instalar TapeOS." }
    $lblSumTitle.Text = if ($isEPA) { "Reçûmen de la îttalaçiôn" } else { "Resumen de la instalación" }
    $btnCreate.Text = if ($isEPA) { "⚡ Dehkargâh, Parcheâh y Kreâh (1-Klik)" } else { "⚡ Descargar, Parchear y Crear (1-Clic)" }
    $lblEta5.Text = if ($isEPA) { "Êttimao: --" } else { "Estimado: --" }
    $btnBack.Text = if ($isEPA) { "‹ Anteriôh" } else { "‹ Anterior" }
    $btnNext.Text = if ($isEPA) { "Çiguiente ›" } else { "Siguiente ›" }
    $lblEta1.Text = if ($isEPA) { "Êttimao: 0 ç (kompletao)" } else { "Estimado: 0 s (completado)" }
}

# =============================================================================
# Ebentô der GUI
# =============================================================================
$cbLang.Add_SelectedIndexChanged({
    Set-TapeOSLanguage -Lang $cbLang.SelectedItem.ToString()
})

$btnBack.Add_Click({
    if ($script:currentStep -gt 0) { Set-TapeOSStep ($script:currentStep - 1) }
})

$btnNext.Add_Click({
    if ($script:currentStep -lt 4) { Set-TapeOSStep ($script:currentStep + 1) }
})

$radioUsb.Add_Click({
    $cbUsbDrives.Enabled = $true
    $btnRefreshUsb.Enabled = $true
    $txtImageDir.Enabled = $false
    $btnBrowseDir.Enabled = $false
    Refresh-UsbList
})
$radioImageOnly.Add_Click({
    $cbUsbDrives.Enabled = $false
    $btnRefreshUsb.Enabled = $false
    $txtImageDir.Enabled = $true
    $btnBrowseDir.Enabled = $true
})
$btnBrowseDir.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Elihe la karpeta pa guâddâh er medio de îttalaçiôn TapeOS (.img)"
    $dlg.SelectedPath = $txtImageDir.Text
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $txtImageDir.Text = $dlg.Path }
})
$btnRefreshUsb.Add_Click({ Refresh-UsbList })

# Konhûtta a la API (paço 2) en runspace dedicá, kon barra y ETA
$script:recoveryInfo = $null
$btnCheckOnline.Add_Click({
    $btnCheckOnline.Enabled = $false
    $pbStep2.Visible = $true
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $lblEta2.Text = "Êttimao: ~5 ç"
    $queryScript = {
        param([string]$Codename, [string]$ModuleDir)
        Import-Module (Join-Path $ModuleDir "RecoveryDownloader.psm1") -Force
        Get-TapeOSLatestRecoveryInfo -BoardCodename $Codename
    }
    $rs = [runspacefactory]::CreateRunspace(); $rs.ApartmentState = "STA"; $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    $null = $ps.AddScript($queryScript.ToString())
    $null = $ps.AddParameter("Codename", (($cbRecovery.SelectedItem.ToString()).Split(' ')[0]))
    $null = $ps.AddParameter("ModuleDir", $moduleDir)
    $async = $ps.BeginInvoke()
    $qTimer = New-Object System.Windows.Forms.Timer
    $qTimer.Interval = 200
    $qTimer.Add_Tick({
        $el = $sw.Elapsed.TotalSeconds
        $lblEta2.Text = "Êttimao: " + (Format-ETA ([math]::Max(0.5, (5 - $el))))
        if ($async.IsCompleted) {
            $qTimer.Stop(); $qTimer.Dispose()
            $pbStep2.Visible = $false
            try {
                $script:recoveryInfo = $ps.EndInvoke($async)
                $lblStatusUrl.Text = "✔ Berçiôn: Milestone $($script:recoveryInfo.Milestone) | Arxibo: $($script:recoveryInfo.FileName)"
                $lblEta2.Text = "Kompletao en $(Format-ETA $el)"
                $logBox.AppendText("[ChromiumDash] Berçiôn Milestone $($script:recoveryInfo.Milestone) enkontrá.`r`n")
            } catch {
                Write-TapeOSLog ("ERROR consulta API: " + $_.Exception.ToString())
                $lblStatusUrl.Text = "❌ No çe pudo konhûttâh la API: $($_.Exception.Message)"
                $lblEta2.Text = ""
            } finally {
                $ps.Dispose(); $rs.Dispose()
                $btnCheckOnline.Enabled = $true
            }
        }
    })
    $qTimer.Start()
})

$pipelineScript = @'
param(
    [object]$Form, [object]$LogBox, [object]$ProgressBar, [object]$LblPhase, [object]$LblEta,
    [string]$Codename, [bool]$EnableGoogleApps, [bool]$ImageOnlyMode,
    [string]$ImageDestDir, [object]$TargetUsb, [object]$HwReport,
    [string]$ModuleDir, [string]$LogFile
)
$ErrorActionPreference = 'Stop'
function Write-PipelineLog {
    param([string]$Msg)
    try { Add-Content -Path $LogFile -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Msg) -Encoding UTF8 } catch { }
}
function F-Eta {
    param([double]$S)
    if ($S -lt 0 -or [double]::IsNaN($S) -or [double]::IsInfinity($S)) { return '--' }
    if ($S -lt 60) { return ('{0:N0} ç' -f $S) }
    if ($S -lt 3600) { return ('{0:N0} min {1:N0} ç' -f [math]::Floor($S / 60), ($S % 60)) }
    return ('{0:N1} orâ' -f ($S / 3600))
}
Import-Module (Join-Path $ModuleDir "RecoveryDownloader.psm1") -Force
Import-Module (Join-Path $ModuleDir "ImagePatcher.psm1") -Force
Import-Module (Join-Path $ModuleDir "UsbFlasher.psm1") -Force

try {
    Write-PipelineLog "Pipeline (runspace) iniciado"
    Write-PipelineLog ("Pipeline: codename=$Codename, googleplay=$EnableGoogleApps, imageOnly=$ImageOnlyMode, destino=$ImageDestDir")
    $Form.Invoke([Action]{ $LogBox.AppendText("`r`n[Iniçio] Proçeço de îttalaçiôn arranká.`r`n") })

    # --- FASE 1: Dehkarga ---
    $Form.Invoke([Action]{ $LblPhase.Text = '📥 Dehkarga de la imâhen ofiçiâh'; $ProgressBar.Value = 0; $LblEta.Text = 'Êttimao: --' })
    $info = Get-TapeOSLatestRecoveryInfo -BoardCodename $Codename
    $downloadDir = "C:\TapeOS\downloads"
    $destZip = Join-Path $downloadDir $info.FileName
    if ((Test-Path $destZip) -and (Get-Item $destZip).Length -gt 100MB) {
        Write-PipelineLog "ZIP previo encontrado; se reutiliza: $destZip"
        $Form.Invoke([Action]{ $LogBox.AppendText("[Dehkarga] Dehkarga anteriôh enkontrá; çe reûtiliça.`r`n"); $ProgressBar.Value = 100; $LblEta.Text = 'Kompletao: 0 ç' })
    } else {
        $dlSw = [System.Diagnostics.Stopwatch]::StartNew()
        Start-TapeOSDownload -Url $info.Url -DestinationFile $destZip -ProgressCallback {
            param($percent, $received, $total)
            try {
                $sp = if ($dlSw.Elapsed.TotalSeconds -gt 1) { $received / $dlSw.Elapsed.TotalSeconds } else { 0 }
                $eta = if ($sp -gt 0) { ($total - $received) / $sp } else { -1 }
                $etaStr = 'Êttimao: ' + (F-Eta $eta)
                $pctInt = [math]::Min(100, [int]$percent)
                $Form.Invoke([Action]{ $ProgressBar.Value = $pctInt; $LblEta.Text = $etaStr })
            } catch {
                Write-PipelineLog ("ERROR callback descarga: " + $_.Exception.ToString())
            }
        } | Out-Null
    }

    # --- FASE 2: Parcheo ---
    $Form.Invoke([Action]{ $LblPhase.Text = '🩹 Parcheo TapeOS (Legacy EFI + swtpm + GPU)'; $ProgressBar.Value = 0; $LblEta.Text = 'Êttimao: --' })
    $ptSw = [System.Diagnostics.Stopwatch]::StartNew()
    $patched = Invoke-TapeOSImagePatch `
        -RecoveryZipPath $destZip `
        -OutputDir "C:\TapeOS\patched" `
        -EnableIA32 ($HwReport.Firmware.IsIA32UEFI) `
        -EnableLegacyGPU $true `
        -EnableSwtpm $true `
        -EnableGoogleApps $EnableGoogleApps `
        -AdditionalFrameworkOptions @($HwReport.FrameworkPatches | ForEach-Object { $_.Option }) `
        -ProgressCallback {
            param($pct, $msg)
            try {
                $el = $ptSw.Elapsed.TotalSeconds
                $eta = if ($pct -gt 0) { ($el * (100 - $pct) / $pct) } else { -1 }
                $etaStr = 'Êttimao: ' + (F-Eta $eta)
                $pctInt = [int]$pct
                $msgLine = "  • $msg`r`n"
                $Form.Invoke([Action]{ $ProgressBar.Value = $pctInt; $LblEta.Text = $etaStr; $LogBox.AppendText($msgLine) })
            } catch {
                Write-PipelineLog ("ERROR callback parcheo: " + $_.Exception.ToString())
            }
        }

    # --- FASE 3: Grabaçiôn u medio ---
    if ($ImageOnlyMode) {
        $Form.Invoke([Action]{ $LblPhase.Text = '📀 Kreando er medio de îttalaçiôn (.img)'; $ProgressBar.Value = 0; $LblEta.Text = 'Êttimao: --' })
        $destDir = $ImageDestDir.Trim()
        if (-not $destDir) { $destDir = "C:\TapeOS\images" }
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        $imgName = "TapeOS-$($info.Board)-M$($info.Milestone)-$(if ($EnableGoogleApps) { 'googleapps' } else { 'aurora' }).img"
        $imgPath = Join-Path $destDir $imgName
        $cpSw = [System.Diagnostics.Stopwatch]::StartNew()
        Copy-Item -Path $patched.PatchedImagePath -Destination $imgPath -Force
        if (Test-Path $patched.ConfigFile) { Copy-Item -Path $patched.ConfigFile -Destination (Join-Path $destDir "grub.cfg") -Force }
        $elapsedStr = 'Kompletao en ' + (F-Eta $cpSw.Elapsed.TotalSeconds)
        $Form.Invoke([Action]{
            $ProgressBar.Value = 100
            $LblEta.Text = $elapsedStr
            $LogBox.AppendText("`r`n✅ ¡MEDIO DE ÎTTALAÇIÔN KREAO!`r`nArxibo: $imgPath`r`n")
            [System.Windows.Forms.MessageBox]::Show(
                "¡Medio de îttalaçiôn TapeOS kreao!`r`n`r`nRûtta: $imgPath`r`n`r`nPa uçâl-lo, grábalo en un pendraîh kon Rufû, Win32DiskImager u dêhde TapeOS (modo Live-USB).",
                "Medio de îttalaçiôn kreao", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        })
    } else {
        $Form.Invoke([Action]{ $LblPhase.Text = '💾 Grabaçiôn en er pendraîh USB'; $ProgressBar.Value = 0; $LblEta.Text = 'Êttimao: --' })
        Start-TapeOSUsbFlash `
            -ImageFilePath $patched.PatchedImagePath `
            -PhysicalDriveId $TargetUsb.DeviceID `
            -ProgressCallback {
                param($pct, $speedMBs, $written, $total)
                try {
                    $eta = if ($speedMBs -gt 0) { (($total - $written) / 1MB) / $speedMBs } else { -1 }
                    $etaStr = 'Êttimao: ' + (F-Eta $eta) + " ($speedMBs MB/s)"
                    $pctInt = [math]::Min(100, [int]$pct)
                    $Form.Invoke([Action]{ $ProgressBar.Value = $pctInt; $LblEta.Text = $etaStr })
                } catch {
                    Write-PipelineLog ("ERROR callback grabaçiôn: " + $_.Exception.ToString())
                }
            } | Out-Null
        $Form.Invoke([Action]{
            $ProgressBar.Value = 100
            $LblEta.Text = 'Kompletao'
            $LogBox.AppendText("`r`n✅ ¡PROÇEÇO KOMPLETAO KON ÉXITO!`r`nEr pendraîh êttá lîtta pa arrankâh en kualkiêh ekîpo kon EFI.`r`n")
            [System.Windows.Forms.MessageBox]::Show(
                "¡TapeOS çe á grabao kon éxito en tu pendraîh!`r`n`r`nYa pueêh reiníçiâh er ekîpo y arrankâh dêhde er pendraîh USB (têkla F12/F11/Eç en er logo).",
                "Grabaçiôn Kompletá", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        })
    }
    Write-PipelineLog "Pipeline finalizado con exito."
} catch {
    Write-PipelineLog ("ERROR pipeline: " + $_.Exception.ToString())
    try {
        $Form.Invoke([Action]{
            $LogBox.AppendText("❌ ERRÔH: $($_.Exception.Message)`r`n")
            [System.Windows.Forms.MessageBox]::Show(
                "Okurrió un errôh en er proçeço:`r`n$($_.Exception.Message)",
                "Errôh", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        })
    } catch { }
}
'@

# --- Botôn Kreâh: balidaçiôn, konfîrmaçiôn y lançe der piplîne ---
$btnCreate.Add_Click({
    try {
        $imageOnlyMode = $radioImageOnly.Checked
        $targetUsb = $null
        if (-not $imageOnlyMode) {
            $usbList = @(Get-TapeOSUsbDrives)
            if ($usbList.Count -eq 0 -or $cbUsbDrives.SelectedIndex -ge $usbList.Count) {
                [System.Windows.Forms.MessageBox]::Show("No çe detêttó nîn pun pendraîh USB. Konêtta uno y pulça 'Refrehkâh'.", "Pendraîh no detêttao", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
                Set-TapeOSStep 2
                return
            }
            $targetUsb = $usbList[$cbUsbDrives.SelectedIndex]
            $confirm = [System.Windows.Forms.MessageBox]::Show("¿Êttâh çeguro de ke kierêh grabâh TapeOS en:`r`n$($targetUsb.DisplayName)?`r`n`r`nTÔ LÔ DATÔ DER PENDRAÎH ÇE BORRARÁN.", "Konfîrmaçiôn de Grabaçiôn", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        } else {
            $confirm = [System.Windows.Forms.MessageBox]::Show("Çe dehkargará y parcheará la imâhen de ChromeOS y çe kreará er medio de îttalaçiôn (.img) en:`r`n$($txtImageDir.Text)`r`n`r`nNo çe grabará en nîn pun pendraîh.", "Konfîrmaçiôn — Kreâh er medio", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        Write-TapeOSLog "Confirmacion aceptada. Lanzando pipeline (runspace)..."
        Set-TapeOSStep 4
        $btnBack.Enabled = $false
        $btnNext.Visible = $false

        $pipelineRunspace = [runspacefactory]::CreateRunspace()
        $pipelineRunspace.ApartmentState = "STA"
        $pipelineRunspace.Open()
        $pipelinePS = [powershell]::Create()
        $pipelinePS.Runspace = $pipelineRunspace
        $null = $pipelinePS.AddScript($pipelineScript)
        $null = $pipelinePS.AddParameter("Form", $form)
        $null = $pipelinePS.AddParameter("LogBox", $logBox)
        $null = $pipelinePS.AddParameter("ProgressBar", $pbStep5)
        $null = $pipelinePS.AddParameter("LblPhase", $lblPhase)
        $null = $pipelinePS.AddParameter("LblEta", $lblEta5)
        $null = $pipelinePS.AddParameter("Codename", (($cbRecovery.SelectedItem.ToString()).Split(' ')[0]))
        $null = $pipelinePS.AddParameter("EnableGoogleApps", $radioGoogleApps.Checked)
        $null = $pipelinePS.AddParameter("ImageOnlyMode", $imageOnlyMode)
        $null = $pipelinePS.AddParameter("ImageDestDir", $txtImageDir.Text)
        $null = $pipelinePS.AddParameter("TargetUsb", $targetUsb)
        $null = $pipelinePS.AddParameter("HwReport", $hwReport)
        $null = $pipelinePS.AddParameter("ModuleDir", $moduleDir)
        $null = $pipelinePS.AddParameter("LogFile", $script:__tapeosLogFile)
        $pipelineAsync = $pipelinePS.BeginInvoke()

        $watchTimer = New-Object System.Windows.Forms.Timer
        $watchTimer.Interval = 1000
        $watchTimer.Add_Tick({
            if ($pipelineAsync.IsCompleted) {
                $watchTimer.Stop(); $watchTimer.Dispose()
                try {
                    $null = $pipelinePS.EndInvoke($pipelineAsync)
                    Write-TapeOSLog "Pipeline completado sin errores."
                } catch {
                    Write-TapeOSLog ("ERROR al finalizar pipeline: " + $_.Exception.ToString())
                } finally {
                    $pipelinePS.Dispose(); $pipelineRunspace.Dispose()
                    $btnBack.Enabled = $true
                    $btnNext.Visible = $true
                }
            }
        })
        $watchTimer.Start()
    } catch {
        Write-TapeOSLog ("ERROR en boton Crear: " + $_)
        try { [System.Windows.Forms.MessageBox]::Show("Errôh inepperao al iniçiâh er proçeço:`r`n$($_.Exception.Message)", "TapeOS", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null } catch { }
    }
})

# =============================================================================
# Iniçio der wîçâh
# =============================================================================
Refresh-UsbList
Set-TapeOSLanguage -Lang "Andaluz"
Set-TapeOSStep 0
[void]$form.ShowDialog()
