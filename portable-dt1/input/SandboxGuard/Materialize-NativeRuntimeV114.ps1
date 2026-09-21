$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($PSCommandPath -ne 'C:\CanaryTools\Materialize-NativeRuntimeV114.ps1' -or $env:USERNAME -ne 'WDAGUtilityAccount') { throw 'Guest only' }

$reportPath = 'C:\CanaryLogs\gpu-retry-v95\native-materialize-v114.json'
$report = [ordered]@{ StartedUtc = [DateTime]::UtcNow.ToString('o'); Passed = $false; Files = 0; Bytes = 0L; Error = $null }
try {
    if (Get-Process -Name osclient -ErrorAction SilentlyContinue) { throw 'Client must be stopped' }
    $source = 'C:\PreparedRuntime\first-game-v1'
    $target = 'C:\SandboxGuard\first-game-v1'
    if (-not (Test-Path -LiteralPath (Join-Path $source 'osclient.exe'))) { throw 'Prepared native runtime missing' }
    $item = Get-Item -LiteralPath $target -Force
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.LinkType -ne 'Junction' -or @($item.Target) -notcontains $source) { throw 'Native runtime link identity changed' }
    $item.Delete()
    New-Item -ItemType Directory -Path $target | Out-Null
    foreach ($file in Get-ChildItem -LiteralPath $source -File) {
        $destination = Join-Path $target $file.Name
        Copy-Item -LiteralPath $file.FullName -Destination $destination
        if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash) { throw ('Native file copy mismatch: ' + $file.Name) }
        $report.Files++
        $report.Bytes += $file.Length
    }
    foreach ($directory in Get-ChildItem -LiteralPath $source -Directory) {
        New-Item -ItemType Junction -Path (Join-Path $target $directory.Name) -Target $directory.FullName | Out-Null
    }
    if (-not (Test-Path -LiteralPath (Join-Path $target 'temp'))) {
        New-Item -ItemType Directory -Path (Join-Path $target 'temp') | Out-Null
    }
    foreach ($required in @('osclient.exe', 'core.dll', 'opengl32.dll', 'libgallium_wgl.dll', 'GameLoadTestOverlayV2.exe')) {
        $requiredPath = Join-Path $target $required
        if (-not (Test-Path -LiteralPath $requiredPath)) { throw ('Native file missing: ' + $required) }
        if ((Get-Item -LiteralPath $requiredPath).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw ('Native file still linked: ' + $required) }
    }
    $report.Passed = $true
} catch {
    $report.Error = $_.Exception.Message
}
$report.CompletedUtc = [DateTime]::UtcNow.ToString('o')
$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding UTF8
if (-not $report.Passed) { exit 2 }
exit 0
