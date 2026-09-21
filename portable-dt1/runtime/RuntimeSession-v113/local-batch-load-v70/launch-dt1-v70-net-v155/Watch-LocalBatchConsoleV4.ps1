param([int]$SupervisorId,[long]$SupervisorStartTicks,[ValidatePattern('^connected-v4-[0-9-]+$')][string]$Run)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
$case='C:\CanaryLogs\first-launch-20260906-v1';$game='C:\SandboxGuard\first-game-v1\osclient.exe'
$statePath=Join-Path $case ($Run+'-state.json');$report=Join-Path $case ($Run+'-watchdog.json')
$r=[ordered]@{Run=$Run;Ready=$true;Finished=$false;BlockAllRestored=$false;OwnedHarnessStopped=$false;Error=$null}
$r|ConvertTo-Json|Set-Content -LiteralPath $report -Encoding UTF8
while($true){
    $supervisor=Get-Process -Id $SupervisorId -ErrorAction SilentlyContinue
    if(!$supervisor -or $supervisor.StartTime.ToUniversalTime().Ticks -ne $SupervisorStartTicks){break}
    Start-Sleep -Milliseconds 500
}
try{
    $fw=New-Object -ComObject HNetCfg.FwPolicy2
    $rules=@($fw.Rules|Where-Object Name -ceq 'Pexora-FirstGame-v1-osclient.exe-Outbound')
    if($rules.Count -ne 1 -or [int]$rules[0].Action -ne 0 -or [int]$rules[0].Direction -ne 2 -or $rules[0].ApplicationName -ne $game -or $rules[0].RemoteAddresses -ne '*'){throw 'Baseline rule identity differs'}
    $rules[0].Enabled=$true
    $r.BlockAllRestored=[bool](@($fw.Rules|Where-Object Name -ceq 'Pexora-FirstGame-v1-osclient.exe-Outbound')[0].Enabled)
    if(Test-Path -LiteralPath $statePath){
        $state=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json
        if($state.Run -ne $Run){throw 'State identity mismatch'}
        if($state.HarnessId){
            $h=Get-Process -Id $state.HarnessId -ErrorAction SilentlyContinue
            if($h -and $h.Path -eq 'C:\SandboxGuard\first-game-v1\GameLoadTestOverlayV2.exe' -and $h.StartTime.ToUniversalTime().Ticks -eq $state.HarnessStartTicks){Stop-Process -InputObject $h;$r.OwnedHarnessStopped=$true}
        }
    }
    . 'C:\CanaryTools\FirstLaunchV1\OsrsNetworkPolicyV2.ps1'
    $spec=Get-Content -LiteralPath (Join-Path $case ($Run+'-policy.json')) -Raw|ConvertFrom-Json
    $closed=Restore-OsrsNetworkPolicyV2 -Spec $spec -Emergency
    if(!$closed.BlanketEnabled -or !$closed.OwnedRulesRemoved){throw 'Owned policy cleanup failed'}
    & 'C:\SandboxGuard\first-game-v1\BlockLoopbackV2.exe' remove game *> (Join-Path $case ($Run+'-loopback-remove.txt'))
    if($LASTEXITCODE -ne 0){throw 'Loopback cleanup failed'}
    $r.Finished=$true
}catch{$r.Error=$_.Exception.GetType().Name}
$r|ConvertTo-Json|Set-Content -LiteralPath $report -Encoding UTF8
