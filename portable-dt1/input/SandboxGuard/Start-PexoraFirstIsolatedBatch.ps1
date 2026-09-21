$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest logon only'}
$desktop=[Environment]::GetFolderPath('Desktop')
$shortcutPath=Join-Path $desktop 'Refresh Plugins And Restart.lnk'
$shell=New-Object -ComObject WScript.Shell
$shortcut=$shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath='C:\PreparedRuntime\Refresh-Plugins-And-Restart.bat'
$shortcut.WorkingDirectory='C:\PreparedRuntime'
$shortcut.IconLocation='C:\Windows\System32\shell32.dll,238'
$shortcut.Description='Swap the staged v72 probe, refresh plugins, and restart Pexora'
$shortcut.Save()
if(!(Test-Path -LiteralPath $shortcutPath -PathType Leaf)){throw 'Refresh desktop shortcut creation failed'}
$launchPath=Join-Path $desktop 'launch.bat'
@'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\PreparedRuntime\Resume-FirstIsolatedDt1.ps1"
if errorlevel 1 (
  echo.
  echo Launch failed. Latest report:
  type "C:\CanaryLogs\first-isolated-dt1-resume.json"
  echo.
  pause
)
'@ | Set-Content -LiteralPath $launchPath -Encoding ASCII
if(!(Test-Path -LiteralPath $launchPath -PathType Leaf)){throw 'Guest launch.bat creation failed'}
"ENTRY_UTC=$([DateTime]::UtcNow.ToString('o'));TRACK=first-isolated-v113-dt1-v70" |
    Set-Content -LiteralPath 'C:\CanaryLogs\first-isolated-entry.txt' -Encoding UTF8
try {
    & 'C:\CanaryTools\Start-FastBootstrapV113.ps1'
    if($LASTEXITCODE -ne 0){throw 'First-isolated v113 bootstrap failed'}
    # The complete DT1 client uses GameLoadTestOverlayV2 and list helper V39.
    # The older local-batch-load-v70\launch folder selects different helpers.
    & 'C:\PreparedRuntime\Resume-FirstIsolatedDt1.ps1'
    if($LASTEXITCODE -ne 0){throw 'Complete DT1 client launch failed'}
} catch {
    [ordered]@{
        TimestampUtc=[DateTime]::UtcNow.ToString('o')
        Track='first-isolated-v113-dt1-v70'
        Message=$_.Exception.Message
        ScriptName=$_.InvocationInfo.ScriptName
        Line=$_.InvocationInfo.ScriptLineNumber
        Stack=$_.ScriptStackTrace
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath 'C:\CanaryLogs\first-isolated-error.json' -Encoding UTF8
    throw
}
