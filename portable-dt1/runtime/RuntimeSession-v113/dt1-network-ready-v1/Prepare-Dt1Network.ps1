$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount' -or !(Test-Path -LiteralPath 'C:\PreparedRuntime\Resume-FirstIsolatedDt1.ps1')){throw 'DT1 Sandbox guest only'}
if(Get-Process -Name osclient -ErrorAction SilentlyContinue){throw 'Preserve the running game before network preparation'}
. 'C:\CanaryTools\FirstLaunchV1\OsrsNetworkPolicyV2.ps1'
$batch='C:\CanaryLogs\plugin-batch-20260906-v1'
$out=Join-Path $batch ('dt1-network-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff'))
[IO.Directory]::CreateDirectory($out)|Out-Null
$report=[ordered]@{StartedUtc=[DateTime]::UtcNow.ToString('o');Passed=$false;Stage='https';MtuChanged=$false;OriginalMtu=$null;ConfigCodebase=$null;ConfigStatus=$null;HostNetworkChanged=$false;Error=$null}
$jagexAuthRequired=$env:PEXORA_JAGEX_NETWORK -eq '1'
$report['JagexAuthRequired']=$jagexAuthRequired
$report['JagexAuthHttpsStatus']=$null
function Save-Network {$report|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $out 'preparation.json') -Encoding UTF8}
function Read-Config {
    $previous=$ErrorActionPreference;$ErrorActionPreference='Continue'
    try{$raw=@(& curl.exe --ipv4 --noproxy '*' --location --connect-timeout 5 --max-time 12 --silent --show-error --write-out "`nPEXORA_HTTP=%{http_code}" 'https://oldschool.config.runescape.com/jav_config.ws?m=0' 2>&1);$code=$LASTEXITCODE}finally{$ErrorActionPreference=$previous}
    $body=($raw|ForEach-Object {[string]$_}) -join "`n"
    $match=[regex]::Match($body,'(?m)^codebase=(https?://oldschool[0-9]{1,3}[a-z]?\.runescape\.com/)\r?$')
    [pscustomobject]@{Passed=($code -eq 0 -and $match.Success);Codebase=$match.Groups[1].Value;Status=[regex]::Match($body,'PEXORA_HTTP=([0-9]{3})').Groups[1].Value}
}
try{
    Save-Network
    $config=Read-Config
    if(!$config.Passed){
        $interfaces=@([Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()|Where-Object {$_.OperationalStatus -eq 'Up' -and @($_.GetIPProperties().GatewayAddresses|Where-Object {$_.Address.AddressFamily -eq 'InterNetwork' -and $_.Address.ToString() -ne '0.0.0.0'}).Count -gt 0})
        if($interfaces.Count -ne 1){throw 'Expected one guest IPv4 gateway'}
        $ipv4=$interfaces[0].GetIPProperties().GetIPv4Properties();$report.OriginalMtu=$ipv4.Mtu
        if($ipv4.Mtu -gt 1280){
            $native=@(& netsh.exe interface ipv4 set subinterface ([string]$ipv4.Index) mtu=1280 store=active)
            if($LASTEXITCODE -ne 0){throw 'Guest MTU repair failed'}
            $report.MtuChanged=$true;$config=Read-Config
            if(!$config.Passed){$restore=@(& netsh.exe interface ipv4 set subinterface ([string]$ipv4.Index) ('mtu='+$ipv4.Mtu) store=active);if($LASTEXITCODE -ne 0){throw 'Guest MTU rollback failed'}}
        }
    }
    if(!$config.Passed){throw 'RuneScape HTTPS configuration is not available; game launch withheld'}
    $report.ConfigCodebase=$config.Codebase;$report.ConfigStatus=$config.Status
    $report.Stage='endpoint-policy';Save-Network
    $manifest=Get-Content -LiteralPath (Join-Path $batch 'launch-v4\osrs-endpoint-manifest-v4.json') -Raw|ConvertFrom-Json
    if([DateTime]::UtcNow.AddMinutes(10) -ge [DateTime]::Parse($manifest.ExpiresUtc)){
        $report.Stage='refreshing-official-endpoints';Save-Network
        $freshDirectory=Join-Path $out 'fresh-osrs'
        & (Join-Path $PSScriptRoot 'Refresh-Dt1OsrsSnapshot.ps1') -OutputDirectory $freshDirectory
        $manifest=Get-Content -LiteralPath (Join-Path $freshDirectory 'osrs-endpoint-manifest-v4.json') -Raw|ConvertFrom-Json
        if([DateTime]::UtcNow.AddMinutes(10) -ge [DateTime]::Parse($manifest.ExpiresUtc)){throw 'Fresh OSRS snapshot is not usable'}
    }
    $old=Get-Content -LiteralPath (Join-Path $batch 'launch-v99\osrs-endpoint-manifest-v4.json') -Raw|ConvertFrom-Json
    $manifest.VendorNegativeTestAddresses=@(@($manifest.VendorNegativeTestAddresses)+@($old.VendorNegativeTestAddresses)|Sort-Object -Unique)
    $extra=@()
    $dependencyHosts=@('api.runelite.net',([uri]$config.Codebase).Host)
    if($jagexAuthRequired){
        # The broker uses auth.jagex.com; the pinned native game's observed
        # game-session token request uses auth.runescape.com.
        $dependencyHosts+=@('auth.jagex.com','auth.runescape.com')
        # A credential-free TLS check; never reuse the account session in probes.
        $authStatus=& curl.exe --ipv4 --noproxy '*' --head --connect-timeout 5 --max-time 12 --silent --output NUL --write-out '%{http_code}' 'https://auth.jagex.com/'
        if($LASTEXITCODE -ne 0 -or [string]$authStatus -notmatch '^[24][0-9]{2}$|^3[0-9]{2}$'){throw 'Jagex authentication HTTPS is unavailable; account launch withheld'}
        $report.JagexAuthHttpsStatus=[string]$authStatus
    }
    foreach($hostName in $dependencyHosts){
        $ports=if($hostName -in @('api.runelite.net','auth.jagex.com','auth.runescape.com')){@(443)}else{@(80,443,43594,43595)}
        $answers=@(Resolve-DnsName -Name $hostName -Type A -DnsOnly|Where-Object Type -eq A)
        if(!$answers.Count -or $answers.Count -gt 8){throw 'Unexpected dependency DNS answer count'}
        foreach($answer in $answers){
            Assert-ONPV2PublicIPv4 $answer.IPAddress
            if($answer.IPAddress -in $manifest.VendorNegativeTestAddresses){throw 'Dependency address overlaps blocked vendor fixture'}
            $extra+=@{IPAddress=[string]$answer.IPAddress;Ports=$ports}
            $manifest.HostMappings+=@{Hostname=$hostName;IPAddress=[string]$answer.IPAddress;Ports=$ports;ObservedTTL=[int]$answer.TTL}
        }
    }
    $spec=New-OsrsNetworkPolicyV2Spec -Endpoints @($manifest.Endpoints+$extra) -Program 'C:\SandboxGuard\first-game-v1\NetworkProbeV2.exe' -RunId 'dt1-prepare'
    $manifest.Endpoints=$spec.Endpoints
    $manifest.PolicyBoundary='OSRS IPv4 plus api.runelite.net TCP443, matching the original DT1 dependency scope. IP ceiling is not hostname isolation on shared CDN addresses. No host policy changes.'
    if($jagexAuthRequired){$manifest.PolicyBoundary='OSRS IPv4 plus api.runelite.net, auth.jagex.com and auth.runescape.com TCP443 for Jagex game-session login. IP ceiling is not hostname isolation on shared CDN addresses. No host policy changes.'}
    $manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $out 'osrs-endpoint-manifest-v4.json') -Encoding UTF8
    $report.Stage='transport-verification';Save-Network
    & (Join-Path $PSScriptRoot 'Verify-Dt1Network.ps1') -NetworkDirectory $out -CodebaseHost ([uri]$config.Codebase).Host
    $verified=Get-Content -LiteralPath (Join-Path $out 'osrs-network-verification-v4.json') -Raw|ConvertFrom-Json
    if(!$verified.Passed){throw ('Dependency network verification failed: '+$verified.Error)}
    $env:PEXORA_DT1_NETWORK=$out
    $report.Stage='ready';$report.Passed=$true
}catch{$report.Error=$_.Exception.Message;throw}finally{Save-Network}
