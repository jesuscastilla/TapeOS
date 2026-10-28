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
$form.Size = New-Object System.Drawing.Size(900, 820)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 250)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)

# Banner Superior
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(900, 80)
$headerPanel.BackColor = [System.Drawing.Color]::FromArgb(26, 115, 232)
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

# 1. Grupo: Diagnóstico de Hardware
$hwGroup = New-Object System.Windows.Forms.GroupBox
$hwGroup.Text = " 1. Diagnóstico Automático del Equipo "
$hwGroup.Location = New-Object System.Drawing.Point(20, 90)
$hwGroup.Size = New-Object System.Drawing.Size(845, 110)
$hwGroup.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($hwGroup)

$hwText = New-Object System.Windows.Forms.Label
$hwText.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$hwText.Location = New-Object System.Drawing.Point(15, 22)
$hwText.Size = New-Object System.Drawing.Size(815, 80)

$rec = $hwReport.Recommendations
$hwInfo = @"
• CPU: $($hwReport.CPU.Name) ($($hwReport.CPU.Generation))
• Firmware: $($hwReport.Firmware.Type)  |  Secure Boot: $(if ($hwReport.Firmware.SecureBoot) { 'Activo' } else { 'Inactivo' })  |  BitLocker: $(if ($hwReport.Security.BitLockerActive) { 'ACTIVO ⚠️' } else { 'Inactivo ✅' })
• GPU: $(($hwReport.GPU | ForEach-Object { $_.Name }) -join ', ')
• Recomendación: Recovery [$($rec.RecoveryCodename.ToUpper())] con Kernel [$($rec.Kernel)]
"@
$hwText.Text = $hwInfo
$hwGroup.Controls.Add($hwText)

# 2. Grupo: Configuración y Descarga de ChromeOS Actualizado
$crosGroup = New-Object System.Windows.Forms.GroupBox
$crosGroup.Text = " 2. Imagen de Recuperación de ChromeOS (Oficial de Google) "
$crosGroup.Location = New-Object System.Drawing.Point(20, 210)
$crosGroup.Size = New-Object System.Drawing.Size(845, 130)
$crosGroup.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
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
$gaGroup.Location = New-Object System.Drawing.Point(20, 350)
$gaGroup.Size = New-Object System.Drawing.Size(845, 70)
$gaGroup.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($gaGroup)

$radioGoogleApps = New-Object System.Windows.Forms.RadioButton
$radioGoogleApps.Text = "✅ Con Google Apps — Play Store y aplicaciones Android (recomendado)"
$radioGoogleApps.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$radioGoogleApps.Location = New-Object System.Drawing.Point(20, 30)
$radioGoogleApps.AutoSize = $true
$radioGoogleApps.Checked = $true
$gaGroup.Controls.Add($radioGoogleApps)

$radioNoGoogleApps = New-Object System.Windows.Forms.RadioButton
$radioNoGoogleApps.Text = "🚫 Sin Google Apps — ChromeOS ligero, solo navegador y aplicaciones web"
$radioNoGoogleApps.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$radioNoGoogleApps.Location = New-Object System.Drawing.Point(440, 30)
$radioNoGoogleApps.AutoSize = $true
$gaGroup.Controls.Add($radioNoGoogleApps)

# 3. Grupo: Destino (Pendrive USB o archivo .img)
$usbGroup = New-Object System.Windows.Forms.GroupBox
$usbGroup.Text = " 3. Destino de Instalación (Pendrive USB o Archivo .img) "
$usbGroup.Location = New-Object System.Drawing.Point(20, 430)
$usbGroup.Size = New-Object System.Drawing.Size(845, 165)
$usbGroup.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($usbGroup)

$radioUsb = New-Object System.Windows.Forms.RadioButton
$radioUsb.Text = "💾 Grabar directamente en un pendrive USB"
$radioUsb.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$radioUsb.Location = New-Object System.Drawing.Point(20, 28)
$radioUsb.AutoSize = $true
$radioUsb.Checked = $true
$usbGroup.Controls.Add($radioUsb)

$cbUsbDrives = New-Object System.Windows.Forms.ComboBox
$cbUsbDrives.Location = New-Object System.Drawing.Point(160, 25)
$cbUsbDrives.Size = New-Object System.Drawing.Size(510, 25)
$cbUsbDrives.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cbUsbDrives.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$usbGroup.Controls.Add($cbUsbDrives)

$btnRefreshUsb = New-Object System.Windows.Forms.Button
$btnRefreshUsb.Text = "🔄 Refrescar"
$btnRefreshUsb.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$btnRefreshUsb.Location = New-Object System.Drawing.Point(680, 24)
$btnRefreshUsb.Size = New-Object System.Drawing.Size(150, 27)
$usbGroup.Controls.Add($btnRefreshUsb)

$radioImageOnly = New-Object System.Windows.Forms.RadioButton
$radioImageOnly.Text = "📁 Solo crear archivo de imagen (.img) — sin grabar en ningún pendrive"
$radioImageOnly.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$radioImageOnly.Location = New-Object System.Drawing.Point(20, 58)
$radioImageOnly.AutoSize = $true
$usbGroup.Controls.Add($radioImageOnly)

$txtImageDir = New-Object System.Windows.Forms.TextBox
$txtImageDir.Text = "C:\TapeOS\images"
$txtImageDir.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$txtImageDir.Location = New-Object System.Drawing.Point(160, 55)
$txtImageDir.Size = New-Object System.Drawing.Size(510, 25)
$txtImageDir.Enabled = $false
$usbGroup.Controls.Add($txtImageDir)

$btnBrowseDir = New-Object System.Windows.Forms.Button
$btnBrowseDir.Text = "📂 Examinar..."
$btnBrowseDir.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$btnBrowseDir.Location = New-Object System.Drawing.Point(680, 54)
$btnBrowseDir.Size = New-Object System.Drawing.Size(150, 27)
$btnBrowseDir.Enabled = $false
$usbGroup.Controls.Add($btnBrowseDir)

$lblUsbWarning = New-Object System.Windows.Forms.Label
$lblUsbWarning.Text = "⚠️ ATENCIÓN: El pendrive seleccionado será formateado para instalar TapeOS booteable con ChromeOS."
$lblUsbWarning.ForeColor = [System.Drawing.Color]::FromArgb(180, 40, 40)
$lblUsbWarning.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblUsbWarning.Location = New-Object System.Drawing.Point(160, 92)
$lblUsbWarning.Size = New-Object System.Drawing.Size(670, 30)
$usbGroup.Controls.Add($lblUsbWarning)

$lblImgHint = New-Object System.Windows.Forms.Label
$lblImgHint.Text = "El archivo .img podrá grabarse más tarde con Rufus, Win32DiskImager o desde TapeOS (modo USB)."
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
})
$radioImageOnly.Add_Click({
    $cbUsbDrives.Enabled = $false
    $btnRefreshUsb.Enabled = $false
    $txtImageDir.Enabled = $true
    $btnBrowseDir.Enabled = $true
})
$btnBrowseDir.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Selecciona la carpeta donde guardar la imagen TapeOS (.img)"
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
        [void]$cbUsbDrives.Items.Add("⚠️ No se detectó ningún pendrive USB. Conecta uno y pulsa 'Refrescar'.")
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
$logBox.Location = New-Object System.Drawing.Point(20, 605)
$logBox.Size = New-Object System.Drawing.Size(845, 95)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.BackColor = [System.Drawing.Color]::FromArgb(20, 24, 30)
$logBox.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 128)
$logBox.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$logBox.Text = "=== TapeOS Automated Installation Engine Ready ===`r`nElige el destino (pendrive USB o solo archivo .img) y pulsa 'Crear en 1 Clic' para ejecutar el proceso completo.`r`n"
$form.Controls.Add($logBox)

# Botones de Acción Inferiores
$btnFullAuto = New-Object System.Windows.Forms.Button
$btnFullAuto.Text = "⚡ Descargar, Parchear y Crear (1-Clic)"
$btnFullAuto.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnFullAuto.BackColor = [System.Drawing.Color]::FromArgb(26, 115, 232)
$btnFullAuto.ForeColor = [System.Drawing.Color]::White
$btnFullAuto.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnFullAuto.Location = New-Object System.Drawing.Point(445, 710)
$btnFullAuto.Size = New-Object System.Drawing.Size(420, 45)
$btnFullAuto.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnFullAuto)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Cerrar"
$btnExit.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnExit.Location = New-Object System.Drawing.Point(325, 710)
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
    $imageOnlyMode = $radioImageOnly.Checked
    if (-not $imageOnlyMode) {
        $selectedUsbIdx = $cbUsbDrives.SelectedIndex
        $usbList = Get-TapeOSUsbDrives
        if ($usbList.Count -eq 0 -or $selectedUsbIdx -ge $usbList.Count) {
            [System.Windows.Forms.MessageBox]::Show(
                "Por favor conecta un pendrive USB válido y pulsa 'Refrescar'.",
                "Pendrive no detectado",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        $targetUsb = $usbList[$selectedUsbIdx]
        $confirmText = "¿Estás seguro de que deseas grabar TapeOS en:`r`n$($targetUsb.DisplayName)?`r`n`r`nTODOS LOS DATOS DEL PENDRIVE SE BORRARÁN."
        $confirmTitle = "Confirmación de Grabación"
    } else {
        $targetUsb = $null
        $imgDest = $txtImageDir.Text.Trim()
        if (-not $imgDest) { $imgDest = "C:\TapeOS\images" }
        $confirmText = "Se descargará y parcheará la imagen de ChromeOS y se guardará como archivo .img en:`r`n$imgDest`r`n`r`nNo se grabará en ningún pendrive."
        $confirmTitle = "Confirmación — Crear archivo .img"
    }
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        $confirmText,
        $confirmTitle,
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $btnFullAuto.Enabled = $false
    $btnCheckOnline.Enabled = $false

    # Ejecutar en segundo plano para no congelar la UI
    [System.Threading.ThreadPool]::QueueUserWorkItem({
        try {
            $selectedStr = $form.Invoke([Func[string]]{ $cbRecovery.SelectedItem.ToString() })
            $codename = $selectedStr.Split(' ')[0]

            # Modo Google Apps elegido en la interfaz
            $enableGoogleApps = $form.Invoke([Func[bool]]{ $radioGoogleApps.Checked })
            $form.Invoke([Action]{
                $logBox.AppendText("Modo Google Apps: $(if ($enableGoogleApps) { 'Activado (Play Store + Android)' } else { 'Desactivado (ChromeOS ligero)' })`r`n")
            })

            # Modo destino: pendrive USB o solo archivo .img
            $imageOnlyMode = $form.Invoke([Func[bool]]{ $radioImageOnly.Checked })
            $imageDestDir = $form.Invoke([Func[string]]{ $txtImageDir.Text })

            # 1. Obtener URL si no se había consultado
            $form.Invoke([Action]{ $logBox.AppendText("`r`n[Paso 1/4] Consultando última versión oficial de Google para '$codename'...`r`n") })
            $info = Get-TapeOSLatestRecoveryInfo -BoardCodename $codename
            
            # 2. Descargar imagen oficial
            $downloadDir = "C:\TapeOS\downloads"
            $destZip = Join-Path $downloadDir $info.FileName
            $form.Invoke([Action]{ 
                $lblStatusUrl.Text = "Descargando: $($info.FileName)..."
                $logBox.AppendText("[Paso 2/4] Descargando imagen desde CDN oficial de Google...`r`n") 
            })

            Start-TapeOSDownload -Url $info.Url -DestinationFile $destZip -ProgressCallback {
                param($percent, $received, $total)
                $form.Invoke([Action]{
                    $progressBar.Value = [math]::Min(100, [int]$percent)
                })
            } | Out-Null

            # 3. Parchear imagen
            $form.Invoke([Action]{ 
                $logBox.AppendText("[Paso 3/4] Descomprimiendo y aplicando parches TapeOS (Legacy EFI, swtpm, GPU, Google Apps: $(if ($enableGoogleApps) { 'SÍ' } else { 'NO' }))...`r`n") 
            })
            $patched = Invoke-TapeOSImagePatch `
                -RecoveryZipPath $destZip `
                -OutputDir "C:\TapeOS\patched" `
                -EnableIA32 ($hwReport.Firmware.IsIA32UEFI) `
                -EnableLegacyGPU $true `
                -EnableSwtpm $true `
                -EnableGoogleApps $enableGoogleApps `
                -ProgressCallback {
                    param($pct, $msg)
                    $form.Invoke([Action]{
                        $progressBar.Value = [int]$pct
                        $logBox.AppendText("  • $msg`r`n")
                    })
                }

            if ($imageOnlyMode) {
                # 4. Guardar como archivo .img (sin grabar)
                $form.Invoke([Action]{ 
                    $logBox.AppendText("[Paso 4/4] Guardando imagen parcheada como archivo .img (sin grabar)...`r`n") 
                })
                $destDir = $imageDestDir.Trim()
                if (-not $destDir) { $destDir = "C:\TapeOS\images" }
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                $imgName = "TapeOS-$($info.Board)-M$($info.Milestone)-$(if ($enableGoogleApps) { 'googleapps' } else { 'lite' }).img"
                $imgPath = Join-Path $destDir $imgName
                Copy-Item -Path $patched.PatchedImagePath -Destination $imgPath -Force
                if (Test-Path $patched.ConfigFile) { Copy-Item -Path $patched.ConfigFile -Destination (Join-Path $destDir "grub.cfg") -Force }

                $form.Invoke([Action]{
                    $progressBar.Value = 100
                    $logBox.AppendText("`r`n✅ ¡IMAGEN CREADA EXITOSAMENTE!`r`nArchivo: $imgPath`r`nPodrás grabarla más tarde con Rufus, Win32DiskImager o con TapeOS (modo USB).`r`n")
                    [System.Windows.Forms.MessageBox]::Show(
                        "¡Imagen TapeOS creada sin grabar!`r`n`r`nRuta: $imgPath`r`n`r`nPara usarla, grábola en un pendrive con Rufus, Win32DiskImager o desde TapeOS (modo USB).",
                        "Imagen .img creada",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    )
                })
            } else {
                # 4. Grabar en pendrive USB
                $form.Invoke([Action]{ 
                    $logBox.AppendText("[Paso 4/4] Grabando imagen parcheada directamente en $($targetUsb.DeviceID)...`r`n") 
                })
                Start-TapeOSUsbFlash `
                    -ImageFilePath $patched.PatchedImagePath `
                    -PhysicalDriveId $targetUsb.DeviceID `
                    -ProgressCallback {
                        param($pct, $speedMBs, $written, $total)
                        $form.Invoke([Action]{
                            $progressBar.Value = [math]::Min(100, [int]$pct)
                            $lblStatusUrl.Text = "Grabando en USB: $pct% ($speedMBs MB/s)"
                        })
                    } | Out-Null

                $form.Invoke([Action]{
                    $progressBar.Value = 100
                    $logBox.AppendText("`r`n✅ ¡PROCESO COMPLETADO EXITOSAMENTE!`r`nEl pendrive está listo para arrancar en cualquier equipo con EFI.`r`n")
                    [System.Windows.Forms.MessageBox]::Show(
                        "¡TapeOS ha sido grabado exitosamente en tu pendrive!`r`n`r`nYa puedes reiniciar el equipo y arrancar desde el pendrive USB (tecla F12/F11/Esc en el logo).",
                        "Grabación Completada",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    )
                })
            }
        } catch {
            $err = $_.Exception.Message
            $form.Invoke([Action]{
                $logBox.AppendText("❌ ERROR: $err`r`n")
                [System.Windows.Forms.MessageBox]::Show(
                    "Ocurrió un error en el proceso:`r`n$err",
                    "Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            })
        } finally {
            $form.Invoke([Action]{
                $btnFullAuto.Enabled = $true
                $btnCheckOnline.Enabled = $true
            })
        }
    })
})

# Mostrar formulario
[void]$form.ShowDialog()
