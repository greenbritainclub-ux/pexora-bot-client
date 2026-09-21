param([ValidatePattern('^connected-v4-[0-9-]+$')][string]$Run)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
. 'C:\CanaryTools\FirstLaunchV1\OsrsNetworkPolicyV2.ps1'
$case='C:\CanaryLogs\first-launch-20260906-v1';$work='C:\SandboxGuard\first-game-v1'
$manifestPath='C:\CanaryLogs\plugin-batch-20260906-v1\launch-v54\osrs-endpoint-manifest-v4.json'
$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
$verified=Get-Content -LiteralPath 'C:\CanaryLogs\plugin-batch-20260906-v1\launch-v54\osrs-network-verification-v4.json' -Raw|ConvertFrom-Json
if((Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash -ne 'DEA50F21348163B04FFBD78831F401C412F3BC644411657D4920E5C9E6127508'){throw 'Reviewed world-list endpoint revision differs'}
if(!$verified.Passed -or [DateTime]::UtcNow -gt [DateTime]::Parse($manifest.ExpiresUtc)){throw 'Network validation failed or endpoint snapshot expired'}
if((Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash -ne $verified.EndpointManifestSHA256){throw 'Endpoint snapshot differs from tested policy'}
foreach($direction in @('Inbound','Outbound')){
    $name='Pexora-FirstGame-v1-GameLoadTestOverlayV2.exe-'+$direction
    if(!(Get-NetFirewallRule -Name $name -ErrorAction SilentlyContinue)){New-NetFirewallRule -Name $name -DisplayName $name -Program ($work+'\GameLoadTestOverlayV2.exe') -Direction $direction -Action Block -Enabled True -Profile Any|Out-Null}
    $rule=Get-NetFirewallRule -Name $name -PolicyStore ActiveStore;$app=$rule|Get-NetFirewallApplicationFilter;$addr=$rule|Get-NetFirewallAddressFilter
    if($rule.Enabled -ne 'True' -or $rule.Action -ne 'Block' -or $app.Program -ne ($work+'\GameLoadTestOverlayV2.exe') -or $addr.RemoteAddress -ne 'Any'){throw 'Harness network fence mismatch'}
}
$inbound=Get-NetFirewallRule -Name 'Pexora-FirstGame-v1-osclient.exe-Inbound' -PolicyStore ActiveStore
if($inbound.Enabled -ne 'True' -or $inbound.Action -ne 'Block' -or ($inbound|Get-NetFirewallApplicationFilter).Program -ne ($work+'\osclient.exe') -or ($inbound|Get-NetFirewallAddressFilter).RemoteAddress -ne 'Any'){throw 'Game inbound block mismatch'}
$spec=New-OsrsNetworkPolicyV2Spec -Endpoints $manifest.Endpoints -Program ($work+'\osclient.exe') -RunId $Run
$spec|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $case ($Run+'-policy.json')) -Encoding UTF8
& (Join-Path $work 'BlockLoopbackV2.exe') install game *> (Join-Path $case ($Run+'-loopback-install.txt'))
if($LASTEXITCODE -ne 0){throw 'Local proxy block installation failed'}
& (Join-Path $work 'BlockLoopbackV2.exe') verify game *> (Join-Path $case ($Run+'-loopback-verify.txt'))
if($LASTEXITCODE -ne 0){throw 'Local proxy block verification failed'}
$result=Apply-OsrsNetworkPolicyV2 -Spec $spec
$result|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $case ($Run+'-policy-active.json')) -Encoding UTF8
exit 0
