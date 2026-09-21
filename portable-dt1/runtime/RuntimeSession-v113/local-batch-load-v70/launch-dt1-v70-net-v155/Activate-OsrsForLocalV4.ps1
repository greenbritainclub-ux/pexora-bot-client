param([ValidatePattern('^connected-v4-[0-9-]+$')][string]$Run)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
. 'C:\CanaryTools\FirstLaunchV1\OsrsNetworkPolicyV2.ps1'
$case='C:\CanaryLogs\first-launch-20260906-v1';$work='C:\SandboxGuard\first-game-v1'
$manifestPath='C:\CanaryLogs\plugin-batch-20260906-v1\launch-v155\osrs-endpoint-manifest-v4.json'
$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
$verified=Get-Content -LiteralPath 'C:\CanaryLogs\plugin-batch-20260906-v1\launch-v155\osrs-network-verification-v4.json' -Raw|ConvertFrom-Json
if((Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash -ne 'B6FAA9A7A601FC922DBFD86CD996E37E6FAE6A90A3C44128F48AAF9ABB259B2F'){throw 'Reviewed world-list endpoint revision differs'}
 # Local-runtime mode: reuse the structurally verified historical endpoint
 # snapshot; the firewall policy below is applied from it per launch.
 if(!$verified.Passed){throw 'Network validation failed'}
if((Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash -ne $verified.EndpointManifestSHA256){throw 'Endpoint snapshot differs from tested policy'}
$fw=New-Object -ComObject HNetCfg.FwPolicy2
foreach($direction in @('Inbound','Outbound')){
    $name='Pexora-FirstGame-v1-GameLoadTestOverlayV2.exe-'+$direction
    $rules=@($fw.Rules|Where-Object Name -ceq $name)
    if(!$rules.Count){$rule=New-Object -ComObject HNetCfg.FWRule;$rule.Name=$name;$rule.ApplicationName=$work+'\GameLoadTestOverlayV2.exe';$rule.Direction=$(if($direction -eq 'Inbound'){1}else{2});$rule.Action=0;$rule.Enabled=$true;$rule.Profiles=2147483647;$rule.Protocol=256;$rule.InterfaceTypes='All';$fw.Rules.Add($rule);$rules=@($fw.Rules|Where-Object Name -ceq $name)}
    if($rules.Count -ne 1 -or -not [bool]$rules[0].Enabled -or [int]$rules[0].Action -ne 0 -or $rules[0].ApplicationName -ne ($work+'\GameLoadTestOverlayV2.exe') -or $rules[0].RemoteAddresses -ne '*'){throw 'Harness network fence mismatch'}
}
$inbound=@($fw.Rules|Where-Object Name -ceq 'Pexora-FirstGame-v1-osclient.exe-Inbound')
if($inbound.Count -ne 1 -or -not [bool]$inbound[0].Enabled -or [int]$inbound[0].Action -ne 0 -or $inbound[0].ApplicationName -ne ($work+'\osclient.exe') -or $inbound[0].RemoteAddresses -ne '*'){throw 'Game inbound block mismatch'}
$spec=New-OsrsNetworkPolicyV2Spec -Endpoints $manifest.Endpoints -Program ($work+'\osclient.exe') -RunId $Run
$spec|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $case ($Run+'-policy.json')) -Encoding UTF8
& (Join-Path $work 'BlockLoopbackV2.exe') install game *> (Join-Path $case ($Run+'-loopback-install.txt'))
if($LASTEXITCODE -ne 0){throw 'Local proxy block installation failed'}
& (Join-Path $work 'BlockLoopbackV2.exe') verify game *> (Join-Path $case ($Run+'-loopback-verify.txt'))
if($LASTEXITCODE -ne 0){throw 'Local proxy block verification failed'}
$result=Apply-OsrsNetworkPolicyV2 -Spec $spec
$result|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $case ($Run+'-policy-active.json')) -Encoding UTF8
exit 0
