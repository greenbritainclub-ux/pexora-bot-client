param([int]$SupervisorId,[long]$SupervisorStartTicks,[ValidatePattern('^connected-v4-[0-9-]+$')][string]$Run)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
$case='C:\SandboxLocalLogs132\first-launch-20260906-v1';$game='C:\SandboxGuard\first-game-v1\osclient.exe'
$statePath=Join-Path $case ($Run+'-state.json');$report=Join-Path $case ($Run+'-watchdog.json')
$r=[ordered]@{Run=$Run;Ready=$true;Finished=$false;BlockAllRestored=$false;OwnedHarnessStopped=$false;Error=$null}
$r|ConvertTo-Json|Set-Content -LiteralPath $report -Encoding UTF8
while($true){
    $supervisor=Get-Process -Id $SupervisorId -ErrorAction SilentlyContinue
    if(!$supervisor -or $supervisor.StartTime.ToUniversalTime().Ticks -ne $SupervisorStartTicks){break}
    Start-Sleep -Milliseconds 500
}
try{
    $rule=Get-NetFirewallRule -Name 'Pexora-FirstGame-v1-osclient.exe-Outbound' -PolicyStore ActiveStore
    $app=$rule|Get-NetFirewallApplicationFilter;$address=$rule|Get-NetFirewallAddressFilter
    if($rule.Action -ne 'Block' -or $rule.Direction -ne 'Outbound' -or $app.Program -ne $game -or $address.RemoteAddress -ne 'Any'){throw 'Baseline rule identity differs'}
    Set-NetFirewallRule -Name $rule.Name -Enabled True
    $r.BlockAllRestored=(Get-NetFirewallRule -Name $rule.Name -PolicyStore ActiveStore).Enabled -eq 'True'
    if(Test-Path -LiteralPath $statePath){
        $state=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json
        if($state.Run -ne $Run){throw 'State identity mismatch'}
        if($state.HarnessId){
            $h=Get-Process -Id $state.HarnessId -ErrorAction SilentlyContinue
            if($h -and $h.Path -eq 'C:\SandboxGuard\first-game-v1\GameLoadTestOverlayV2.exe' -and $h.StartTime.ToUniversalTime().Ticks -eq $state.HarnessStartTicks){Stop-Process -InputObject $h;$r.OwnedHarnessStopped=$true}
        }
    }
    & 'C:\SandboxLocalTools132\NextPluginsV1\Restore-OsrsForLocalV4.ps1' -Run $Run
    if($LASTEXITCODE -ne 0){throw 'Owned policy cleanup failed'}
    $r.Finished=$true
}catch{$r.Error=$_.Exception.GetType().Name}
$r|ConvertTo-Json|Set-Content -LiteralPath $report -Encoding UTF8
