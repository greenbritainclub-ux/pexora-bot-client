param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. 'C:\CanaryTools\FirstLaunchV1\OsrsNetworkPolicyV2.ps1'
Assert-ONPV2Guest
if(!(Test-Path -LiteralPath 'C:\PreparedRuntime\Resume-FirstIsolatedDt1.ps1')){throw 'Exact DT1 guest mapping required'}
if($OutputDirectory -notmatch '^C:\\CanaryLogs\\plugin-batch-20260906-v1\\dt1-network-[0-9-]+\\fresh-osrs$'){throw 'Unexpected fresh DT1 snapshot directory'}
$taskCase=$OutputDirectory
$taskReport=Join-Path $taskCase 'endpoint-refresh-v4.json'
$taskManifest=Join-Path $taskCase 'osrs-endpoint-manifest-v4.json'
if((Test-Path -LiteralPath $taskReport) -or (Test-Path -LiteralPath $taskManifest)){throw 'Preserve previous refresh'}
New-Item -ItemType Directory -Path $taskCase -Force | Out-Null
$taskResult=[ordered]@{CreatedUtc=[DateTime]::UtcNow.ToString('o');Stage='official-resources';Passed=$false;Resources=@();Dns=@();FirewallChanged=$false;VendorHttpRequested=$false;Error=$null}
function Save-Refresh {$taskResult|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $taskReport -Encoding UTF8}
function Read-OfficialV4([uri]$Uri,[int]$Hop=0){
    $config=$Uri.Scheme -eq 'https' -and $Uri.Port -eq 443 -and $Uri.Host -match '^(oldschool\.config|oldschool[0-9]{1,3}[a-z]?)\.runescape\.com$' -and $Uri.AbsolutePath -eq '/jav_config.ws'
    $index=$Uri.AbsoluteUri -ceq 'https://oldschool.config.runescape.com/slr.ws?order=LPWM'
    $binary=$Uri.AbsoluteUri -ceq 'http://www.runescape.com/g=oldscape/slr.ws?order=LPWM'
    if($Hop -gt 2 -or $Uri.UserInfo -or (!$config -and !$index -and !$binary)){throw 'Unreviewed official URL'}
    $response=$null;$stream=$null;$memory=$null
    try{
        $request=[Net.HttpWebRequest]::Create($Uri);$request.AllowAutoRedirect=$false;$request.Timeout=15000;$request.ReadWriteTimeout=15000;$request.Proxy=$null;$request.UseDefaultCredentials=$false
        $response=$request.GetResponse()
        if($config -and [int]$response.StatusCode -in @(301,302,307,308)){
            $next=[uri]::new($Uri,$response.Headers['Location']);$response.Close();$response=$null
            return Read-OfficialV4 $next ($Hop+1)
        }
        if([int]$response.StatusCode -ne 200){throw 'Official resource status differs'}
        $limit=if($index){2097152}else{131072}
        $stream=$response.GetResponseStream();$memory=[IO.MemoryStream]::new();$buffer=New-Object byte[] 4096
        while(($n=$stream.Read($buffer,0,$buffer.Length)) -gt 0){if($memory.Length+$n -gt $limit){throw 'Official resource size bound'};$memory.Write($buffer,0,$n)}
        [pscustomobject]@{Url=$Uri.AbsoluteUri;Status=200;ContentType=[string]$response.ContentType;Bytes=$memory.ToArray()}
    }finally{if($memory){$memory.Dispose()};if($stream){$stream.Dispose()};if($response){$response.Close()}}
}
function Digest-V4([byte[]]$Bytes){$sha=[Security.Cryptography.SHA256]::Create();try{[BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace('-','')}finally{$sha.Dispose()}}
try{
    Save-Refresh
    $config=Read-OfficialV4 ([uri]'https://oldschool.config.runescape.com/jav_config.ws?m=0')
    $found=[regex]::Matches([Text.Encoding]::UTF8.GetString($config.Bytes),'(?m)^param=17=([^\r\n]+)')
    if($found.Count -ne 1 -or $found[0].Groups[1].Value -cne 'http://www.runescape.com/g=oldscape/slr.ws?order=LPWM'){throw 'Official world-list configuration changed'}
    $index=Read-OfficialV4 ([uri]'https://oldschool.config.runescape.com/slr.ws?order=LPWM')
    $world=Read-OfficialV4 ([uri]$found[0].Groups[1].Value)
    if($world.ContentType -notlike 'application/octet-stream*' -or $world.Bytes.Length -lt 6){throw 'World-list binary format differs'}
    $worldCount=([int]$world.Bytes[4]*256)+[int]$world.Bytes[5]
    if($worldCount -lt 1 -or $worldCount -gt 2048){throw 'World count outside bound'}
    foreach($item in @($config,$index,$world)){$taskResult.Resources+=@{Url=$item.Url;Status=$item.Status;Bytes=$item.Bytes.Length;SHA256=(Digest-V4 $item.Bytes)}}
    $worldHosts=@([regex]::Matches([Text.Encoding]::UTF8.GetString($index.Bytes),'(?i)(?<![a-z0-9.-])oldschool[0-9]{1,3}[a-z]?\.runescape\.com')|ForEach-Object {$_.Value.ToLowerInvariant()}|Sort-Object -Unique)
    if($worldHosts.Count -lt 1 -or $worldHosts.Count -gt 510 -or 'oldschool1.runescape.com' -notin $worldHosts){throw 'Official world host inventory differs'}
    $taskResult.Stage='fresh-dns';Save-Refresh
    $endpoints=@();$mappings=@();$worldListIP=$null
    foreach($hostname in @('oldschool.config.runescape.com','www.runescape.com')+$worldHosts){
        $answers=@(Resolve-DnsName -Name $hostname -Type A -DnsOnly -ErrorAction Stop|Where-Object Type -eq A)
        if(!$answers.Count -or $answers.Count -gt 8){throw 'Official DNS answer count'}
        if($hostname -eq 'www.runescape.com' -and $answers.Count -ne 1){throw 'World-list endpoint became ambiguous'}
        $ports=if($hostname -eq 'www.runescape.com'){@(80,443)}elseif($hostname -eq 'oldschool.config.runescape.com'){@(443)}else{@(80,443,43594,43595)}
        foreach($answer in $answers){
            if($answer.Name -notmatch '(?i)(\.jagex\.com$|^oldschool[0-9]{1,3}[a-z]?\.osrs\.aws\.jagex\.network$)'){throw 'Unexpected official DNS infrastructure'}
            $address=[string]$answer.IPAddress;Assert-ONPV2PublicIPv4 $address
            $endpoints+=@{IPAddress=$address;Ports=$ports}
            $mappings+=@{Hostname=$hostname;CanonicalName=[string]$answer.Name;IPAddress=$address;Ports=$ports;ObservedTTL=[int]$answer.TTL}
            if($hostname -eq 'www.runescape.com'){$worldListIP=$address}
        }
        $taskResult.Dns+=@{Hostname=$hostname;Answers=@($answers|Select-Object Name,IPAddress,TTL)}
    }
    $vendor=@(Resolve-DnsName -Name 'bot-client.com' -Type A -DnsOnly -ErrorAction Stop|Where-Object Type -eq A|Select-Object -ExpandProperty IPAddress -Unique)
    if(!$vendor.Count -or @($endpoints|Where-Object {$_.IPAddress -in $vendor}).Count){throw 'Vendor DNS overlap or absent negative-test destinations'}
    $after=@(Resolve-DnsName -Name 'www.runescape.com' -Type A -DnsOnly -ErrorAction Stop|Where-Object Type -eq A)
    if($after.Count -ne 1 -or $after[0].IPAddress -ne $worldListIP){throw 'World-list DNS changed during validation'}
    $spec=New-OsrsNetworkPolicyV2Spec -Endpoints $endpoints -Program 'C:\SandboxGuard\first-game-v1\NetworkProbeV2.exe' -RunId 'fresh-v4'
    $created=[DateTime]::UtcNow
    $manifest=[ordered]@{Version=4;CreatedUtc=$created.ToString('o');ExpiresUtc=$created.AddHours(4).ToString('o');Source=$index.Url;Endpoints=$spec.Endpoints;HostMappings=$mappings;RejectedHosts=@();VendorNegativeTestAddresses=$vendor;NoVendorHttpRequests=$true;HttpPort80Allowed=$true;WorldListIPAddress=$worldListIP;WorldListUrl=$world.Url;WorldCount=$worldCount;PolicyBoundary='Fresh public IPv4/TCP ceiling, not URL/TLS identity or all IPC containment. Existing four-hour review window retained; no host, VPN or account changes.'}
    $manifest|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $taskManifest -Encoding UTF8
    $taskResult.ManifestSHA256=(Get-FileHash -LiteralPath $taskManifest -Algorithm SHA256).Hash
    $taskResult.Passed=$true;$taskResult.Stage='complete'
}catch{$taskResult.Error=$_.Exception.Message;$taskResult['ErrorLine']=$_.InvocationInfo.ScriptLineNumber;$taskResult.Stage='failed'}
Save-Refresh
if(!$taskResult.Passed){throw ('Fresh OSRS discovery failed: '+$taskResult.Error)}
