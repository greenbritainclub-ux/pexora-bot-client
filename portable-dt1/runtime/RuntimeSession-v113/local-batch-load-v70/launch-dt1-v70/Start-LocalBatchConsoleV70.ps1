$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
$taskCase='C:\CanaryLogs\first-launch-20260906-v1';$taskWork='C:\SandboxGuard\first-game-v1'
$taskNetwork='C:\CanaryLogs\plugin-batch-20260906-v1\launch-v54'
if(@(Get-Process -Name GameLoadTest,GameLoadTestV2,GameLoadTestOverlayV2 -ErrorAction SilentlyContinue).Count -or @(Get-Process -Name osclient -ErrorAction SilentlyContinue|Where-Object Path -eq ($taskWork+'\osclient.exe')).Count){throw 'A local test is already running'}
$taskManifest=Join-Path $taskNetwork 'osrs-endpoint-manifest-v4.json'
if((Get-FileHash -LiteralPath $taskManifest -Algorithm SHA256).Hash -ne 'DEA50F21348163B04FFBD78831F401C412F3BC644411657D4920E5C9E6127508'){throw 'Reviewed endpoint pin differs'}
$taskEndpoints=Get-Content -LiteralPath $taskManifest -Raw|ConvertFrom-Json
$taskVerified=Get-Content -LiteralPath (Join-Path $taskNetwork 'osrs-network-verification-v4.json') -Raw|ConvertFrom-Json
if(!$taskVerified.Passed -or !$taskVerified.Restored -or !$taskVerified.OtherRulesUnchanged -or $taskVerified.EndpointManifestSHA256 -ne 'DEA50F21348163B04FFBD78831F401C412F3BC644411657D4920E5C9E6127508' -or [DateTime]::UtcNow.AddMinutes(10) -ge [DateTime]::Parse($taskEndpoints.ExpiresUtc)){throw 'Fresh verified OSRS endpoint policy required'}
& 'C:\CanaryTools\FirstLaunchV1\Test-PluginListLaunchGate.ps1'
& 'C:\CanaryTools\FirstLaunchV1\Test-WalkerCacheStageV1.ps1'
& 'C:\SandboxGuard\local-batch-load-v70\launch-dt1-v70\Test-LocalBatchSessionGateV4.ps1'
$taskRun='connected-v4-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')
& powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File 'C:\SandboxGuard\local-batch-load-v70\launch-dt1-v70\Run-ConnectedFixturesV4.ps1' -Run $taskRun
if($LASTEXITCODE -ne 0){throw 'Runtime fixture failure'}
$taskP=Start-Process -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ArgumentList @('-NoProfile','-NonInteractive','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File','C:\SandboxGuard\local-batch-load-v70\launch-dt1-v70\Run-LocalBatchConsoleV70.ps1','-Run',$taskRun) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskCase ($taskRun+'-supervisor.log')) -RedirectStandardError (Join-Path $taskCase ($taskRun+'-supervisor-errors.log'))
[ordered]@{Run=$taskRun;SupervisorId=$taskP.Id;SupervisorStartTicks=$taskP.StartTime.ToUniversalTime().Ticks;AutoStopSeconds=$null;StartRequested=$false;PluginBatch='pending';NetworkStatus='pending-policy-verification'}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $taskCase ($taskRun+'-launch.json')) -Encoding UTF8
