param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
$launcher='C:\SandboxGuard\local-batch-load-v70\launch-dt1-v70-net-v100\Run-LocalBatchConsoleV70.ps1'
$case='C:\CanaryLogs\first-launch-20260906-v1'
$attempts=0
while($attempts -lt 2){
    $attempts++
    $run='connected-v4-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')
    & powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $launcher -Run $run
    $code=$LASTEXITCODE
    $statePath=Join-Path $case ($run+'-state.json')
    $state=$null
    if(Test-Path -LiteralPath $statePath){$state=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json}
    if($code -eq 0){exit 0}
    $errorText=if($state){[string]$state.Error}else{''}
    $retryable=$errorText -match 'helper|registration|manager|list|attach|TimeoutException|result 22'
    if($attempts -ge 2 -or !$retryable){exit $code}
    Start-Sleep -Seconds 3
}
exit 2
