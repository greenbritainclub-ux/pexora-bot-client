param([Parameter(Mandatory=$true)][string]$NetworkDirectory,[Parameter(Mandatory=$true)][string]$CodebaseHost)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount' -or $NetworkDirectory -notmatch '^C:\\CanaryLogs\\plugin-batch-20260906-v1\\dt1-network-[0-9-]+$'){throw 'Unexpected DT1 guest network path'}
. 'C:\CanaryTools\FirstLaunchV1\OsrsNetworkPolicyV2.ps1'
$exe='C:\SandboxGuard\first-game-v1\NetworkProbeV2.exe'
$loop='C:\SandboxGuard\first-game-v1\BlockLoopbackV2.exe'
$path=Join-Path $NetworkDirectory 'osrs-endpoint-manifest-v4.json'
$report=[ordered]@{CheckedUtc=[DateTime]::UtcNow.ToString('o');Passed=$false;EndpointManifestSHA256=(Get-FileHash -LiteralPath $path).Hash;Fixtures=$null;Probes=@();Restored=$false;OtherRulesUnchanged=$false;LoopbackRemoved=$false;Error=$null}
$spec=$null;$installed=$false;$before=$null;$listener=$null
function Save-Verification {$report|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $NetworkDirectory 'osrs-network-verification-v4.json') -Encoding UTF8}
function Get-UnrelatedPolicyHash {
    $fw=New-Object -ComObject HNetCfg.FwPolicy2
    $rows=@(foreach($r in $fw.Rules){if($r.ApplicationName -ine $exe){[pscustomobject]@{Name=$r.Name;App=$r.ApplicationName;Enabled=$r.Enabled;Action=$r.Action;Direction=$r.Direction;Protocol=$r.Protocol;Profiles=$r.Profiles;Local=$r.LocalAddresses;Remote=$r.RemoteAddresses;LocalPorts=$r.LocalPorts;RemotePorts=$r.RemotePorts;Group=$r.Grouping}}})
    $sha=[Security.Cryptography.SHA256]::Create();try{[Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($rows|Sort-Object Name|ConvertTo-Json -Depth 4 -Compress))))}finally{$sha.Dispose()}
}
try{
    Save-Verification
    $report.Fixtures=Invoke-OsrsNetworkPolicyV2Fixtures
    if(!$report.Fixtures.Passed){throw 'Policy pure fixtures failed'}
    $build=Get-Content -LiteralPath 'C:\CanaryLogs\first-launch-20260906-v1\connected-build-v2.json' -Raw|ConvertFrom-Json
    foreach($binary in @($exe,$loop)){$pin=@($build.Files|Where-Object Name -eq ([IO.Path]::GetFileName($binary)));if($pin.Count -ne 1 -or (Get-FileHash -LiteralPath $binary).Hash -ne $pin[0].SHA256){throw 'Network fixture binary pin changed'}}
    $m=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
    if([DateTime]::UtcNow -ge [DateTime]::Parse($m.ExpiresUtc)){throw 'Network snapshot expired'}
    & $loop install probe *> (Join-Path $NetworkDirectory 'loopback-install.txt');if($LASTEXITCODE -ne 0){throw 'Probe loopback fence installation failed'};$installed=$true
    & $loop verify probe *> (Join-Path $NetworkDirectory 'loopback-verify.txt');if($LASTEXITCODE -ne 0){throw 'Probe loopback fence readback failed'}
    $before=Get-UnrelatedPolicyHash
    $spec=New-OsrsNetworkPolicyV2Spec -Endpoints $m.Endpoints -Program $exe -RunId ('probe-dt1-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))
    $spec|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $NetworkDirectory 'probe-policy.json') -Encoding UTF8
    $policy=Apply-OsrsNetworkPolicyV2 -Spec $spec
    $config=@($m.HostMappings|Where-Object Hostname -eq 'oldschool.config.runescape.com')[0].IPAddress
    $world=@($m.HostMappings|Where-Object Hostname -eq $CodebaseHost)[0].IPAddress
    $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0);$listener.Start()
    $tests=@(@($config,443,'allow'),@($world,80,'allow'),@($world,443,'allow'),@($world,43594,'allow'),@($world,81,'block'),@('127.0.0.1',$listener.LocalEndpoint.Port,'block'))
    if($env:PEXORA_JAGEX_NETWORK -eq '1'){
        foreach($authHost in @('auth.jagex.com','auth.runescape.com')){
            if(!@($m.HostMappings|Where-Object Hostname -eq $authHost).Count){throw 'Jagex authentication endpoint is missing from the policy'}
        }
    }
    foreach($address in @($m.HostMappings|Where-Object {$_.Hostname -in @('api.runelite.net','auth.jagex.com','auth.runescape.com')}|ForEach-Object IPAddress|Sort-Object -Unique)){$tests+=,@($address,443,'allow');$tests+=,@($address,444,'block')}
    foreach($address in $m.VendorNegativeTestAddresses){$tests+=,@($address,443,'block');$tests+=,@($address,80,'block')}
    foreach($test in $tests){
        $line=(& $exe $test[0] ([string]$test[1]) $test[2]|Out-String).Trim();$code=$LASTEXITCODE
        $report.Probes+=@{Address=$test[0];Port=$test[1];Expected=$test[2];ExitCode=$code;Result=$line};Save-Verification
    }
    if(@($report.Probes|Where-Object ExitCode -ne 0).Count){throw 'A positive or negative transport probe failed'}
    $report.Passed=$true
}catch{$report.Error=$_.Exception.Message}finally{
    if($listener){$listener.Stop()}
    if($spec){try{$restored=Restore-OsrsNetworkPolicyV2 -Spec $spec -Emergency;$report.Restored=$restored.BlanketEnabled -and $restored.OwnedRulesRemoved}catch{$report.Error='Policy restore: '+$_.Exception.Message}}
    if($installed){& $loop remove probe *> (Join-Path $NetworkDirectory 'loopback-remove.txt');$report.LoopbackRemoved=$LASTEXITCODE -eq 0}
    if($before){$report.OtherRulesUnchanged=$before -eq (Get-UnrelatedPolicyHash)}
    $report.Passed=$report.Passed -and $report.Restored -and $report.LoopbackRemoved -and $report.OtherRulesUnchanged -and !$report.Error
    Save-Verification
}
