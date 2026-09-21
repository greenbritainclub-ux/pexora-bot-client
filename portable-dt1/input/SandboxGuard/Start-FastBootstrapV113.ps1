$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($PSCommandPath -ne 'C:\CanaryTools\Start-FastBootstrapV113.ps1' -or $env:USERNAME -ne 'WDAGUtilityAccount') { throw 'Guest logon only' }

# Portable distribution bootstrap. It deliberately does not disable security
# controls, install trust roots, or consume account state.
$reportPath = 'C:\CanaryLogs\portable-bootstrap.json'
$report = [ordered]@{ StartedUtc = [DateTime]::UtcNow.ToString('o'); Passed = $false; RuntimeMounted = $false; JdkMounted = $false; Error = $null }
try {
    New-Item -ItemType Directory -Force -Path 'C:\SandboxGuard','C:\CanaryLogs' | Out-Null
    foreach ($directory in Get-ChildItem -LiteralPath 'C:\PreparedRuntime' -Directory) {
        $link = Join-Path 'C:\SandboxGuard' $directory.Name
        if (Test-Path -LiteralPath $link) { throw ('Runtime link collision: ' + $directory.Name) }
        New-Item -ItemType Junction -Path $link -Target $directory.FullName | Out-Null
    }
    foreach ($file in Get-ChildItem -LiteralPath 'C:\PreparedRuntime' -File) {
        # The profile archive is consumed by Materialize-ProfileV116 and is
        # intentionally not copied into the writable bootstrap area.
        if ($file.Name -eq 'profile-v116.tar') { continue }
        if ($file.Length -gt 1MB) { throw ('Unexpected root runtime file: ' + $file.Name) }
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path 'C:\SandboxGuard' $file.Name)
    }
    & 'C:\CanaryTools\Materialize-NativeRuntimeV114.ps1'
    if ($LASTEXITCODE -ne 0) { throw 'Native runtime materialization failed' }
    & 'C:\CanaryTools\Materialize-ProfileV116.ps1'
    if ($LASTEXITCODE -ne 0) { throw 'Profile materialization failed' }
    foreach ($required in @('osclient.exe','core.dll','opengl32.dll','libgallium_wgl.dll','GameLoadTestOverlayV2.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path 'C:\SandboxGuard\first-game-v1' $required))) { throw ('Runtime file missing: ' + $required) }
    }
    $report.RuntimeMounted = $true
    if (-not (Test-Path -LiteralPath 'C:\BuildJdk\bin\java.exe')) { throw 'Prepared JDK mount missing' }
    $report.JdkMounted = $true
    $report.Passed = $true
} catch { $report.Error = $_.Exception.Message }
$report.CompletedUtc = [DateTime]::UtcNow.ToString('o')
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportPath -Encoding UTF8
if (-not $report.Passed) { exit 2 }
