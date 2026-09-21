$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Windows Sandbox guest only'}
# This entry is the Legacy route. Never inherit a Jagex session into it.
foreach($field in @('JX_SESSION_ID','JX_CHARACTER_ID','JX_DISPLAY_NAME','JX_ACCESS_TOKEN','JX_REFRESH_TOKEN','PEXORA_JAGEX_NETWORK')){[Environment]::SetEnvironmentVariable($field,$null,'Process')}
$reportPath='C:\CanaryLogs\first-isolated-dt1-resume.json'
$started=[DateTime]::UtcNow
$result=[ordered]@{StartedUtc=$started.ToString('o');Track='first-isolated-v113-dt1-v70';Stage='checking';Passed=$false;Run=$null;PluginStartRequested=$false;ExtensionsPending=$true;ExtensionsPassed=$false;ExtensionError=$null;Error=$null}
function Save-Resume {$result|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $reportPath -Encoding UTF8}
try {
    Save-Resume
    $existing=@(Get-Process -Name osclient,GameLoadTestV2,GameLoadTestOverlayV2 -ErrorAction SilentlyContinue)
    if($existing.Count){throw 'A client is already open; preserve it before resuming'}
    $reportArchive='C:\PreparedRuntime\Archive-StalePexoraPluginReportsV1.ps1'
    if((Get-FileHash -LiteralPath $reportArchive).Hash -ne 'B43AA3E81D61D7D406EA63DF2A1AC882D72BE2EF6B656CB9AC7F9213C6B3B877'){throw 'Diagnostic archive helper pin'}
    & $reportArchive | Out-Null
    & 'C:\PreparedRuntime\dt1-report-io-v1\Validate-LaunchV100.ps1'
    $ioSource='C:\PreparedRuntime\local-batch-load-v70\launch-dt1-v70-net-v155'
    $ioManifest=Get-Content -LiteralPath (Join-Path $ioSource 'launcher-io-manifest.json') -Raw|ConvertFrom-Json
    foreach($artifact in $ioManifest.Artifacts){if((Get-FileHash -LiteralPath (Join-Path $ioSource $artifact.Name)).Hash -ne $artifact.SHA256){throw ('Mapped V155 launcher pin: '+$artifact.Name)}}
    $helper='C:\PreparedRuntime\mike-manager-ready-v1\LocalPluginProbe.jar'
    if((Get-FileHash -LiteralPath $helper).Hash -ne '7DB1D8A6F482198E99E206B5B8D73754D94F30C24533C13239DC32768230E07F'){throw 'Manager-readiness helper pin mismatch'}
    Copy-Item -LiteralPath $helper -Destination 'C:\SandboxGuard\first-game-v1\LocalPluginProbe.jar' -Force
    if((Get-FileHash -LiteralPath 'C:\SandboxGuard\first-game-v1\LocalPluginProbe.jar').Hash -ne '7DB1D8A6F482198E99E206B5B8D73754D94F30C24533C13239DC32768230E07F'){throw 'Guest manager-readiness helper copy mismatch'}
    $env:PEXORA_LOCAL_RUNTIME='1'
    Write-Host 'Opening Pexora isolated client: Allure DT1 v70, Mike, Inferno, Fight Caves and Colosseum.'
    $result.Stage='launching';Save-Resume
    & 'C:\PreparedRuntime\local-batch-load-v70\launch-dt1-v70-net-v155\Start-Dt1ResumeV70.ps1'
    if($LASTEXITCODE -ne 0){throw 'DT1 launch validation failed; inspect the fresh stable-launch report'}
    $case='C:\CanaryLogs\first-launch-20260906-v1'
    $records=@(Get-ChildItem -LiteralPath $case -File -Filter 'connected-v4-*-state.json'|Where-Object LastWriteTimeUtc -ge $started|Sort-Object LastWriteTimeUtc -Descending)
    if(!$records.Count){throw 'Fresh DT1 session report missing'}
    $state=Get-Content -LiteralPath $records[0].FullName -Raw|ConvertFrom-Json
    $result.Run=$state.Run
    if($state.Phase -ne 'running' -or $state.PluginList -ne 'registered-stopped' -or $state.BatchPlugins -ne 'registered-stopped' -or $state.Error -or $state.Finished){throw 'Complete DT1 registration is not ready'}
    $result.Stage='ready';$result.Passed=$true;Save-Resume
    try {
        Write-Host 'Registering Detuks Delve from the local extension manifest...'
        & 'C:\PreparedRuntime\dt1-plugin-extensions-v9\Register-Dt1PluginExtensions.ps1' -Run $state.Run
        $result.ExtensionsPassed=$true
    } catch {
        $result.ExtensionError=$_.Exception.Message
        Write-Host ('DELVE REGISTRATION: '+$result.ExtensionError) -ForegroundColor Yellow
    } finally {$result.ExtensionsPending=$false;Save-Resume}
    if($result.ExtensionsPassed){Write-Host 'PEXORA DT1 CLIENT READY: the five original plugins plus Detuks Delve are registered.' -ForegroundColor Green}
    else{Write-Host 'The five original DT1 plugins are ready; Delve registration needs attention.' -ForegroundColor Yellow}
    Wait-Process -Id ([int]$state.SupervisorId)
} catch {
    $result.Stage='failed';$result.Error=$_.Exception.Message;$result.ExtensionsPending=$false;Save-Resume
    Write-Host ('PEXORA DT1: '+$result.Error) -ForegroundColor Red
    exit 2
}
