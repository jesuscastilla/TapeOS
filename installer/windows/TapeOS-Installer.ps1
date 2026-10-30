<#
.SYNOPSIS
    TapeOS Interactive Windows Installer (GUI wizard)
.DESCRIPTION
    Açîtente por paçô: Detêççiôn -> Rekomendaçiôn de Rekûperaçiôn ->
    Konfiguraçiôn -> Aplikâçionêh -> Medio -> Reçûmen -> Ehekuçiôn, kon barra de progreço y ETA
    (tiempo êttimao) en kada etapa. EPA po defêto, kon çelettôh Êppanyôh.
#>

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"") -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

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

# =============================================================================
# Utilidades de ehtilo: bîttalêh modernô, êkkinâ redondeâ y çîn parpadeo
# =============================================================================
function Set-TapeOSRounded {
    param($Control, [int]$Radius = 8)
    try {
        if ($Control.Width -le ($Radius * 2) -or $Control.Height -le ($Radius * 2)) { return }
        $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
        $d = $Radius * 2
        $gp.AddArc(0, 0, $d, $d, 180, 90)
        $gp.AddArc($Control.Width - $d, 0, $d, $d, 270, 90)
        $gp.AddArc($Control.Width - $d, $Control.Height - $d, $d, $d, 0, 90)
        $gp.AddArc(0, $Control.Height - $d, $d, $d, 90, 90)
        $gp.CloseFigure()
        $oldReg = $Control.Region
        $Control.Region = New-Object System.Drawing.Region($gp)
        if ($oldReg) { $oldReg.Dispose() }
        $gp.Dispose()
    } catch { }
}
function Enable-TapeOSDoubleBuffer {
    param($Ctrl)
    try {
        $prop = $Ctrl.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic,Instance')
        if ($prop) { $prop.SetValue($Ctrl, $true, $null) }
    } catch { }
    foreach ($child in $Ctrl.Controls) { Enable-TapeOSDoubleBuffer $child }
}
function Set-TapeOSButtonStyle {
    param($Btn, [string]$Kind = 'secondary')
    $Btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $Btn.FlatAppearance.BorderSize = 0
    $Btn.UseVisualStyleBackColor = $false
    $Btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $Btn.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    if ($Kind -eq 'primary') {
        $Btn.BackColor = [System.Drawing.Color]::FromArgb(0, 132, 61)
        $Btn.ForeColor = [System.Drawing.Color]::White
        $Btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(0, 112, 52)
        $Btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(0, 96, 44)
    } else {
        $Btn.BackColor = [System.Drawing.Color]::FromArgb(228, 236, 230)
        $Btn.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
        $Btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(215, 226, 218)
        $Btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(202, 216, 206)
    }
    Set-TapeOSRounded -Control $Btn -Radius 6
}

# Cargar módulos
$moduleDir = Join-Path $PSScriptRoot "modules"
Import-Module (Join-Path $moduleDir "HardwareDetector.psm1") -Force
Import-Module (Join-Path $moduleDir "RecoveryCatalog.psm1") -Force
Import-Module (Join-Path $moduleDir "RecoveryDownloader.psm1") -Force
Import-Module (Join-Path $moduleDir "ImagePatcher.psm1") -Force
Import-Module (Join-Path $moduleDir "UsbFlasher.psm1") -Force
Import-Module (Join-Path $moduleDir "DiskManager.psm1") -Force
Import-Module (Join-Path $moduleDir "BootManager.psm1") -Force

# Diagnóstico diferido al evento Shown: la ventana aparece al instante
$script:hwReport = $null
$script:catalog = @()
$script:rec = $null

# DPI-aware: evita el escalado borroso de Windows en pantallas de alta densidad
try {
    Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public class TapeOSNative { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }' -ErrorAction Stop
    [TapeOSNative]::SetProcessDPIAware() | Out-Null
} catch { }

# =============================================================================
# Formulario principal (redimençionable y repponçibo)
# =============================================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "TapeOS Installer — Açîtente por Paçô"
$form.ClientSize = New-Object System.Drawing.Size(1000, 715)
$form.MinimumSize = New-Object System.Drawing.Size(920, 600)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
$form.MaximizeBox = $true
$form.MinimizeBox = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(243, 246, 244)
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None

# Cabecera
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(1000, 100)
$headerPanel.Dock = [System.Windows.Forms.DockStyle]::Top
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
    # Re-escalado del logo con interpolacion de alta calidad (nitidez)
    $logoSrc = [System.Drawing.Image]::FromFile($logoPath)
    $logoBitmap = New-Object System.Drawing.Bitmap(60, 60)
    $logoG = [System.Drawing.Graphics]::FromImage($logoBitmap)
    $logoG.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $logoG.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $logoG.DrawImage($logoSrc, 0, 0, 60, 60)
    $logoG.Dispose(); $logoSrc.Dispose()
    $logoBox = New-Object System.Windows.Forms.PictureBox
    $logoBox.Image = $logoBitmap
    $logoBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::CenterImage
    $logoBox.Location = New-Object System.Drawing.Point(16, 17)
    $logoBox.Size = New-Object System.Drawing.Size(60, 60)
    $headerPanel.Controls.Add($logoBox)
}

$titleFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$titleFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
$titleFlow.WrapContents = $false
$titleFlow.AutoSize = $true
$titleFlow.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$titleFlow.BackColor = [System.Drawing.Color]::FromArgb(0, 132, 61)
$titleFlow.Location = New-Object System.Drawing.Point(88, 14)
$titleFlow.Margin = New-Object System.Windows.Forms.Padding(0)
$titleFlow.Padding = New-Object System.Windows.Forms.Padding(0)
$headerPanel.Controls.Add($titleFlow)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "TapeOS Îttaladôh Uniberçâh"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::White
$titleLabel.AutoSize = $true
$titleLabel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 2)
$titleFlow.Controls.Add($titleLabel)

$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = "Açîtente de îttalaçiôn · Andalûh"
$subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$subtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(216, 239, 225)
$subtitleLabel.AutoSize = $true
$subtitleLabel.Margin = New-Object System.Windows.Forms.Padding(0)
$titleFlow.Controls.Add($subtitleLabel)

$cbLang = New-Object System.Windows.Forms.ComboBox
$cbLang.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cbLang.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$cbLang.Location = New-Object System.Drawing.Point(812, 33)
$cbLang.Size = New-Object System.Drawing.Size(164, 28)
$cbLang.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$cbLang.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$cbLang.TabStop = $false
[void]$cbLang.Items.Add("Andaluz")
[void]$cbLang.Items.Add("Español")
$cbLang.SelectedIndex = 0
$headerPanel.Controls.Add($cbLang)

# Franja tricolor de la bandera de Andalucía (acento en la base de la cabecera)
$flagStripeG1 = New-Object System.Windows.Forms.Panel
$flagStripeG1.Location = New-Object System.Drawing.Point(0, 94)
$flagStripeG1.Size = New-Object System.Drawing.Size(333, 6)
$flagStripeG1.BackColor = [System.Drawing.Color]::FromArgb(0, 112, 52)
$headerPanel.Controls.Add($flagStripeG1)

$flagStripeW = New-Object System.Windows.Forms.Panel
$flagStripeW.Location = New-Object System.Drawing.Point(333, 94)
$flagStripeW.Size = New-Object System.Drawing.Size(334, 6)
$flagStripeW.BackColor = [System.Drawing.Color]::White
$headerPanel.Controls.Add($flagStripeW)

$flagStripeG2 = New-Object System.Windows.Forms.Panel
$flagStripeG2.Location = New-Object System.Drawing.Point(667, 94)
$flagStripeG2.Size = New-Object System.Drawing.Size(333, 6)
$flagStripeG2.BackColor = [System.Drawing.Color]::FromArgb(0, 112, 52)
$headerPanel.Controls.Add($flagStripeG2)

$headerPanel.Add_Resize({
    $w = $headerPanel.Width
    $h = $headerPanel.Height
    $y = [math]::Max(0, ($h - 6))
    $third = [int]($w / 3)
    $flagStripeG1.Location = New-Object System.Drawing.Point(0, $y)
    $flagStripeG1.Width = $third
    $flagStripeW.Location = New-Object System.Drawing.Point($third, $y)
    $flagStripeW.Width = $third
    $flagStripeG2.Location = New-Object System.Drawing.Point(($third * 2), $y)
    $flagStripeG2.Width = [math]::Max(0, ($w - ($third * 2)))
})

# =============================================================================
# Indicador de paçô (6 etapâ)
# =============================================================================
$stepIndicator = New-Object System.Windows.Forms.Panel
$stepIndicator.Location = New-Object System.Drawing.Point(24, 106)
$stepIndicator.Size = New-Object System.Drawing.Size(952, 36)
$stepIndicator.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$stepIndicator.BackColor = [System.Drawing.Color]::FromArgb(243, 246, 244)
$form.Controls.Add($stepIndicator)

$stepLabels = @()
$stepNamesEPA = @("1. Detêççiôn", "2. Rekûperaçiôn", "3. Aplikâçionêh", "4. Medio", "5. Reçûmen", "6. Ehekuçiôn")
$stepNamesES  = @("1. Detección", "2. Recovery", "3. Aplicaciones", "4. Medio", "5. Resumen", "6. Ejecución")
for ($i = 0; $i -lt 6; $i++) {
    $sl = New-Object System.Windows.Forms.Label
    $sl.Text = $stepNamesEPA[$i]
    $sl.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
    $sl.ForeColor = [System.Drawing.Color]::FromArgb(80, 104, 90)
    $sl.BackColor = [System.Drawing.Color]::FromArgb(231, 238, 233)
    $sl.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $stepX = 1 + ($i * 160)
    $sl.Location = New-Object System.Drawing.Point($stepX, 0)
    $sl.Size = New-Object System.Drawing.Size(150, 36)
    Set-TapeOSRounded -Control $sl -Radius 18
    $stepIndicator.Controls.Add($sl)
    $stepLabels += $sl
}

function Update-TapeOSStepChips {
    $totalW = $stepIndicator.Width
    $count = $stepLabels.Count
    if ($count -eq 0) { return }
    $gap = 8
    $chipW = [math]::Min(180, [math]::Max(100, [int](($totalW - ($gap * ($count - 1))) / $count)))
    $usedW = ($chipW * $count) + ($gap * ($count - 1))
    $startX = [math]::Max(0, [int](($totalW - $usedW) / 2))
    for ($i = 0; $i -lt $count; $i++) {
        $stepLabels[$i].Location = New-Object System.Drawing.Point(($startX + ($i * ($chipW + $gap))), 0)
        $stepLabels[$i].Size = New-Object System.Drawing.Size($chipW, 36)
        Set-TapeOSRounded -Control $stepLabels[$i] -Radius 18
    }
}
$stepIndicator.Add_Resize({ Update-TapeOSStepChips })
Update-TapeOSStepChips

# Tarjeta de contenido (una bîtta po paço): borde suabe y êkkinâ redondeâ
$cardShell = New-Object System.Windows.Forms.Panel
$cardShell.Location = New-Object System.Drawing.Point(24, 148)
$cardShell.Size = New-Object System.Drawing.Size(952, 372)
$cardShell.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$cardShell.BackColor = [System.Drawing.Color]::FromArgb(214, 222, 217)
Set-TapeOSRounded -Control $cardShell -Radius 10
$form.Controls.Add($cardShell)

$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Location = New-Object System.Drawing.Point(1, 1)
$contentPanel.Size = New-Object System.Drawing.Size(950, 370)
$contentPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$contentPanel.BackColor = [System.Drawing.Color]::White
Set-TapeOSRounded -Control $contentPanel -Radius 9
$cardShell.Controls.Add($contentPanel)

$cardShell.Add_Resize({
    if ($cardShell.Width -gt 10 -and $cardShell.Height -gt 10) {
        $contentPanel.Size = New-Object System.Drawing.Size(($cardShell.Width - 2), ($cardShell.Height - 2))
        Set-TapeOSRounded -Control $cardShell -Radius 10
        Set-TapeOSRounded -Control $contentPanel -Radius 9
    }
})

# --- PAÇO 1: Detêççiôn de hardware ---
$pnl1 = New-Object System.Windows.Forms.Panel
$pnl1.Location = New-Object System.Drawing.Point(0, 0)
$pnl1.Size = $contentPanel.Size
$pnl1.Dock = [System.Windows.Forms.DockStyle]::Fill
$pnl1.BackColor = [System.Drawing.Color]::White

$lblHwTitle = New-Object System.Windows.Forms.Label
$lblHwTitle.Text = "Detêççiôn de hardware"
$lblHwTitle.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
$lblHwTitle.ForeColor = [System.Drawing.Color]::FromArgb(23, 53, 43)
$lblHwTitle.Location = New-Object System.Drawing.Point(24, 16)
$lblHwTitle.AutoSize = $true
$pnl1.Controls.Add($lblHwTitle)

$lblHwInfo = New-Object System.Windows.Forms.Label
$lblHwInfo.Text = "Deteôtando el hardware..."
$lblHwInfo.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblHwInfo.ForeColor = [System.Drawing.Color]::FromArgb(51, 65, 58)
$lblHwInfo.Location = New-Object System.Drawing.Point(24, 54)
$lblHwInfo.Size = New-Object System.Drawing.Size(902, 220)
$lblHwInfo.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$pnl1.Controls.Add($lblHwInfo)

$pbStep1 = New-Object System.Windows.Forms.ProgressBar
$pbStep1.Location = New-Object System.Drawing.Point(24, 286)
$pbStep1.Size = New-Object System.Drawing.Size(902, 22)
$pbStep1.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$pbStep1.Value = 100
$pnl1.Controls.Add($pbStep1)

$lblEta1 = New-Object System.Windows.Forms.Label
$lblEta1.Text = "Êttimao: 0 ç (kompletao)"
$lblEta1.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$lblEta1.ForeColor = [System.Drawing.Color]::FromArgb(107, 122, 114)
$lblEta1.Location = New-Object System.Drawing.Point(24, 318)
$lblEta1.AutoSize = $true
$lblEta1.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$pnl1.Controls.Add($lblEta1)

$contentPanel.Controls.Add($pnl1)

# --- PAÇO 2: Rekomendaçiôn de rekûperaçiôn ---
$pnl2 = New-Object System.Windows.Forms.Panel
$pnl2.Location = New-Object System.Drawing.Point(0, 0)
$pnl2.Size = $contentPanel.Size
$pnl2.Dock = [System.Windows.Forms.DockStyle]::Fill
$pnl2.BackColor = [System.Drawing.Color]::White

$lblRecTitle = New-Object System.Windows.Forms.Label
$lblRecTitle.Text = "Rekomendaçiôn de rekûperaçiôn"
$lblRecTitle.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
$lblRecTitle.ForeColor = [System.Drawing.Color]::FromArgb(23, 53, 43)
$lblRecTitle.Location = New-Object System.Drawing.Point(24, 16)
$lblRecTitle.AutoSize = $true
$pnl2.Controls.Add($lblRecTitle)

$lblRecInfo = New-Object System.Windows.Forms.Label
$lblRecInfo.Text = "..."
$lblRecInfo.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblRecInfo.ForeColor = [System.Drawing.Color]::FromArgb(51, 65, 58)
$lblRecInfo.Location = New-Object System.Drawing.Point(24, 46)
$lblRecInfo.Size = New-Object System.Drawing.Size(902, 40)
$lblRecInfo.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$pnl2.Controls.Add($lblRecInfo)

$cbRecovery = New-Object System.Windows.Forms.ComboBox
$cbRecovery.Location = New-Object System.Drawing.Point(24, 96)
$cbRecovery.Size = New-Object System.Drawing.Size(600, 28)
$cbRecovery.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cbRecovery.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$cbRecovery.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$cbRecovery.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$pnl2.Controls.Add($cbRecovery)

$btnCheckOnline = New-Object System.Windows.Forms.Button
$btnCheckOnline.Text = "🌐 Bûhkâh la Ûrtima Berçiôn"
$btnCheckOnline.Location = New-Object System.Drawing.Point(644, 94)
$btnCheckOnline.Size = New-Object System.Drawing.Size(282, 32)
$btnCheckOnline.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$pnl2.Controls.Add($btnCheckOnline)
Set-TapeOSButtonStyle -Btn $btnCheckOnline -Kind 'secondary'

$lblStatusUrl = New-Object System.Windows.Forms.Label
$lblStatusUrl.Text = "Berçiôn ofiçiâh mâh reçiente: pulça 'Bûhkâh' pa konhûttâh er CDN de Google."
$lblStatusUrl.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$lblStatusUrl.ForeColor = [System.Drawing.Color]::FromArgb(107, 122, 114)
$lblStatusUrl.Location = New-Object System.Drawing.Point(24, 138)
$lblStatusUrl.Size = New-Object System.Drawing.Size(902, 46)
$lblStatusUrl.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$pnl2.Controls.Add($lblStatusUrl)

$pbStep2 = New-Object System.Windows.Forms.ProgressBar
$pbStep2.Location = New-Object System.Drawing.Point(24, 196)
$pbStep2.Size = New-Object System.Drawing.Size(902, 18)
$pbStep2.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
$pbStep2.Visible = $false
$pbStep2.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$pnl2.Controls.Add($pbStep2)

$lblEta2 = New-Object System.Windows.Forms.Label
$lblEta2.Text = ""
$lblEta2.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$lblEta2.ForeColor = [System.Drawing.Color]::FromArgb(107, 122, 114)
$lblEta2.Location = New-Object System.Drawing.Point(24, 222)
$lblEta2.AutoSize = $true
$lblEta2.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$pnl2.Controls.Add($lblEta2)

$contentPanel.Controls.Add($pnl2)

# --- PAÇO 3: Aplikâçionêh y çoftware ---
$pnl3 = New-Object System.Windows.Forms.Panel
$pnl3.Location = New-Object System.Drawing.Point(0, 0)
$pnl3.Size = $contentPanel.Size
$pnl3.Dock = [System.Windows.Forms.DockStyle]::Fill
$pnl3.BackColor = [System.Drawing.Color]::White

$lblAppsTitle = New-Object System.Windows.Forms.Label
$lblAppsTitle.Text = "Aplikâçionêh y çoftware"
$lblAppsTitle.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
$lblAppsTitle.ForeColor = [System.Drawing.Color]::FromArgb(23, 53, 43)
$lblAppsTitle.Location = New-Object System.Drawing.Point(24, 16)
$lblAppsTitle.AutoSize = $true
$pnl3.Controls.Add($lblAppsTitle)

$radioLibre = New-Object System.Windows.Forms.RadioButton
$radioLibre.Text = "🔓 Çoftware Libre — çîn Googlêh Play (rekomendao)"
$radioLibre.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$radioLibre.ForeColor = [System.Drawing.Color]::FromArgb(35, 48, 40)
$radioLibre.Location = New-Object System.Drawing.Point(24, 58)
$radioLibre.AutoSize = $true
$radioLibre.Checked = $true
$pnl3.Controls.Add($radioLibre)

$radioGoogleApps = New-Object System.Windows.Forms.RadioButton
$radioGoogleApps.Text = "🛍️ Kon Googlêh Play — Android kompleto"
$radioGoogleApps.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$radioGoogleApps.ForeColor = [System.Drawing.Color]::FromArgb(35, 48, 40)
$radioGoogleApps.Location = New-Object System.Drawing.Point(24, 96)
$radioGoogleApps.AutoSize = $true
$radioGoogleApps.Checked = $false
$pnl3.Controls.Add($radioGoogleApps)

$lblAppsExplain = New-Object System.Windows.Forms.Label
$lblAppsExplain.Text = "..."
$lblAppsExplain.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblAppsExplain.ForeColor = [System.Drawing.Color]::FromArgb(51, 65, 58)
$lblAppsExplain.Location = New-Object System.Drawing.Point(24, 144)
$lblAppsExplain.Size = New-Object System.Drawing.Size(902, 210)
$lblAppsExplain.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$pnl3.Controls.Add($lblAppsExplain)

$contentPanel.Controls.Add($pnl3)

# --- PAÇO 4: Medio de îttalaçiôn ---
$pnl4 = New-Object System.Windows.Forms.Panel
$pnl4.Location = New-Object System.Drawing.Point(0, 0)
$pnl4.Size = $contentPanel.Size
$pnl4.Dock = [System.Windows.Forms.DockStyle]::Fill
$pnl4.BackColor = [System.Drawing.Color]::White

$lblMediaTitle = New-Object System.Windows.Forms.Label
$lblMediaTitle.Text = "Medio de îttalaçiôn"
$lblMediaTitle.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
$lblMediaTitle.ForeColor = [System.Drawing.Color]::FromArgb(23, 53, 43)
$lblMediaTitle.Location = New-Object System.Drawing.Point(24, 16)
$lblMediaTitle.AutoSize = $true
$pnl4.Controls.Add($lblMediaTitle)

$radioImageOnly = New-Object System.Windows.Forms.RadioButton
$radioImageOnly.Text = "📀 Kreâh er medio de îttalaçiôn (.img) — guâddâlo en er dîkko"
$radioImageOnly.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$radioImageOnly.ForeColor = [System.Drawing.Color]::FromArgb(35, 48, 40)
$radioImageOnly.Location = New-Object System.Drawing.Point(24, 58)
$radioImageOnly.AutoSize = $true
$radioImageOnly.Checked = $true
$pnl4.Controls.Add($radioImageOnly)

$txtImageDir = New-Object System.Windows.Forms.TextBox
$txtImageDir.Text = "C:\TapeOS\images"
$txtImageDir.Location = New-Object System.Drawing.Point(58, 100)
$txtImageDir.Size = New-Object System.Drawing.Size(600, 28)
$txtImageDir.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$txtImageDir.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$pnl4.Controls.Add($txtImageDir)

$btnBrowseDir = New-Object System.Windows.Forms.Button
$btnBrowseDir.Text = "📂 Ehkaminâh..."
$btnBrowseDir.Location = New-Object System.Drawing.Point(674, 98)
$btnBrowseDir.Size = New-Object System.Drawing.Size(252, 32)
$btnBrowseDir.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$pnl4.Controls.Add($btnBrowseDir)
Set-TapeOSButtonStyle -Btn $btnBrowseDir -Kind 'secondary'

$radioUsb = New-Object System.Windows.Forms.RadioButton
$radioUsb.Text = "💾 Live-USB — Grabâh en un pendraîh USB y arrankâh dêhde él"
$radioUsb.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$radioUsb.ForeColor = [System.Drawing.Color]::FromArgb(35, 48, 40)
$radioUsb.Location = New-Object System.Drawing.Point(24, 158)
$radioUsb.AutoSize = $true
$radioUsb.Checked = $false
$pnl4.Controls.Add($radioUsb)

$cbUsbDrives = New-Object System.Windows.Forms.ComboBox
$cbUsbDrives.Location = New-Object System.Drawing.Point(58, 200)
$cbUsbDrives.Size = New-Object System.Drawing.Size(600, 28)
$cbUsbDrives.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cbUsbDrives.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$cbUsbDrives.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$cbUsbDrives.Enabled = $false
$cbUsbDrives.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$pnl4.Controls.Add($cbUsbDrives)

$btnRefreshUsb = New-Object System.Windows.Forms.Button
$btnRefreshUsb.Text = "🔄 Refrehkâh"
$btnRefreshUsb.Location = New-Object System.Drawing.Point(674, 198)
$btnRefreshUsb.Size = New-Object System.Drawing.Size(252, 32)
$btnRefreshUsb.Enabled = $false
$btnRefreshUsb.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$pnl4.Controls.Add($btnRefreshUsb)
Set-TapeOSButtonStyle -Btn $btnRefreshUsb -Kind 'secondary'

$lblUsbWarning = New-Object System.Windows.Forms.Label
$lblUsbWarning.Text = "OHO: Er pendraîh çelehçionao çe formateará po kompleto pa îttalâh TapeOS."
$lblUsbWarning.ForeColor = [System.Drawing.Color]::FromArgb(178, 59, 59)
$lblUsbWarning.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$lblUsbWarning.Location = New-Object System.Drawing.Point(24, 248)
$lblUsbWarning.Size = New-Object System.Drawing.Size(902, 24)
$lblUsbWarning.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$pnl4.Controls.Add($lblUsbWarning)
# Opcion de firmware: BIOS Legacy (sin UEFI)
$chkBiosMode = New-Object System.Windows.Forms.CheckBox
$chkBiosMode.Text = "🖥️ Modo BIÔ (çin UEFI)"
$chkBiosMode.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$chkBiosMode.Location = New-Object System.Drawing.Point(24, 300)
$chkBiosMode.AutoSize = $true
$pnl4.Controls.Add($chkBiosMode)

$lblBiosInfo = New-Object System.Windows.Forms.Label
$lblBiosInfo.Text = "Pa ekîpô anteriôh a ~2012 çin UEFI: arrankâh por MBR en lûgâh de EFI. La imâhen de TapeOS êh îbriá (çirbe pa lô dô modô); márkalo çolo çi tu ekîpo arranka únikamente en BIÔ Legâyy."
$lblBiosInfo.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblBiosInfo.ForeColor = [System.Drawing.Color]::FromArgb(107, 122, 114)
$lblBiosInfo.Location = New-Object System.Drawing.Point(40, 326)
$lblBiosInfo.Size = New-Object System.Drawing.Size(880, 44)
$pnl4.Controls.Add($lblBiosInfo)

$contentPanel.Controls.Add($pnl4)

# --- PAÇO 5: Reçûmen ---
$pnl5 = New-Object System.Windows.Forms.Panel
$pnl5.Location = New-Object System.Drawing.Point(0, 0)
$pnl5.Size = $contentPanel.Size
$pnl5.Dock = [System.Windows.Forms.DockStyle]::Fill
$pnl5.BackColor = [System.Drawing.Color]::White

$lblSumTitle = New-Object System.Windows.Forms.Label
$lblSumTitle.Text = "Reçûmen de la îttalaçiôn"
$lblSumTitle.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
$lblSumTitle.ForeColor = [System.Drawing.Color]::FromArgb(23, 53, 43)
$lblSumTitle.Location = New-Object System.Drawing.Point(24, 16)
$lblSumTitle.AutoSize = $true
$pnl5.Controls.Add($lblSumTitle)

$lblSummary = New-Object System.Windows.Forms.Label
$lblSummary.Text = "..."
$lblSummary.Font = New-Object System.Drawing.Font("Segoe UI", 10.5)
$lblSummary.ForeColor = [System.Drawing.Color]::FromArgb(35, 48, 40)
$lblSummary.Location = New-Object System.Drawing.Point(24, 54)
$lblSummary.Size = New-Object System.Drawing.Size(902, 230)
$lblSummary.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$pnl5.Controls.Add($lblSummary)

$btnCreate = New-Object System.Windows.Forms.Button
$btnCreate.Text = "Vamoh!"
$btnCreate.Location = New-Object System.Drawing.Point(275, 300)
$btnCreate.Size = New-Object System.Drawing.Size(400, 52)
Set-TapeOSButtonStyle -Btn $btnCreate -Kind 'primary'
$btnCreate.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$btnCreate.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom
$pnl5.Controls.Add($btnCreate)

$pnl5.Add_Resize({
    $btnCreate.Left = [int](($pnl5.Width - $btnCreate.Width) / 2)
})

$contentPanel.Controls.Add($pnl5)

# --- PAÇO 6: Ehekuçiôn ---
$pnl6 = New-Object System.Windows.Forms.Panel
$pnl6.Location = New-Object System.Drawing.Point(0, 0)
$pnl6.Size = $contentPanel.Size
$pnl6.Dock = [System.Windows.Forms.DockStyle]::Fill
$pnl6.BackColor = [System.Drawing.Color]::White

$lblPhase = New-Object System.Windows.Forms.Label
$lblPhase.Text = "Êpperando..."
$lblPhase.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
$lblPhase.ForeColor = [System.Drawing.Color]::FromArgb(23, 53, 43)
$lblPhase.Location = New-Object System.Drawing.Point(24, 16)
$lblPhase.Size = New-Object System.Drawing.Size(902, 28)
$lblPhase.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$pnl6.Controls.Add($lblPhase)

$pbStep5 = New-Object System.Windows.Forms.ProgressBar
$pbStep5.Location = New-Object System.Drawing.Point(24, 60)
$pbStep5.Size = New-Object System.Drawing.Size(902, 32)
$pbStep5.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$pnl6.Controls.Add($pbStep5)

$lblEta5 = New-Object System.Windows.Forms.Label
$lblEta5.Text = "Êttimao: --"
$lblEta5.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$lblEta5.ForeColor = [System.Drawing.Color]::FromArgb(107, 122, 114)
$lblEta5.Location = New-Object System.Drawing.Point(24, 108)
$lblEta5.Size = New-Object System.Drawing.Size(902, 24)
$lblEta5.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$pnl6.Controls.Add($lblEta5)

$contentPanel.Controls.Add($pnl6)

# =============================================================================
# Log, botonêh de nabegaçiôn y funçionêh der wîçâh
# =============================================================================
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(24, 532)
$logBox.Size = New-Object System.Drawing.Size(952, 92)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.BackColor = [System.Drawing.Color]::FromArgb(14, 21, 18)
$logBox.ForeColor = [System.Drawing.Color]::FromArgb(140, 231, 165)
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9.5)
$logBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$logBox.Text = "=== TapeOS Lîtta ===`r`n"
$logBox.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($logBox)

$btnBack = New-Object System.Windows.Forms.Button
$btnBack.Text = "‹ Anteriôh"
$btnBack.Location = New-Object System.Drawing.Point(24, 638)
$btnBack.Size = New-Object System.Drawing.Size(160, 46)
$btnBack.Enabled = $false
$btnBack.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
Set-TapeOSButtonStyle -Btn $btnBack -Kind 'secondary'
$form.Controls.Add($btnBack)

$btnNext = New-Object System.Windows.Forms.Button
$btnNext.Text = "Çiguiente ›"
$btnNext.Location = New-Object System.Drawing.Point(816, 638)
$btnNext.Size = New-Object System.Drawing.Size(160, 46)
$btnNext.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
Set-TapeOSButtonStyle -Btn $btnNext -Kind 'primary'
$form.Controls.Add($btnNext)

$stepPanels = @($pnl1, $pnl2, $pnl3, $pnl4, $pnl5, $pnl6)
$script:currentStep = 0
$script:langEPA = $true

function Set-TapeOSStep {
    param([int]$StepIndex)
    $script:currentStep = $StepIndex
    for ($i = 0; $i -lt $stepPanels.Count; $i++) {
        $stepPanels[$i].Visible = ($i -eq $StepIndex)
    }
    for ($i = 0; $i -lt $stepLabels.Count; $i++) {
        if ($i -eq $StepIndex) {
            $stepLabels[$i].ForeColor = [System.Drawing.Color]::White
            $stepLabels[$i].BackColor = [System.Drawing.Color]::FromArgb(0, 132, 61)
            $stepLabels[$i].Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
        } else {
            $stepLabels[$i].ForeColor = [System.Drawing.Color]::FromArgb(80, 104, 90)
            $stepLabels[$i].BackColor = [System.Drawing.Color]::FromArgb(231, 238, 233)
            $stepLabels[$i].Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
        }
    }
    $btnBack.Enabled = ($StepIndex -gt 0 -and $StepIndex -lt 5)
    $btnNext.Visible = ($StepIndex -lt 4)
    if ($StepIndex -eq 4) {
        $sumMode = if ($radioImageOnly.Checked) { "Îttaladôh (.img) → $($txtImageDir.Text)" } else { "Live-USB → $(if ($cbUsbDrives.SelectedItem) { $cbUsbDrives.SelectedItem.ToString() } else { '(çelehçiona pendraîh)' })" }
        $lblSummary.Text = @"
$(if ($script:langEPA) {
"• Rekûperaçiôn: $((($cbRecovery.SelectedItem.ToString()).Split(' ')[0]).ToUpper()) $(if ($script:recoveryInfo) { "- Milestone $($script:recoveryInfo.Milestone)" } else { '' })
• Aplikâçionêh: $(if ($radioLibre.Checked) { 'Çoftware Libre (APK + Aurora Çtore)' } else { 'Googlêh Play (Çtore + Android)' })
• Medio: $sumMode
• Parcheh de hardware: $(if ($script:patchList) { $script:patchList } else { 'nîn guno' })"
} else {
"• Recovery: $((($cbRecovery.SelectedItem.ToString()).Split(' ')[0]).ToUpper()) $(if ($script:recoveryInfo) { "- Milestone $($script:recoveryInfo.Milestone)" } else { '' })
• Aplicaciones: $(if ($radioLibre.Checked) { 'Software Libre (APK + Aurora Store)' } else { 'Google Play (Store + Android)' })
• Medio: $sumMode
• Parches de hardware: $(if ($script:patchList) { $script:patchList } else { 'ninguno' })"
})
"@
    }
}

function Refresh-UsbList {
    $cbUsbDrives.Items.Clear()
    $usbList = @(Get-TapeOSUsbDrives)
    if ($usbList.Count -eq 0) {
        [void]$cbUsbDrives.Items.Add("No çe detêttó nîn pun pendraîh USB")
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

function Get-HwSummaryText {
    param([bool]$EPA)
    if (-not $script:hwReport) {
        return if ($EPA) { "Deteôtando el hardware...`r`n`r`n" } else { "Detectando el hardware...`r`n`r`n" }
    }
    $wifiSummary = if ($script:hwReport.Network.WiFi.Count -gt 0) { (($script:hwReport.Network.WiFi | ForEach-Object { $_.Name }) -join ', ') } else { '—' }
    $btSummary = if ($script:hwReport.Network.Bluetooth.Count -gt 0) { (($script:hwReport.Network.Bluetooth | ForEach-Object { $_.Name }) -join ', ') } else { '—' }
    $audioSummary = if ($script:hwReport.Audio.Count -gt 0) { (($script:hwReport.Audio | ForEach-Object { $_.Name }) -join ', ') } else { '—' }
    $touchSummary = if ($script:hwReport.Touchscreen.Count -gt 0) { (($script:hwReport.Touchscreen | ForEach-Object { $_.Name }) -join ', ') } else { '—' }
    $script:patchList = (($script:hwReport.FrameworkPatches | ForEach-Object { $_.Option }) -join ', ')
    $gpuSummary = (($script:hwReport.GPU | ForEach-Object { "$($_.Name) $(if ($_.VendorId -eq '10DE') { '(NVIDIA)' } elseif ($_.VendorId -eq '1002') { '(AMD)' } elseif ($_.VendorId -eq '8086') { '(Intel)' } else { '' })" }) -join ', ')
    if ($EPA) {
        $sbon  = if ($script:hwReport.Firmware.SecureBoot) { 'Attibo ' } else { 'Inattibo ' }
        $blon  = if ($script:hwReport.Security.BitLockerActive) { 'ATTIBO ' } else { 'Inattibo ' }
        $wifi  = if ($wifiSummary -ne '—') { $wifiSummary } else { 'No detêttao' }
        $bt    = if ($btSummary -ne '—') { $btSummary } else { 'No detêttao' }
        $audio = if ($audioSummary -ne '—') { $audioSummary } else { 'Çoportao' }
        $touch = if ($touchSummary -ne '—') { $touchSummary } else { 'No detêttá' }
        $patches = if ($script:patchList) { $script:patchList } else { 'nîn guno neçeçario' }
        return @"
• CPU: $($script:hwReport.CPU.Name) ($($script:hwReport.CPU.Generation))
• Firmware: $($script:hwReport.Firmware.Type)  |  Secure Boot: $sbon  |  BitLocker: $blon
• GPU: $gpuSummary
• WiFi: $wifi   |   Bluetooth: $bt
• Audio: $audio   |   Tâttîh: $touch
• Parcheh de hardware detêttáô: $patches
"@
    } else {
        $sbon  = if ($script:hwReport.Firmware.SecureBoot) { 'Activo ' } else { 'Inactivo ✅' }
        $blon  = if ($script:hwReport.Security.BitLockerActive) { 'ACTIVO ⚠️' } else { 'Inactivo ✅' }
        $wifi  = if ($wifiSummary -ne '—') { $wifiSummary } else { 'No detectado' }
        $bt    = if ($btSummary -ne '—') { $btSummary } else { 'No detectado' }
        $audio = if ($audioSummary -ne '—') { $audioSummary } else { 'Soportado' }
        $touch = if ($touchSummary -ne '—') { $touchSummary } else { 'No detectado' }
        $patches = if ($script:patchList) { $script:patchList } else { 'ninguno necesario' }
        return @"
• CPU: $($script:hwReport.CPU.Name) ($($script:hwReport.CPU.Generation))
• Firmware: $($script:hwReport.Firmware.Type)  |  Secure Boot: $sbon  |  BitLocker: $blon
• GPU: $gpuSummary
• WiFi: $wifi   |   Bluetooth: $bt
• Audio: $audio   |   Táctil: $touch
• Parches de hardware detectados: $patches
"@
    }
}

function Get-AppsExplainText {
    param([bool]$EPA)
    if ($radioLibre.Checked) {
        if ($EPA) { return "TapeOS 100% libre: çîn nîn pun çerbiçio de Google.`r`nLâ aplikâçionêh Android çe îttalan mediante arxibô APK o la tienda Aurora (arrepôi êtico de Play).`r`nÎdeal pa privâçidá, reûtiliçaçiôn de ekîpô bîehô y comunidá de çoftware libre." }
        return "TapeOS 100% libre: sin ningún servicio de Google.`r`nLas aplicaciones Android se instalan mediante archivos APK o la tienda Aurora (sustituto ético de Play).`r`nIdeal para privacidad, reutilización de equipos antiguos y comunidad de software libre."
    } else {
        if ($EPA) { return "Inkluye Play Çtore y lô çerbiçiô de Google.`r`nLa baçe der çîttema (ChromiumOS) çige çiendo libre, pero çe añaden komponentê propietariô de Google pa dâh çoportê kompleto a lâ aplikâçionêh Android." }
        return "Incluye Play Store y los servicios de Google.`r`nLa base del sistema (ChromiumOS) sigue siendo libre, pero se añaden componentes propietarios de Google para dar soporte completo a las aplicaciones Android."
    }
}

function Set-TapeOSLanguage {
    param([string]$Lang)
    $isEPA = ($Lang -eq "Andaluz")
    $script:langEPA = $isEPA
    $titleLabel.Text = if ($isEPA) { "TapeOS Îttaladôh Uniberçâh" } else { "TapeOS instalador universal" }
    $subtitleLabel.Text = if ($isEPA) { "Açîtente de îttalaçiôn · Andalûh" } else { "Asistente de instalación · Español" }
    for ($i = 0; $i -lt 6; $i++) { $stepLabels[$i].Text = if ($isEPA) { $stepNamesEPA[$i] } else { $stepNamesES[$i] } }
    $lblHwTitle.Text = if ($isEPA) { "Detêççiôn de hardware" } else { "Detección de hardware" }
    $lblHwInfo.Text = Get-HwSummaryText $isEPA
    $lblRecTitle.Text = if ($isEPA) { "Rekomendaçiôneh" } else { "Recomendaciones" }
    if ($script:rec) {
        $lblRecInfo.Text = if ($isEPA) { "Çegún tu hardware, la rekûperaçiôn rekomendá êh [$($script:rec.RecoveryCodename.ToUpper())] kon kernel [$($script:rec.Kernel)]." } else { "Según tu hardware, el recovery recomendado es [$($script:rec.RecoveryCodename.ToUpper())] con kernel [$($script:rec.Kernel)]." }
    } else {
        $lblRecInfo.Text = "..."
    }
    $btnCheckOnline.Text = if ($isEPA) { "🌐 Bûhkâh la Ûrtima Berçiôn" } else { "🌐 Buscar Última Versión" }
    $lblStatusUrl.Text = if ($isEPA) { "Berçiôn ofiçiâh mâh reçiente: pulça 'Bûhkâh' pa konhûttâh er CDN de Google." } else { "Versión oficial más reciente: pulsa 'Buscar' para consultar el CDN de Google." }
    $lblAppsTitle.Text = if ($isEPA) { "Aplikâçionêh y çoftware" } else { "Aplicaciones y software" }
    $radioLibre.Text = if ($isEPA) { "🔓 Çoftware Libre — çîn Googlêh Play (rekomendao)" } else { "🔓 Software Libre — sin Google Play (recomendado)" }
    $radioGoogleApps.Text = if ($isEPA) { "🛍️ Kon Googlêh Play — Android kompleto" } else { "🛍️ Con Google Play — Android completo" }
    $lblAppsExplain.Text = Get-AppsExplainText $isEPA
    $lblMediaTitle.Text = if ($isEPA) { "Medio de îttalaçiôn" } else { "Medio de instalación" }
    $radioUsb.Text = if ($isEPA) { "💾 Live-USB — Grabâh en un pendraîh USB y arrankâh dêhde él" } else { "💾 Live-USB — Grabar en un pendrive USB y arrancar desde él" }
    $btnRefreshUsb.Text = if ($isEPA) { "🔄 Refrehkâh" } else { "🔄 Refrescar" }
    $radioImageOnly.Text = if ($isEPA) { "📀 Kreâh er medio de îttalaçiôn (.img) — guâddâlo en er dîkko" } else { "📀 Crear el medio de instalación (.img) — guardarlo en el disco" }
    $btnBrowseDir.Text = if ($isEPA) { "📂 Ehkaminâh..." } else { "📂 Examinar..." }
    $lblUsbWarning.Text = if ($isEPA) { "⚠️ OHO: Er pendraîh çelehçionao çe formateará po kompleto pa îttalâh TapeOS." } else { "⚠️ ATENCIÓN: El pendrive seleccionado se formateará por completo para instalar TapeOS." }
    $chkBiosMode.Text = if ($isEPA) { "🖥️ Modo BIÔ (çin UEFI)" } else { "🖥️ Modo BIOS (sin UEFI)" }
    $lblBiosInfo.Text = if ($isEPA) { "Pa ekîpô anteriôh a ~2012 çin UEFI: arrankâh por MBR en lûgâh de EFI. La imâhen de TapeOS êh îbriá (çirbe pa lô dô modô); márkalo çolo çi tu ekîpo arranka únikamente en BIÔ Legâyy." } else { "Para equipos anteriores a ~2012 sin UEFI: arranque por MBR en lugar de EFI. La imagen de TapeOS es híbrida (sirve para ambos modos); márcalo solo si tu equipo arranca únicamente en BIOS Legacy." }
    $lblSumTitle.Text = if ($isEPA) { "Reçûmen de la îttalaçiôn" } else { "Resumen de la instalación" }
    $btnCreate.Text = if ($isEPA) { "⚡ Dehkargâh, Parcheâh y Kreâh (1-Klik)" } else { "⚡ Descargar, Parchear y Crear (1-Clic)" }
    $lblEta5.Text = if ($isEPA) { "Êttimao: --" } else { "Estimado: --" }
    $btnBack.Text = if ($isEPA) { "‹ Anteriôh" } else { "‹ Anterior" }
    $btnNext.Text = if ($isEPA) { "Çiguiente ›" } else { "Siguiente ›" }
    $lblEta1.Text = if ($isEPA) { "Êttimao: 0 ç (kompletao)" } else { "Estimado: 0 s (completado)" }
    if ($script:currentStep -eq 4) { Set-TapeOSStep 4 }
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

$radioLibre.Add_Click({
    $lblAppsExplain.Text = Get-AppsExplainText $script:langEPA
})
$radioGoogleApps.Add_Click({
    $lblAppsExplain.Text = Get-AppsExplainText $script:langEPA
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
    $timedOut = $false
    $qTimer = New-Object System.Windows.Forms.Timer
    $qTimer.Interval = 200
    $qTimer.Add_Tick({
        $el = $sw.Elapsed.TotalSeconds
        $lblEta2.Text = "Êttimao: " + (Format-ETA ([math]::Max(0.5, (5 - $el))))
        if ($async.IsCompleted -or $timedOut) {
            $qTimer.Stop(); $qTimer.Dispose()
            $pbStep2.Visible = $false
            try {
                $script:recoveryInfo = $ps.EndInvoke($async)
                if (-not $timedOut) {
                    $lblStatusUrl.Text = "✔ Berçiôn: Milestone $($script:recoveryInfo.Milestone) | Arxibo: $($script:recoveryInfo.FileName)"
                    $lblEta2.Text = "Kompletao en $(Format-ETA $el)"
                    $logBox.AppendText("[ChromiumDash] Berçiôn Milestone $($script:recoveryInfo.Milestone) enkontrá.`r`n")
                }
            } catch {
                Write-TapeOSLog ("ERROR consulta API: " + $_.Exception.ToString())
                if ($timedOut) {
                    $lblStatusUrl.Text = if ($script:langEPA) { "❌ Tîmpo agotao (15 ç, ¿çîn internet?). Çe uçará la berçiôn êttable der katálogo lokâh." } else { "❌ Tiempo agotado (15 s, ¿sin internet?). Se usará la versión estable del catálogo local." }
                } else {
                    $lblStatusUrl.Text = "❌ No çe pudo konhûttâh la API: $($_.Exception.Message)"
                }
                $lblEta2.Text = ""
            } finally {
                $ps.Dispose(); $rs.Dispose()
                $btnCheckOnline.Enabled = $true
            }
        } elseif ($el -gt 15) {
            # Timeout: se cancela la consulta; el siguiente tick la recoge como completada con error
            $timedOut = $true
            try { $ps.Stop() | Out-Null } catch { }
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
Import-Module (Join-Path $ModuleDir "BootManager.psm1") -Force
Import-Module (Join-Path $ModuleDir "FrameworkInstaller.psm1") -Force
Import-Module (Join-Path $ModuleDir "ImageCatalog.psm1") -Force

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
        $Form.Invoke([Action]{ $LblPhase.Text = 'Kreando er medio de îttalaçiôn (.img)'; $ProgressBar.Value = 0; $LblEta.Text = 'Êttimao: --' })
        $destDir = $ImageDestDir.Trim()
        if (-not $destDir) { $destDir = "C:\TapeOS\images" }
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        $imgName = "TapeOS-$($info.Board)-M$($info.Milestone)-$(if ($EnableGoogleApps) { 'googleapps' } else { 'aurora' }).img"
        $imgPath = Join-Path $destDir $imgName
        $cpSw = [System.Diagnostics.Stopwatch]::StartNew()
        Copy-Item -Path $patched.PatchedImagePath -Destination $imgPath -Force
        if (Test-Path $patched.ConfigFile) { Copy-Item -Path $patched.ConfigFile -Destination (Join-Path $destDir "grub.cfg") -Force }
        $fwAsset = @((Join-Path $ModuleDir "..\assets\tapeos-initramfs.cpio.gz"), "C:\TapeOS\tapeos-initramfs.cpio.gz", (Join-Path $env:TEMP "TapeOS-App\assets\tapeos-initramfs.cpio.gz")) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if ($fwAsset) { Copy-Item -LiteralPath $fwAsset -Destination (Join-Path $destDir "tapeos-initramfs.cpio.gz") -Force }
        $elapsedStr = 'Kompletao en ' + (F-Eta $cpSw.Elapsed.TotalSeconds)
        $Form.Invoke([Action]{
            $ProgressBar.Value = 100
            $LblEta.Text = $elapsedStr
            $LogBox.AppendText("`r`n¡MEDIO DE ÎTTALAÇIÔN KREAO!`r`nArxibo: $imgPath`r`n")
            [System.Windows.Forms.MessageBox]::Show(
                "¡Medio de îttalaçiôn TapeOS kreao!`r`n`r`nRûtta: $imgPath`r`n`r`nPa uçâl-lo, grábalo en un pendraîh kon Rufû, Win32DiskImager u dêhde TapeOS (modo Live-USB).",
                "Medio de îttalaçiôn kreao", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        })
    } else {
        $fwMsg = ""
        $frameworkAssetsDir = ""
        $frameworkScriptDir = ""
        foreach ($cand in @("G:\TapeOS\dist\brunch", "C:\TapeOS\brunch", (Join-Path $ModuleDir "..\assets\framework-assets"))) {
            if (Test-Path -LiteralPath (Join-Path $cand "rootc.img")) { $frameworkAssetsDir = $cand; break }
        }
        foreach ($cand in @("G:\TapeOS\core\framework", (Join-Path $ModuleDir "..\assets\framework-scripts"))) {
            if (Test-Path -LiteralPath (Join-Path $cand "install-framework-usb.sh")) { $frameworkScriptDir = $cand; break }
        }
        # Opciones de framework para esta maquina (parches automaticos segun hardware)
        $brunchOptions = (($HwReport.FrameworkPatches | ForEach-Object { $_.Option } | Where-Object { $_ }) -join ",")
        if (-not $EnableGoogleApps) { $brunchOptions = if ($brunchOptions) { $brunchOptions + ",no_google_play" } else { "no_google_play" } }
        if (-not $brunchOptions) { $brunchOptions = "enable_updates" }
        Write-PipelineLog ("Opciones TapeOS: " + $brunchOptions)

        # Si existe una imagen completa TapeOS (Brunch + parches), grabarla directo: NO hace falta WSL.
        $tapeosImg = $null
        if (-not $EnableGoogleApps) {
            foreach ($imgDir in @("G:\TapeOS\dist", "C:\TapeOS\images", (Join-Path $ModuleDir "..\assets"))) {
                $c = Get-ChildItem -Path (Join-Path $imgDir "TapeOS-Free-*.img") -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($c) { $tapeosImg = $c; break }
            }
        }
        foreach ($imgDir in @("G:\TapeOS\dist", "C:\TapeOS\images", (Join-Path $ModuleDir "..\assets"))) {
            $c = Get-ChildItem -Path (Join-Path $imgDir ("TapeOS-$Codename-*.img")) -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($c) { $tapeosImg = $c; break }
        }
        if (-not $tapeosImg) {
            try {
                $Form.Invoke([Action]{ $LblPhase.Text = '📥 Dehkargando imâhen TapeOS dêhde er çerbidôh...'; $ProgressBar.Value = 0; $LblEta.Text = 'Êttimao: --' })
                $remoteImg = Get-TapeOSRemoteImage -Codename $Codename -Version $(if ($EnableGoogleApps) { 'full' } else { 'free' }) -ProgressCallback {
                    param($pct, $mb, $tot)
                    try {
                        $pctInt = [math]::Min(100, [int]$pct)
                        $Form.Invoke([Action]{ $ProgressBar.Value = $pctInt; $LblEta.Text = "Dehkargao $mb MB de $tot MB" })
                    } catch { }
                }
                $tapeosImg = Get-Item -LiteralPath $remoteImg
            } catch {
                Write-PipelineLog ("Descarga de imagen remota no disponible: " + $_.Exception.Message)
            }
        }
        $usedFramework = $false
        if ($tapeosImg) {
            try {
                $Form.Invoke([Action]{ $LblPhase.Text = '💾 Grabando imagen TapeOS (Brunch + parches)...'; $ProgressBar.Value = 0; $LblEta.Text = 'Êttimao: --' })
                Start-TapeOSUsbFlash `
                    -ImageFilePath $tapeosImg.FullName `
                    -PhysicalDriveId $TargetUsb.DeviceID `
                    -ProgressCallback {
                        param($pct, $speedMBs, $written, $total)
                        try {
                            $eta = if ($speedMBs -gt 0) { (($total - $written) / 1MB) / $speedMBs } else { -1 }
                            $etaStr = 'Êttimao: ' + (F-Eta $eta) + " ($speedMBs MB/s)"
                            $pctInt = [math]::Min(100, [int]$pct)
                            $Form.Invoke([Action]{ $ProgressBar.Value = $pctInt; $LblEta.Text = $etaStr })
                        } catch { Write-PipelineLog ("ERROR callback imagen: " + $_.Exception.ToString()) }
                    } | Out-Null
                $usedFramework = $true
                $fwMsg = "`r`nImagen completa TapeOS (Brunch + parches) grabada: menu normal/verbose/seguro/instalar."
                $Form.Invoke([Action]{ $LogBox.AppendText("[Imagen] $($tapeosImg.Name) grabada en er pendraîh.`r`n") })
            } catch {
                Write-PipelineLog ("Grabacion de imagen TapeOS fallo: " + $_.Exception.Message)
                if (-not $tapeosImg) {
            try {
                $Form.Invoke([Action]{ $LblPhase.Text = '📥 Dehkargando imâhen TapeOS dêhde er çerbidôh...'; $ProgressBar.Value = 0; $LblEta.Text = 'Êttimao: --' })
                $remoteImg = Get-TapeOSRemoteImage -Codename $Codename -Version $(if ($EnableGoogleApps) { 'full' } else { 'free' }) -ProgressCallback {
                    param($pct, $mb, $tot)
                    try {
                        $pctInt = [math]::Min(100, [int]$pct)
                        $Form.Invoke([Action]{ $ProgressBar.Value = $pctInt; $LblEta.Text = "Dehkargao $mb MB de $tot MB" })
                    } catch { }
                }
                $tapeosImg = Get-Item -LiteralPath $remoteImg
            } catch {
                Write-PipelineLog ("Descarga de imagen remota no disponible: " + $_.Exception.Message)
            }
        }
        $usedFramework = $false
            }
        }
        if ($frameworkAssetsDir -and $frameworkScriptDir -and (Test-TapeOSWsl)) {
            try {
                $Form.Invoke([Action]{ $LblPhase.Text = 'Îttalando Brunch + TapeOS (WSL)...'; $ProgressBar.Value = 0; $LblEta.Text = 'Êttimao: ~5 min' })
                Invoke-TapeOSFrameworkInstall -ImageFilePath $patched.PatchedImagePath -DiskNumber $TargetUsb.DiskNumber -BrunchScriptDir $frameworkScriptDir -BrunchAssetsDir $frameworkAssetsDir -Options $brunchOptions | Out-Null
                $usedFramework = $true
                $fwMsg = "`r`nTapeOS instalado: menu de 6 entradas, parches automaticos segun el hardware y Aurora Store disponible."
                $Form.Invoke([Action]{ $LogBox.AppendText("[TapeOS] Îttalaçiôn kompletá.`r`n") })
            } catch {
                Write-PipelineLog ("Instalacion TapeOS fallo; se usa la grabacion clasica: " + $_.Exception.Message)
                # Opciones de framework para esta maquina (parches automaticos segun hardware)
        $brunchOptions = (($HwReport.FrameworkPatches | ForEach-Object { $_.Option } | Where-Object { $_ }) -join ",")
        if (-not $EnableGoogleApps) { $brunchOptions = if ($brunchOptions) { $brunchOptions + ",no_google_play" } else { "no_google_play" } }
        if (-not $brunchOptions) { $brunchOptions = "enable_updates" }
        Write-PipelineLog ("Opciones TapeOS: " + $brunchOptions)

        # Si existe una imagen completa TapeOS (Brunch + parches), grabarla directo: NO hace falta WSL.
        $tapeosImg = $null
        if (-not $EnableGoogleApps) {
            foreach ($imgDir in @("G:\TapeOS\dist", "C:\TapeOS\images", (Join-Path $ModuleDir "..\assets"))) {
                $c = Get-ChildItem -Path (Join-Path $imgDir "TapeOS-Free-*.img") -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($c) { $tapeosImg = $c; break }
            }
        }
        foreach ($imgDir in @("G:\TapeOS\dist", "C:\TapeOS\images", (Join-Path $ModuleDir "..\assets"))) {
            $c = Get-ChildItem -Path (Join-Path $imgDir ("TapeOS-$Codename-*.img")) -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($c) { $tapeosImg = $c; break }
        }
        if (-not $tapeosImg) {
            try {
                $Form.Invoke([Action]{ $LblPhase.Text = '📥 Dehkargando imâhen TapeOS dêhde er çerbidôh...'; $ProgressBar.Value = 0; $LblEta.Text = 'Êttimao: --' })
                $remoteImg = Get-TapeOSRemoteImage -Codename $Codename -Version $(if ($EnableGoogleApps) { 'full' } else { 'free' }) -ProgressCallback {
                    param($pct, $mb, $tot)
                    try {
                        $pctInt = [math]::Min(100, [int]$pct)
                        $Form.Invoke([Action]{ $ProgressBar.Value = $pctInt; $LblEta.Text = "Dehkargao $mb MB de $tot MB" })
                    } catch { }
                }
                $tapeosImg = Get-Item -LiteralPath $remoteImg
            } catch {
                Write-PipelineLog ("Descarga de imagen remota no disponible: " + $_.Exception.Message)
            }
        }
        $usedFramework = $false
        if ($tapeosImg) {
            try {
                $Form.Invoke([Action]{ $LblPhase.Text = '💾 Grabando imagen TapeOS (Brunch + parches)...'; $ProgressBar.Value = 0; $LblEta.Text = 'Êttimao: --' })
                Start-TapeOSUsbFlash `
                    -ImageFilePath $tapeosImg.FullName `
                    -PhysicalDriveId $TargetUsb.DeviceID `
                    -ProgressCallback {
                        param($pct, $speedMBs, $written, $total)
                        try {
                            $eta = if ($speedMBs -gt 0) { (($total - $written) / 1MB) / $speedMBs } else { -1 }
                            $etaStr = 'Êttimao: ' + (F-Eta $eta) + " ($speedMBs MB/s)"
                            $pctInt = [math]::Min(100, [int]$pct)
                            $Form.Invoke([Action]{ $ProgressBar.Value = $pctInt; $LblEta.Text = $etaStr })
                        } catch { Write-PipelineLog ("ERROR callback imagen: " + $_.Exception.ToString()) }
                    } | Out-Null
                $usedFramework = $true
                $fwMsg = "`r`nImagen completa TapeOS (Brunch + parches) grabada: menu normal/verbose/seguro/instalar."
                $Form.Invoke([Action]{ $LogBox.AppendText("[Imagen] $($tapeosImg.Name) grabada en er pendraîh.`r`n") })
            } catch {
                Write-PipelineLog ("Grabacion de imagen TapeOS fallo: " + $_.Exception.Message)
                if (-not $tapeosImg) {
            try {
                $Form.Invoke([Action]{ $LblPhase.Text = '📥 Dehkargando imâhen TapeOS dêhde er çerbidôh...'; $ProgressBar.Value = 0; $LblEta.Text = 'Êttimao: --' })
                $remoteImg = Get-TapeOSRemoteImage -Codename $Codename -Version $(if ($EnableGoogleApps) { 'full' } else { 'free' }) -ProgressCallback {
                    param($pct, $mb, $tot)
                    try {
                        $pctInt = [math]::Min(100, [int]$pct)
                        $Form.Invoke([Action]{ $ProgressBar.Value = $pctInt; $LblEta.Text = "Dehkargao $mb MB de $tot MB" })
                    } catch { }
                }
                $tapeosImg = Get-Item -LiteralPath $remoteImg
            } catch {
                Write-PipelineLog ("Descarga de imagen remota no disponible: " + $_.Exception.Message)
            }
        }
        $usedFramework = $false
            }
        }
            }
        }
        if (-not $usedFramework) {
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
        $Form.Invoke([Action]{ $LblPhase.Text = '🩹 Inyettando er arrankâh TapeOS (GRUB + initramfs)'; $LblEta.Text = 'Êttimao: --' })
        $initramfsPath = ""
        foreach ($cand in @((Join-Path $ModuleDir "..\assets\tapeos-initramfs.cpio.gz"), "C:\TapeOS\tapeos-initramfs.cpio.gz", (Join-Path $env:TEMP "TapeOS-App\assets\tapeos-initramfs.cpio.gz"))) {
            if (Test-Path -LiteralPath $cand) { $initramfsPath = (Resolve-Path -LiteralPath $cand).Path; break }
        }
        $kernelImagePath = ""
        foreach ($cand in @((Join-Path $ModuleDir "..\assets\tapeos-vmlinuz"), "C:\TapeOS\tapeos-vmlinuz", (Join-Path $env:TEMP "TapeOS-App\assets\tapeos-vmlinuz"))) {
            if (Test-Path -LiteralPath $cand) { $kernelImagePath = (Resolve-Path -LiteralPath $cand).Path; break }
        }
        $espInfo = $null
        try {
            $espInfo = Write-TapeOSGrubToEsp -DiskNumber $TargetUsb.DiskNumber -Timeout 15 -InitramfsPath $initramfsPath -KernelImagePath $kernelImagePath
            Write-PipelineLog ("ESP: menu GRUB inyectado. PARTUUID=" + $espInfo.RootPartuuid + ", initramfs=" + $espInfo.InitramfsInjected)
        } catch {
            Write-PipelineLog ("AVISO: no se pudo inyectar el menu GRUB en la ESP: " + $_.Exception.Message)
        }
        if ($espInfo -and $espInfo.InitramfsInjected -and $espInfo.KernelInjected) { $fwMsg = "`r`nFramework TapeOS inyettao: arrankêh normal/verbose/çeguro y êntrá de îttalaçiôn a dîkko dûhô dipponiblêh en er menú GRUB." } else { $fwMsg = "`r`n⚠️ AVISO: no çe enkontró er initramfs der framework (tapeos-initramfs.cpio.gz); er medio çolo arrankará er rekûperaçiôn ofiçiâh." }
        $Form.Invoke([Action]{
            $ProgressBar.Value = 100
            $LblEta.Text = 'Kompletao'
            $LogBox.AppendText("`r`n¡PROÇEÇO KOMPLETAO KON ÉXITO!`r`nEr pendraîh êttá lîtta pa arrankâh en kualkiêh ekîpo kon EFI.`r`n" + $fwMsg + "`r`n")
            [System.Windows.Forms.MessageBox]::Show(
                "¡TapeOS çe á grabao kon éxito en tu pendraîh!`r`n`r`nYa pueêh reiníçiâh er ekîpo y arrankâh dêhde er pendraîh USB (têkla F12/F11/Eç en er logo).",
                "Grabaçiôn Kompletá", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        })
        }
    }
    Write-PipelineLog "Pipeline finalizado con exito."
} catch {
    Write-PipelineLog ("ERROR pipeline: " + $_.Exception.ToString())
    try {
        $Form.Invoke([Action]{
            $LogBox.AppendText("ERRÔH: $($_.Exception.Message)`r`n")
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
                if ($script:langEPA) {
                    [System.Windows.Forms.MessageBox]::Show("No çe detêttó nîn pun pendraîh USB.`r`nKonêtta uno y pulça 'Refrehkâh', o elihe 'Kreâh er medio (.img)'.", "Pendraîh no detêttao", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
                } else {
                    [System.Windows.Forms.MessageBox]::Show("No se detectó ningún pendrive USB.`r`nConecta uno y pulsa 'Refrescar', o elige 'Crear el medio (.img)'.", "Pendrive no detectado", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
                }
                Set-TapeOSStep 3
                return
            }
            $targetUsb = $usbList[$cbUsbDrives.SelectedIndex]
            $confirm = [System.Windows.Forms.MessageBox]::Show("¿Êttâh çeguro de ke kierêh grabâh TapeOS en:`r`n$($targetUsb.DisplayName)?`r`n`r`nTÔ LÔ DATÔ DER PENDRAÎH ÇE BORRARÁN.", "Konfîrmaçiôn de Grabaçiôn", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        } else {
            $confirm = [System.Windows.Forms.MessageBox]::Show("Çe dehkargará y parcheará la imâhen de ChromeOS y çe kreará er medio de îttalaçiôn (.img) en:`r`n$($txtImageDir.Text)`r`n`r`nNo çe grabará en nîn pun pendraîh.", "Konfîrmaçiôn — Kreâh er medio", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        Write-TapeOSLog "Confirmacion aceptada. Lanzando pipeline (runspace)..."
        Set-TapeOSStep 5
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
        $null = $pipelinePS.AddParameter("HwReport", $script:hwReport)
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
# Iniçio der wîçâh: la bentana çe muêttra al îttante y la detêççiôn korre ar arrankâh
# =============================================================================
function Initialize-TapeOSDetection {
    if ($script:hwReport) { return }
    try {
        $script:hwReport = Get-TapeOSHardwareReport
        $script:catalog = Get-TapeOSCatalog
        $script:rec = $script:hwReport.Recommendations
        $cbRecovery.Items.Clear()
        foreach ($item in $script:catalog) { [void]$cbRecovery.Items.Add("$($item.Codename) — $($item.DisplayName)") }
        $cbRecovery.SelectedIndex = 0
        for ($i = 0; $i -lt $script:catalog.Count; $i++) {
            if ($script:catalog[$i].Codename -eq $script:rec.RecoveryCodename) { $cbRecovery.SelectedIndex = $i; break }
        }
        Refresh-UsbList
        $cbLang.SelectedIndex = 0
        Set-TapeOSLanguage -Lang $cbLang.SelectedItem.ToString()
        Set-TapeOSStep 0
        $form.ActiveControl = $btnNext
        Write-TapeOSLog "Deteccion de hardware completada (inicializacion de la GUI)."
    } catch {
        Write-TapeOSLog ("ERROR en deteccion (inicializacion): " + $_.Exception.ToString())
        try { [System.Windows.Forms.MessageBox]::Show("Errôh en la detêççiôn de hardware:`r`n$($_.Exception.Message)", "TapeOS", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null } catch { }
    }
}

Enable-TapeOSDoubleBuffer $form
$form.Add_Shown({ Initialize-TapeOSDetection })
# Red de seguridad: si el host no dispara Shown (p. ej. Show() en el arnés de pruebas),
# un timer la ejecuta en cuanto el bucle de mensajes arranca.
$initTimer = New-Object System.Windows.Forms.Timer
$initTimer.Interval = 100
$initTimer.Add_Tick({
    Initialize-TapeOSDetection
    $initTimer.Stop()
    $initTimer.Dispose()
})
$initTimer.Start()
[void]$form.ShowDialog()
