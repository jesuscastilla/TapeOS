<#
.SYNOPSIS
    TapeOS Interactive Windows Installer (Suite Completa)
.DESCRIPTION
    Instalador interactivo gráfico para Windows de TapeOS.
    Flujo completo: Detección de Hardware -> Selección de Recovery Actualizado ->
    Descarga Directa desde Google -> Parcheo de Compatibilidad Legacy -> Grabación en Pendrive USB.
#>

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"") -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# =============================================================================
# Log y captura global de errores: evita que la app se cierre en silencio.
# El log se escribe en %ProgramData%\TapeOS\tapeos-installer.log
# =============================================================================
$script:__tapeosLogFile = Join-Path $env:ProgramData "TapeOS\tapeos-installer.log"
try {
    New-Item -ItemType Directory -Force -Path (Split-Path $script:__tapeosLogFile) | Out-Null
} catch { }

function Write-TapeOSLog {
    param([string]$Msg)
    try {
        Add-Content -Path $script:__tapeosLogFile -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Msg) -Encoding UTF8
    } catch { }
}

Write-TapeOSLog "=== TapeOS GUI iniciada ==="

try {
    [System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)
    [System.Windows.Forms.Application]::add_ThreadException({
        param($sender, $e)
        Write-TapeOSLog ("UNHANDLED ThreadException: " + $e.Exception.ToString())
        try {
            [System.Windows.Forms.MessageBox]::Show(
                "Error inesperado:`r`n$($e.Exception.Message)",
                "TapeOS",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        } catch { }
    })
} catch { }

# Cargar todos los módulos de TapeOS
$moduleDir = Join-Path $PSScriptRoot "modules"
Import-Module (Join-Path $moduleDir "HardwareDetector.psm1") -Force
Import-Module (Join-Path $moduleDir "RecoveryCatalog.psm1") -Force
Import-Module (Join-Path $moduleDir "RecoveryDownloader.psm1") -Force
Import-Module (Join-Path $moduleDir "ImagePatcher.psm1") -Force
Import-Module (Join-Path $moduleDir "UsbFlasher.psm1") -Force
Import-Module (Join-Path $moduleDir "DiskManager.psm1") -Force
Import-Module (Join-Path $moduleDir "BootManager.psm1") -Force

# Obtener diagnóstico inicial de hardware
$hwReport = Get-TapeOSHardwareReport
$catalog = Get-TapeOSCatalog

# Ventana Principal
$form = New-Object System.Windows.Forms.Form
$form.Text = "TapeOS Installer — Suite Automatizada de ChromeOS para PC (Legacy & Moderno)"
$form.Size = New-Object System.Drawing.Size(900, 860)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 250)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)

# Fondo: bandera de Andalucía (verde - blanco - verde)
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

# Banner Superior
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(900, 80)
$headerPanel.BackColor = [System.Drawing.Color]::FromArgb(0, 132, 61)
$form.Controls.Add($headerPanel)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "TapeOS Universal Installer"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::White
$titleLabel.Location = New-Object System.Drawing.Point(25, 12)
$titleLabel.AutoSize = $true
$headerPanel.Controls.Add($titleLabel)

$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = "Pipeline Completo: Detección -> Descarga Oficial Actualizada -> Parcheo Legacy -> Grabación en Pendrive"
$subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$subtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(232, 240, 254)
$subtitleLabel.Location = New-Object System.Drawing.Point(26, 44)
$subtitleLabel.AutoSize = $true
$headerPanel.Controls.Add($subtitleLabel)

# Logo de la marca (DiploTech) si está disponible junto al instalador
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
    $titleLabel.Location = New-Object System.Drawing.Point(92, 12)
    $subtitleLabel.Location = New-Object System.Drawing.Point(93, 44)
}

# 1. Grupo: Diagnóstico de Hardware
$hwGroup = New-Object System.Windows.Forms.GroupBox
$hwGroup.Text = " 1. Diagnóstico Automático del Equipo "
$hwGroup.Location = New-Object System.Drawing.Point(20, 90)
$hwGroup.Size = New-Object System.Drawing.Size(845, 160)
$hwGroup.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$hwGroup.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($hwGroup)

$hwText = New-Object System.Windows.Forms.Label
$hwText.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$hwText.Location = New-Object System.Drawing.Point(15, 22)
$hwText.Size = New-Object System.Drawing.Size(815, 130)

$rec = $hwReport.Recommendations
$wifiSummary = if ($hwReport.Network.WiFi.Count -gt 0) { (($hwReport.Network.WiFi | ForEach-Object { $_.Name }) -join ', ') } else { 'No detêttao' }
$btSummary = if ($hwReport.Network.Bluetooth.Count -gt 0) { (($hwReport.Network.Bluetooth | ForEach-Object { $_.Name }) -join ', ') } else { 'No detêttao' }
$audioSummary = if ($hwReport.Audio.Count -gt 0) { (($hwReport.Audio | ForEach-Object { $_.Name }) -join ', ') } else { 'Çoportao' }
$touchSummary = if ($hwReport.Touchscreen.Count -gt 0) { (($hwReport.Touchscreen | ForEach-Object { $_.Name }) -join ', ') } else { 'No detêttá' }
$patchList = (($hwReport.FrameworkPatches | ForEach-Object { $_.Option }) -join ', ')
$hwInfo = @"
• CPU: $($hwReport.CPU.Name) ($($hwReport.CPU.Generation))
• Firmware: $($hwReport.Firmware.Type)  |  Secure Boot: $(if ($hwReport.Firmware.SecureBoot) { 'Attibo' } else { 'Inattibo' })  |  BitLocker: $(if ($hwReport.Security.BitLockerActive) { 'ATTIBO ⚠️' } else { 'Inattibo ✅' })
• GPU: $(($hwReport.GPU | ForEach-Object { "$($_.Name) $(if ($_.VendorId -eq '10DE') { '(NVIDIA)' } elseif ($_.VendorId -eq '1002') { '(AMD)' } elseif ($_.VendorId -eq '8086') { '(Intel)' } else { '' })" }) -join ', ')
• WiFi: $wifiSummary   |   Bluetooth: $btSummary
• Audio: $audioSummary   |   Tâttîh: $touchSummary
• Parcheh de hardware detêttáô: $(if ($patchList) { $patchList } else { 'nîn guno neçeçario' })
• Rekomendaçiôn: Rekûperaçiôn [$($rec.RecoveryCodename.ToUpper())] kon Kernel [$($rec.Kernel)]
"@
$hwText.Text = $hwInfo
$hwGroup.Controls.Add($hwText)

# 2. Grupo: Configuración y Descarga de ChromeOS Actualizado
$crosGroup = New-Object System.Windows.Forms.GroupBox
$crosGroup.Text = " 2. Imagen de Recuperación de ChromeOS (Oficial de Google) "
$crosGroup.Location = New-Object System.Drawing.Point(20, 250)
$crosGroup.Size = New-Object System.Drawing.Size(845, 130)
$crosGroup.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$crosGroup.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($crosGroup)

$lblRecovery = New-Object System.Windows.Forms.Label
$lblRecovery.Text = "Seleccionar Modelo:"
$lblRecovery.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblRecovery.Location = New-Object System.Drawing.Point(15, 28)
$lblRecovery.AutoSize = $true
$crosGroup.Controls.Add($lblRecovery)

$cbRecovery = New-Object System.Windows.Forms.ComboBox
$cbRecovery.Location = New-Object System.Drawing.Point(160, 25)
$cbRecovery.Size = New-Object System.Drawing.Size(460, 25)
$cbRecovery.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cbRecovery.Font = New-Object System.Drawing.Font("Segoe UI", 9)
foreach ($item in $catalog) {
    [void]$cbRecovery.Items.Add("$($item.Codename) — $($item.DisplayName)")
}
$cbRecovery.SelectedIndex = 0
for ($i = 0; $i -lt $catalog.Count; $i++) {
    if ($catalog[$i].Codename -eq $hwReport.Recommendations.RecoveryCodename) {
        $cbRecovery.SelectedIndex = $i
        break
    }
}
$crosGroup.Controls.Add($cbRecovery)

$btnCheckOnline = New-Object System.Windows.Forms.Button
$btnCheckOnline.Text = "🌐 Buscar Última Versión"
$btnCheckOnline.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$btnCheckOnline.Location = New-Object System.Drawing.Point(635, 24)
$btnCheckOnline.Size = New-Object System.Drawing.Size(195, 27)
$crosGroup.Controls.Add($btnCheckOnline)

$lblStatusUrl = New-Object System.Windows.Forms.Label
$lblStatusUrl.Text = "Versión oficial más reciente: Lista para consultar en Google CDN..."
$lblStatusUrl.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Italic)
$lblStatusUrl.ForeColor = [System.Drawing.Color]::FromArgb(60, 64, 67)
$lblStatusUrl.Location = New-Object System.Drawing.Point(160, 58)
$lblStatusUrl.Size = New-Object System.Drawing.Size(670, 20)
$crosGroup.Controls.Add($lblStatusUrl)

# Barra de Progreso de Descarga / Parcheo
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(160, 85)
$progressBar.Size = New-Object System.Drawing.Size(670, 25)
$progressBar.Value = 0
$crosGroup.Controls.Add($progressBar)

$lblProgressText = New-Object System.Windows.Forms.Label
$lblProgressText.Text = "Progreso:"
$lblProgressText.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblProgressText.Location = New-Object System.Drawing.Point(15, 87)
$lblProgressText.AutoSize = $true
$crosGroup.Controls.Add($lblProgressText)

# 2b. Grupo: Google Apps (Play Store)
$gaGroup = New-Object System.Windows.Forms.GroupBox
$gaGroup.Text = " 2b. Google Apps (Play Store) "
$gaGroup.Location = New-Object System.Drawing.Point(20, 390)
$gaGroup.Size = New-Object System.Drawing.Size(845, 70)
$gaGroup.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$gaGroup.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($gaGroup)

$radioGoogleApps = New-Object System.Windows.Forms.RadioButton
$radioGoogleApps.Text = "✅ Con Google Apps — Play Store y aplicaciones Android (recomendado)"
$radioGoogleApps.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$radioGoogleApps.Location = New-Object System.Drawing.Point(20, 30)
$radioGoogleApps.AutoSize = $true
$radioGoogleApps.Checked = $true
$gaGroup.Controls.Add($radioGoogleApps)

$radioNoGoogleApps = New-Object System.Windows.Forms.RadioButton
$radioNoGoogleApps.Text = "🚫 Sin Google Play — Android con apps APK (Aurora Store)"
$radioNoGoogleApps.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$radioNoGoogleApps.Location = New-Object System.Drawing.Point(440, 30)
$radioNoGoogleApps.AutoSize = $true
$gaGroup.Controls.Add($radioNoGoogleApps)

# 3. Grupo: Destino (Pendrive USB o archivo .img)
$usbGroup = New-Object System.Windows.Forms.GroupBox
$usbGroup.Text = " 3. Modo: Live-USB o Instalador "
$usbGroup.Location = New-Object System.Drawing.Point(20, 470)
$usbGroup.Size = New-Object System.Drawing.Size(845, 165)
$usbGroup.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$usbGroup.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($usbGroup)

$radioUsb = New-Object System.Windows.Forms.RadioButton
$radioUsb.Text = "💾 Live-USB — Grabar en un pendrive USB y arrancar desde él"
$radioUsb.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$radioUsb.Location = New-Object System.Drawing.Point(20, 28)
$radioUsb.AutoSize = $true
$radioUsb.Checked = $false
$usbGroup.Controls.Add($radioUsb)

$cbUsbDrives = New-Object System.Windows.Forms.ComboBox
$cbUsbDrives.Location = New-Object System.Drawing.Point(160, 25)
$cbUsbDrives.Size = New-Object System.Drawing.Size(510, 25)
$cbUsbDrives.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cbUsbDrives.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$cbUsbDrives.Enabled = $false
$usbGroup.Controls.Add($cbUsbDrives)

$btnRefreshUsb = New-Object System.Windows.Forms.Button
$btnRefreshUsb.Text = "🔄 Refrescar"
$btnRefreshUsb.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$btnRefreshUsb.Location = New-Object System.Drawing.Point(680, 24)
$btnRefreshUsb.Size = New-Object System.Drawing.Size(150, 27)
$btnRefreshUsb.Enabled = $false
$usbGroup.Controls.Add($btnRefreshUsb)

$radioImageOnly = New-Object System.Windows.Forms.RadioButton
$radioImageOnly.Text = "📀 Instalador — Crear el medio de instalación (.img) sin grabar"
$radioImageOnly.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$radioImageOnly.Location = New-Object System.Drawing.Point(20, 58)
$radioImageOnly.AutoSize = $true
$usbGroup.Controls.Add($radioImageOnly)
$radioImageOnly.Checked = $true

$txtImageDir = New-Object System.Windows.Forms.TextBox
$txtImageDir.Text = "C:\TapeOS\images"
$txtImageDir.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$txtImageDir.Location = New-Object System.Drawing.Point(160, 55)
$txtImageDir.Size = New-Object System.Drawing.Size(510, 25)
$txtImageDir.Enabled = $true
$usbGroup.Controls.Add($txtImageDir)

$btnBrowseDir = New-Object System.Windows.Forms.Button
$btnBrowseDir.Text = "📂 Examinar..."
$btnBrowseDir.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$btnBrowseDir.Location = New-Object System.Drawing.Point(680, 54)
$btnBrowseDir.Size = New-Object System.Drawing.Size(150, 27)
$btnBrowseDir.Enabled = $true
$usbGroup.Controls.Add($btnBrowseDir)

$lblUsbWarning = New-Object System.Windows.Forms.Label
$lblUsbWarning.Text = "⚠️ ATENCIÓN: El pendrive seleccionado será formateado para instalar TapeOS booteable con ChromeOS."
$lblUsbWarning.ForeColor = [System.Drawing.Color]::FromArgb(180, 40, 40)
$lblUsbWarning.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblUsbWarning.Location = New-Object System.Drawing.Point(160, 92)
$lblUsbWarning.Size = New-Object System.Drawing.Size(670, 30)
$usbGroup.Controls.Add($lblUsbWarning)

$lblImgHint = New-Object System.Windows.Forms.Label
$lblImgHint.Text = "El .img es el medio de instalación: grábalo cuando quieras con Rufus, Win32DiskImager o TapeOS (modo Live-USB)."
$lblImgHint.ForeColor = [System.Drawing.Color]::FromArgb(60, 64, 67)
$lblImgHint.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblImgHint.Location = New-Object System.Drawing.Point(160, 126)
$lblImgHint.Size = New-Object System.Drawing.Size(670, 25)
$usbGroup.Controls.Add($lblImgHint)

# Eventos de cambio de destino
$radioUsb.Add_Click({
    $cbUsbDrives.Enabled = $true
    $btnRefreshUsb.Enabled = $true
    $txtImageDir.Enabled = $false
    $btnBrowseDir.Enabled = $false
    Refresh-UsbList
    $logBox.AppendText("[Modo] Live-USB çelehçionao. Lô dippoçitivô detêttáô êttán en la lîtta.`r`n")
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
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtImageDir.Text = $dlg.Path
    }
})

# Función para recargar unidades USB
function Refresh-UsbList {
    $cbUsbDrives.Items.Clear()
    $usbList = Get-TapeOSUsbDrives
    if ($usbList.Count -eq 0) {
        [void]$cbUsbDrives.Items.Add("⚠️ No çe detêttó nîn pun pendraîh USB. Konêtta uno y pulça 'Refrehkâh'.")
        $cbUsbDrives.SelectedIndex = 0
    } else {
        foreach ($d in $usbList) {
            [void]$cbUsbDrives.Items.Add($d.DisplayName)
        }
        $cbUsbDrives.SelectedIndex = 0
    }
}
Refresh-UsbList
$btnRefreshUsb.Add_Click({ Refresh-UsbList })

# 4. Consola de Log y Estado
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(20, 645)
$logBox.Size = New-Object System.Drawing.Size(845, 95)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.BackColor = [System.Drawing.Color]::FromArgb(20, 24, 30)
$logBox.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 128)
$logBox.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$logBox.Text = "=== TapeOS Automated Installation Engine Ready ===`r`nModo por defecto: Instalador (crea el .img sin pendrive). Cambia a Live-USB si quieres grabar un pendrive. Pulsa 'Crear en 1 Clic' para empezar.`r`n"
$form.Controls.Add($logBox)

# Botones de Acción Inferiores
$btnFullAuto = New-Object System.Windows.Forms.Button
$btnFullAuto.Text = "⚡ Descargar, Parchear y Crear (1-Clic)"
$btnFullAuto.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnFullAuto.BackColor = [System.Drawing.Color]::FromArgb(0, 132, 61)
$btnFullAuto.ForeColor = [System.Drawing.Color]::White
$btnFullAuto.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnFullAuto.Location = New-Object System.Drawing.Point(445, 750)
$btnFullAuto.Size = New-Object System.Drawing.Size(420, 45)
$btnFullAuto.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnFullAuto)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Cerrar"
$btnExit.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnExit.Location = New-Object System.Drawing.Point(325, 750)
$btnExit.Size = New-Object System.Drawing.Size(105, 45)
$btnExit.Add_Click({ $form.Close() })
$form.Controls.Add($btnExit)

# Evento: Buscar última versión online
$currentRecoveryUrl = $null
$btnCheckOnline.Add_Click({
    $selectedStr = $cbRecovery.SelectedItem.ToString()
    $codename = $selectedStr.Split(' ')[0]
    $logBox.AppendText("[ChromiumDash] Consultando la versión oficial más reciente para '$codename'...`r`n")
    
    $info = Get-TapeOSLatestRecoveryInfo -BoardCodename $codename
    $Script:currentRecoveryUrl = $info.Url
    $lblStatusUrl.Text = "Versión: Milestone $($info.Milestone) | Archivo: $($info.FileName)"
    $logBox.AppendText("[ChromiumDash] ¡Encontrada versión Milestone $($info.Milestone)!`r`nURL: $($info.Url)`r`n")
})

# Evento: Flujo Completo Automatizado
$btnFullAuto.Add_Click({
    try {
    $imageOnlyMode = $radioImageOnly.Checked
    $selectedUsbIdx = $null
    $usbList = @()
    Write-TapeOSLog ("Click Crear: imageOnly=" + $imageOnlyMode)
    if (-not $imageOnlyMode) {
        $selectedUsbIdx = $cbUsbDrives.SelectedIndex
        $usbList = @(Get-TapeOSUsbDrives)
        Write-TapeOSLog ("Live-USB: usbList.Count=" + $usbList.Count + ", selectedIdx=" + $selectedUsbIdx)
        if ($usbList.Count -eq 0 -or $selectedUsbIdx -ge $usbList.Count) {
            # Sin pendrive: informar y ofrecer reintento (sin cambiar de modo)
            $retry = [System.Windows.Forms.MessageBox]::Show(
                "No çe detêttó nîn pun pendraîh USB.`r`n`r`nKonêtta er dippoçitibo, êppera unô çegundô y pulça '🔄 Refrehkâh'.`r`n`r`n¿Kierêh ke TapeOS reintente la detêççiôn ahora?",
                "Pendraîh no detêttao",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($retry -eq [System.Windows.Forms.DialogResult]::Yes) {
                Refresh-UsbList
                $logBox.AppendText("[Modo] Deteççiôn de pendraîh reintentá. Rebîça la lîtta y bûerbe a pulçâh Kreâh.`r`n")
            }
            return
        }
    }
    if ($imageOnlyMode) {
        $targetUsb = $null
        $imgDest = $txtImageDir.Text.Trim()
        if (-not $imgDest) { $imgDest = "C:\TapeOS\images" }
        $confirmText = "Çe dehkargará y parcheará la imâhen de ChromeOS y çe kreará er medio de îttalaçiôn (.img) en:`r`n$imgDest`r`n`r`nNo çe grabará en nîn pun pendraîh."
        $confirmTitle = "Konfîrmaçiôn — Kreâh er medio de îttalaçiôn (.img)"
    } else {
        $targetUsb = $usbList[$selectedUsbIdx]
        $confirmText = "¿Êttâh çeguro de ke kierêh grabâh TapeOS en:`r`n$($targetUsb.DisplayName)?`r`n`r`nTÔ LÔ DATÔ DER PENDRAÎH ÇE BORRARÁN."
        $confirmTitle = "Konfîrmaçiôn de Grabaçiôn"
    }
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        $confirmText,
        $confirmTitle,
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { Write-TapeOSLog "Confirmacion cancelada por el usuario"; return }
    Write-TapeOSLog "Confirmacion aceptada. Lanzando worker del pipeline..."

    $btnFullAuto.Enabled = $false
    $btnCheckOnline.Enabled = $false

    # Ejecutar el pipeline en un runspace dedicado (STA) sin congelar la UI.
    # (QueueUserWorkItem falla en hosts STA de PS 5.1: "no runspace available",
    #  y la excepcion no controlada en el hilo de fondo mata el proceso.)

    $pCodename = ($cbRecovery.SelectedItem.ToString()).Split(' ')[0]
    $pGoogleApps = $radioGoogleApps.Checked
    $pImageOnly = $radioImageOnly.Checked
    $pImageDir = $txtImageDir.Text

    $pipelineScript = @'
param(
    [object]$Form, [object]$LogBox, [object]$ProgressBar, [object]$LblStatus,
    [string]$Codename, [bool]$EnableGoogleApps, [bool]$ImageOnlyMode,
    [string]$ImageDestDir, [object]$TargetUsb, [object]$HwReport,
    [string]$ModuleDir, [string]$LogFile
)
$ErrorActionPreference = 'Stop'
function Write-PipelineLog {
    param([string]$Msg)
    try { Add-Content -Path $LogFile -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Msg) -Encoding UTF8 } catch { }
}
Import-Module (Join-Path $ModuleDir "RecoveryDownloader.psm1") -Force
Import-Module (Join-Path $ModuleDir "ImagePatcher.psm1") -Force
Import-Module (Join-Path $ModuleDir "UsbFlasher.psm1") -Force

try {
    Write-PipelineLog "Pipeline (runspace) iniciado"
    Write-PipelineLog ("Pipeline: codename=$Codename, googleplay=$EnableGoogleApps, imageOnly=$ImageOnlyMode, destino=$ImageDestDir")
    $Form.Invoke([Action]{
        $LogBox.AppendText("Modo Googlêh Play: $(if ($EnableGoogleApps) { 'Attibao (Play Çtore + Android)' } else { 'Dehattibao (APK + Aurora Çtore)' })`r`n")
    })

    # 1. Consulta
    $Form.Invoke([Action]{ $LogBox.AppendText("`r`n[Paço 1/4] Konhûttando la ûrtima berçiôn ofiçiâh de Google pa '$Codename'...`r`n") })
    $info = Get-TapeOSLatestRecoveryInfo -BoardCodename $Codename
            
    # 2. Descarga (reutiliza un ZIP previo completo si existe)
    $downloadDir = "C:\TapeOS\downloads"
    $destZip = Join-Path $downloadDir $info.FileName
    if ((Test-Path $destZip) -and (Get-Item $destZip).Length -gt 100MB) {
        Write-PipelineLog "ZIP previo encontrado; se reutiliza: $destZip"
        $Form.Invoke([Action]{ $LogBox.AppendText("[Paço 2/4] Dehkarga anteriôh enkontrá; çe reûtiliça.`r`n") })
    } else {
        $Form.Invoke([Action]{
            $LblStatus.Text = "Dehkargando: $($info.FileName)..."
            $LogBox.AppendText("[Paço 2/4] Dehkargando la imâhen dêhde er CDN ofiçiâh de Google...`r`n")
        })
        Start-TapeOSDownload -Url $info.Url -DestinationFile $destZip -ProgressCallback {
            param($percent, $received, $total)
            $Form.Invoke([Action]{ $ProgressBar.Value = [math]::Min(100, [int]$percent) })
        } | Out-Null
    }

    # 3. Parcheo
    $Form.Invoke([Action]{
        $LogBox.AppendText("[Paço 3/4] Dehkomprimiendo y aplikando parcheh TapeOS (Legacy EFI, swtpm, GPU, Googlêh Play: $(if ($EnableGoogleApps) { 'ÇÍ' } else { 'NO (APK/Aurora)' }))...`r`n")
    })
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
            $Form.Invoke([Action]{
                $ProgressBar.Value = [int]$pct
                $LogBox.AppendText("  • $msg`r`n")
            })
        }

    # 4. Medio de instalacion (.img)
    if ($ImageOnlyMode) {
        $Form.Invoke([Action]{ $LogBox.AppendText("[Paço 4/4] Kreando er medio de îttalaçiôn (.img) çîn grabâh...`r`n") })
        $destDir = $ImageDestDir.Trim()
        if (-not $destDir) { $destDir = "C:\TapeOS\images" }
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        $imgName = "TapeOS-$($info.Board)-M$($info.Milestone)-$(if ($EnableGoogleApps) { 'googleapps' } else { 'aurora' }).img"
        $imgPath = Join-Path $destDir $imgName
        Copy-Item -Path $patched.PatchedImagePath -Destination $imgPath -Force
        if (Test-Path $patched.ConfigFile) { Copy-Item -Path $patched.ConfigFile -Destination (Join-Path $destDir "grub.cfg") -Force }
        $Form.Invoke([Action]{
            $ProgressBar.Value = 100
            $LogBox.AppendText("`r`n✅ ¡MEDIO DE ÎTTALAÇIÔN KREAO!`r`nArxibo: $imgPath`r`nGrábalo kuando kierâh kon Rufû, Win32DiskImager u TapeOS (modo Live-USB).`r`n")
            [System.Windows.Forms.MessageBox]::Show(
                "¡Medio de îttalaçiôn TapeOS kreao!`r`n`r`nRûtta: $imgPath`r`n`r`nPa uçâl-lo, grábalo en un pendraîh kon Rufû, Win32DiskImager u dêhde TapeOS (modo Live-USB).",
                "Medio de îttalaçiôn kreao",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        })
    } else {
        # 4. Grabacion en pendrive USB
        $Form.Invoke([Action]{ $LogBox.AppendText("[Paço 4/4] Grabando la imâhen parcheá dirêttamente en $($TargetUsb.DeviceID)...`r`n") })
        Start-TapeOSUsbFlash `
            -ImageFilePath $patched.PatchedImagePath `
            -PhysicalDriveId $TargetUsb.DeviceID `
            -ProgressCallback {
                param($pct, $speedMBs, $written, $total)
                $Form.Invoke([Action]{
                    $ProgressBar.Value = [math]::Min(100, [int]$pct)
                    $LblStatus.Text = "Grabando en USB: $pct% ($speedMBs MB/s)"
                })
            } | Out-Null
        $Form.Invoke([Action]{
            $ProgressBar.Value = 100
            $LogBox.AppendText("`r`n✅ ¡PROÇEÇO KOMPLETAO KON ÉXITO!`r`nEr pendraîh êttá lîtta pa arrankâh en kualkiêh ekîpo kon EFI.`r`n")
            [System.Windows.Forms.MessageBox]::Show(
                "¡TapeOS çe á grabao kon éxito en tu pendraîh!`r`n`r`nYa pueêh reiníçiâh er ekîpo y arrankâh dêhde er pendraîh USB (têkla F12/F11/Eç en er logo).",
                "Grabaçiôn Kompletá",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
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
                "Errôh",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        })
    } catch { }
}
'@

    Write-TapeOSLog "Creando runspace dedicado para el pipeline..."
    $pipelineRunspace = [runspacefactory]::CreateRunspace()
    $pipelineRunspace.ApartmentState = "STA"
    $pipelineRunspace.Open()
    $pipelinePS = [powershell]::Create()
    $pipelinePS.Runspace = $pipelineRunspace
    $null = $pipelinePS.AddScript($pipelineScript)
    $null = $pipelinePS.AddParameter("Form", $form)
    $null = $pipelinePS.AddParameter("LogBox", $logBox)
    $null = $pipelinePS.AddParameter("ProgressBar", $progressBar)
    $null = $pipelinePS.AddParameter("LblStatus", $lblStatusUrl)
    $null = $pipelinePS.AddParameter("Codename", $pCodename)
    $null = $pipelinePS.AddParameter("EnableGoogleApps", $pGoogleApps)
    $null = $pipelinePS.AddParameter("ImageOnlyMode", $pImageOnly)
    $null = $pipelinePS.AddParameter("ImageDestDir", $pImageDir)
    $null = $pipelinePS.AddParameter("TargetUsb", $targetUsb)
    $null = $pipelinePS.AddParameter("HwReport", $hwReport)
    $null = $pipelinePS.AddParameter("ModuleDir", $moduleDir)
    $null = $pipelinePS.AddParameter("LogFile", $script:__tapeosLogFile)
    $pipelineAsync = $pipelinePS.BeginInvoke()

    # Vigilar la finalizacion desde la UI sin congelarla
    $watchTimer = New-Object System.Windows.Forms.Timer
    $watchTimer.Interval = 1000
    $watchTimer.Add_Tick({
        if ($pipelineAsync.IsCompleted) {
            $watchTimer.Stop()
            $watchTimer.Dispose()
            try {
                $null = $pipelinePS.EndInvoke($pipelineAsync)
                Write-TapeOSLog "Pipeline completado sin errores."
            } catch {
                Write-TapeOSLog ("ERROR al finalizar pipeline: " + $_.Exception.ToString())
                try {
                    [System.Windows.Forms.MessageBox]::Show(
                        "Errôh en er proçeço:`r`n$($_.Exception.Message)",
                        "TapeOS",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Error
                    ) | Out-Null
                } catch { }
            } finally {
                $pipelinePS.Dispose()
                $pipelineRunspace.Dispose()
                $btnFullAuto.Enabled = $true
                $btnCheckOnline.Enabled = $true
            }
        }
    })
    $watchTimer.Start()
    } catch {
        Write-TapeOSLog ("ERROR en botón Crear: " + $_)
        try {
            [System.Windows.Forms.MessageBox]::Show(
                "Errôh inepperao al iniçiâh er proçeço:`r`n$($_.Exception.Message)",
                "TapeOS",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        } catch { }
    }
})

# Selector de idioma (Español / Andaluz)
$cbLang = New-Object System.Windows.Forms.ComboBox
$cbLang.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cbLang.Location = New-Object System.Drawing.Point(735, 14)
$cbLang.Size = New-Object System.Drawing.Size(140, 25)
$cbLang.Font = New-Object System.Drawing.Font("Segoe UI", 9)
[void]$cbLang.Items.Add("Español")
[void]$cbLang.Items.Add("Andaluz")
$cbLang.SelectedIndex = 0
$headerPanel.Controls.Add($cbLang)

function Set-TapeOSLanguage {
    param([string]$Lang)
    if ($Lang -eq "Andaluz") {
        $titleLabel.Text = "TapeOS Îttaladôh Uniberçâh"
        $subtitleLabel.Text = "Piplîne completo: Deteççiôn -> Dehcarga ofiçiâh -> Parcheo -> Grabâh en Pendraîh"
        $hwGroup.Text = " 1. Diagnóttiko Automátiko der Ekîpo "
        $crosGroup.Text = " 2. Imâhen de Rekûperaçiôn de ChromeOS (Ofiçiâh de Google) "
        $lblRecovery.Text = "Erihîh Modelo:"
        $btnCheckOnline.Text = "🌐 Bûhkâh la Ûrtima Berçiôn"
        $lblStatusUrl.Text = "Berçiôn ofiçiâh mâh reçiente: lîtta pa konhûttâh en Google CDN..."
        $lblProgressText.Text = "Progreço:"
        $gaGroup.Text = " 2b. Googlêh Play (Çtore u APK) "
        $radioGoogleApps.Text = "✅ Kon Googlêh Play — Çtore y aplikâçionêh Android (rekomendao)"
        $radioNoGoogleApps.Text = "🚫 Çîn Googlêh Play — Android kon apph APK (Aurora Çtore)"
        $usbGroup.Text = " 3. Modo: Live-USB u Îttaladôh "
        $radioUsb.Text = "💾 Live-USB — Grabâh en un pendraîh USB y arrankâh dêhde él"
        $radioImageOnly.Text = "📀 Îttaladôh — Kreâh er medio de îttalaçiôn (.img) çîn grabâh"
        $btnRefreshUsb.Text = "🔄 Refrehkâh"
        $btnBrowseDir.Text = "📂 Ehkaminâh..."
        $lblUsbWarning.Text = "⚠️ OHO: Er pendraîh elehçionao çe formateará pa îttalâh TapeOS arrankable kon ChromeOS."
        $lblImgHint.Text = "Er .img êh er medio de îttalaçiôn: grábalo kuando kierâh kon Rufû, Win32DiskImager u TapeOS (modo Live-USB)."
        $btnFullAuto.Text = "⚡ Dehkargâh, Parcheâh y Kreâh (1-Klik)"
        $btnExit.Text = "Çerrâh"
        $logBox.Text = "=== TapeOS Lîtta ===`r`nModo por defêto: Îttaladôh (krea er .img çîn pendraîh). Kambia a Live-USB çi kierêh grabâh un pendraîh. Pulça 'Kreâh en 1 Klik' pa empeçâh.`r`n"
    } else {
        $titleLabel.Text = "TapeOS Universal Installer"
        $subtitleLabel.Text = "Pipeline Completo: Detección -> Descarga Oficial Actualizada -> Parcheo Legacy -> Grabación en Pendrive"
        $hwGroup.Text = " 1. Diagnóstico Automático del Equipo "
        $crosGroup.Text = " 2. Imagen de Recuperación de ChromeOS (Oficial de Google) "
        $lblRecovery.Text = "Seleccionar Modelo:"
        $btnCheckOnline.Text = "🌐 Buscar Última Versión"
        $lblStatusUrl.Text = "Versión oficial más reciente: Lista para consultar en Google CDN..."
        $lblProgressText.Text = "Progreso:"
        $gaGroup.Text = " 2b. Google Apps (Play Store) "
        $radioGoogleApps.Text = "✅ Con Google Apps — Play Store y aplicaciones Android (recomendado)"
        $radioNoGoogleApps.Text = "🚫 Sin Google Play — Android con apps APK (Aurora Store)"
        $usbGroup.Text = " 3. Modo: Live-USB o Instalador "
        $radioUsb.Text = "💾 Live-USB — Grabar en un pendrive USB y arrancar desde él"
        $radioImageOnly.Text = "📀 Instalador — Crear el medio de instalación (.img) sin grabar"
        $btnRefreshUsb.Text = "🔄 Refrescar"
        $btnBrowseDir.Text = "📂 Examinar..."
        $lblUsbWarning.Text = "⚠️ ATENCIÓN: El pendrive seleccionado será formateado para instalar TapeOS booteable con ChromeOS."
        $lblImgHint.Text = "El .img es el medio de instalación: grábalo cuando quieras con Rufus, Win32DiskImager o TapeOS (modo Live-USB)."
        $btnFullAuto.Text = "⚡ Descargar, Parchear y Crear (1-Clic)"
        $btnExit.Text = "Cerrar"
        $logBox.Text = "=== TapeOS Automated Installation Engine Ready ===`r`nModo por defecto: Instalador (crea el .img sin pendrive). Cambia a Live-USB si quieres grabar un pendrive. Pulsa 'Crear en 1 Clic' para empezar.`r`n"
    }
}

$cbLang.Add_SelectedIndexChanged({
    Set-TapeOSLanguage -Lang $cbLang.SelectedItem.ToString()
})
Set-TapeOSLanguage -Lang "Andaluz"

# Mostrar formulario
[void]$form.ShowDialog()
