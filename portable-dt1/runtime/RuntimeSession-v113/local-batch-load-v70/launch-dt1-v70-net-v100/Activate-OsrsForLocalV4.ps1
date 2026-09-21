param([ValidatePattern('^connected-v4-[0-9-]+$')][string]$Run)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
. 'C:\CanaryTools\FirstLaunchV1\OsrsNetworkPolicyV2.ps1'
$case='C:\CanaryLogs\first-launch-20260906-v1';$work='C:\SandboxGuard\first-game-v1'
$networkDirectory=$env:PEXORA_DT1_NETWORK
if($networkDirectory -notmatch '^C:\\CanaryLogs\\plugin-batch-20260906-v1\\dt1-network-[0-9-]+$'){throw 'Verified DT1 dependency network path missing'}
$manifestPath=Join-Path $networkDirectory 'osrs-endpoint-manifest-v4.json'
$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
$verified=Get-Content -LiteralPath (Join-Path $networkDirectory 'osrs-network-verification-v4.json') -Raw|ConvertFrom-Json
if(!$verified.Passed -or !$verified.Restored -or !$verified.OtherRulesUnchanged -or [DateTime]::UtcNow -gt [DateTime]::Parse($manifest.ExpiresUtc)){throw 'Network validation failed or endpoint snapshot expired'}
if((Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash -ne $verified.EndpointManifestSHA256){throw 'Endpoint snapshot differs from tested policy'}
foreach($direction in @('Inbound','Outbound')){
    $name='Pexora-FirstGame-v1-GameLoadTestOverlayV2.exe-'+$direction
    # NetSecurity cmdlets query CIM and are denied in this Sandbox profile.
    # Use the already-approved firewall COM interface instead.
    $fw=New-Object -ComObject HNetCfg.FwPolicy2
    $found=@($fw.Rules | Where-Object {$_.Name -ceq $name})
    if(!$found.Count){
        $new=New-Object -ComObject HNetCfg.FWRule
        $new.Name=$name;$new.Grouping='Pexora-FirstGame-v1';$new.Description='Disposable guest harness fence'
        $new.ApplicationName=($work+'\GameLoadTestOverlayV2.exe');$new.Direction=if($direction -eq 'Inbound'){1}else{2}
        $new.Action=0;$new.Profiles=2147483647;$new.InterfaceTypes='All';$new.EdgeTraversal=$false;$new.Protocol=256;$new.LocalAddresses='*';$new.RemoteAddresses='*';$new.Enabled=$true
        $fw.Rules.Add($new);$found=@($fw.Rules | Where-Object {$_.Name -ceq $name})
    }
    if($found.Count -ne 1 -or !$found[0].Enabled -or [int]$found[0].Action -ne 0 -or [int]$found[0].Direction -ne $(if($direction -eq 'Inbound'){1}else{2}) -or $found[0].ApplicationName -ine ($work+'\GameLoadTestOverlayV2.exe') -or $found[0].RemoteAddresses -ne '*'){throw 'Harness network fence mismatch'}
}
$fw=New-Object -ComObject HNetCfg.FwPolicy2
$inbound=@($fw.Rules | Where-Object {$_.Name -ceq 'Pexora-FirstGame-v1-osclient.exe-Inbound'})
if($inbound.Count -ne 1 -or !$inbound[0].Enabled -or [int]$inbound[0].Action -ne 0 -or [int]$inbound[0].Direction -ne 1 -or $inbound[0].ApplicationName -ine ($work+'\osclient.exe') -or $inbound[0].RemoteAddresses -ne '*'){throw 'Game inbound block mismatch'}
$spec=New-OsrsNetworkPolicyV2Spec -Endpoints $manifest.Endpoints -Program ($work+'\osclient.exe') -RunId $Run
$spec|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $case ($Run+'-policy.json')) -Encoding UTF8
& (Join-Path $work 'BlockLoopbackV2.exe') install game *> (Join-Path $case ($Run+'-loopback-install.txt'))
if($LASTEXITCODE -ne 0){throw 'Local proxy block installation failed'}
& (Join-Path $work 'BlockLoopbackV2.exe') verify game *> (Join-Path $case ($Run+'-loopback-verify.txt'))
if($LASTEXITCODE -ne 0){throw 'Local proxy block verification failed'}
$result=Apply-OsrsNetworkPolicyV2 -Spec $spec
$result|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $case ($Run+'-policy-active.json')) -Encoding UTF8
exit 0
