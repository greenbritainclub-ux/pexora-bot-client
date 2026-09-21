$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:USERNAME -ne 'WDAGUtilityAccount') { throw 'Guest only' }
$reportPath = 'C:\CanaryLogs\gpu-retry-v95\profile-materialize-v116.json'
$copyLogPath = 'C:\CanaryLogs\gpu-retry-v95\profile-materialize-v116-robocopy.log'
$report = [ordered]@{ StartedUtc = [DateTime]::UtcNow.ToString('o'); Passed = $false; Files = 0; Bytes = 0L; Error = $null }
try {
    if (Get-Process -Name osclient -ErrorAction SilentlyContinue) { throw 'Client must be stopped' }
    $source = 'C:\PreparedRuntime\first-game-v1\profile'
    $target = 'C:\SandboxGuard\first-game-v1\profile'
    $item = Get-Item -LiteralPath $target -Force
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.LinkType -ne 'Junction' -or @($item.Target) -notcontains $source) { throw 'Profile link identity changed' }
    $item.Delete()
    New-Item -ItemType Directory -Path $target | Out-Null
    ('STARTED_UTC=' + [DateTime]::UtcNow.ToString('o')) | Set-Content -LiteralPath $copyLogPath -Encoding UTF8
    $archive = 'C:\PreparedRuntime\profile-v116.tar'
    if (Test-Path -LiteralPath $archive -PathType Leaf) {
        if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne '0B5562979A60F76E9DBD7B910C27C74789171A8BA1132C2E1F53061D9AFA8B09') {
            throw 'Profile archive pin mismatch'
        }
        & tar.exe -xf $archive -C $target
        if ($LASTEXITCODE -ne 0) { throw ('Profile archive extraction failed: ' + $LASTEXITCODE) }
        'METHOD=PINNED_TAR;COMPLETED=true' | Add-Content -LiteralPath $copyLogPath -Encoding UTF8
    } else {
        # Compatibility fallback for historical runtimes without the archive.
        & robocopy.exe $source $target /E /XJ /J /MT:8 /R:0 /W:0 /NP /NFL /NDL /NJH /LOG+:$copyLogPath
        if ($LASTEXITCODE -ge 8) { throw ('Profile copy failed: ' + $LASTEXITCODE) }
    }
    $files = @(Get-ChildItem -LiteralPath $target -File -Recurse)
    $sourceFiles = @(Get-ChildItem -LiteralPath $source -File -Recurse)
    if ($files.Count -ne $sourceFiles.Count) { throw 'Profile file count mismatch' }
    $report.Files = $files.Count
    $report.Bytes = ($files | Measure-Object -Property Length -Sum).Sum
    foreach ($required in @('.detuksosrs\logs\client.log', '.detuksosrs\settings.properties', 'AppData\Local')) {
        if (-not (Test-Path -LiteralPath (Join-Path $target $required))) { throw ('Profile path missing: ' + $required) }
    }
    $report.Passed = $true
} catch {
    $report.Error = $_.Exception.Message
}
$report.CompletedUtc = [DateTime]::UtcNow.ToString('o')
$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding UTF8
if (-not $report.Passed) { exit 2 }
exit 0
