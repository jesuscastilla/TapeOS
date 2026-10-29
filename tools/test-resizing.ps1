# TapeOS - Test de redimensionamiento de la GUI
$ErrorActionPreference = 'Stop'

$wiz = Get-Content 'G:\TapeOS\installer\windows\TapeOS-Installer.ps1'
$probe = @'
$null = $form.Show()
if (-not $script:hwReport) { Initialize-TapeOSDetection }
$form.Refresh()

$testSizes = @(
    (New-Object System.Drawing.Size(920, 600)),
    (New-Object System.Drawing.Size(1000, 715)),
    (New-Object System.Drawing.Size(1200, 800))
)

$results = @()

foreach ($ts in $testSizes) {
    $form.ClientSize = $ts
    $form.Refresh()
    Start-Sleep -Milliseconds 200
    
    $cw = $form.ClientSize.Width
    $ch = $form.ClientSize.Height
    $desb = @()
    foreach ($c in $form.Controls) {
        if (($c.Left + $c.Width) -gt $cw -or ($c.Top + $c.Height) -gt $ch) {
            $desb += ("{0}: Left={1} Top={2} Right={3} Bottom={4} (Max={5}x{6})" -f $c.Name, $c.Left, $c.Top, ($c.Left + $c.Width), ($c.Top + $c.Height), $cw, $ch)
        }
    }
    
    $v = if ($desb.Count -eq 0) { 'OK' } else { 'OVERFLOW' }
    $results += ("SIZE {0}x{1} -> VERDICT: {2}" -f $cw, $ch, $v)
    if ($desb.Count -gt 0) {
        $results += $desb
    }
}

$results | ForEach-Object { Write-Output $_ }
$form.Close()
'@

$modifiedText = ($wiz -join "`r`n").Replace('[void]$form.ShowDialog()', $probe)
$tmp = 'G:\TapeOS\installer\windows\tmp-test-resize-run.ps1'
Set-Content -Path $tmp -Value $modifiedText -Encoding UTF8
& $tmp
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
