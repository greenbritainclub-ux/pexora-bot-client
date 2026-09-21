$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

# DT1 network wrapper v2.  This intentionally uses no CIM cmdlets: the
# WDAG guest can reject their provider even when the native network stack is
# healthy.  It only changes DNS inside the disposable Sandbox after proving
# the default resolver cannot answer the official config hostname while a
# direct public resolver can.  The original v1 preflight remains intact.
if($env:USERNAME -ne 'WDAGUtilityAccount' -or !(Test-Path -LiteralPath 'C:\PreparedRuntime\Resume-FirstIsolatedDt1.ps1')){throw 'DT1 Sandbox guest only'}
if(Get-Process -Name osclient -ErrorAction SilentlyContinue){throw 'Preserve the running game before network preparation'}

$root='C:\CanaryLogs\plugin-batch-20260906-v1'
$out=Join-Path $root ('dt1-network-dns-v2-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff'))
[IO.Directory]::CreateDirectory($out)|Out-Null
$report=[ordered]@{
    StartedUtc=[DateTime]::UtcNow.ToString('o')
    Passed=$false
    DefaultDnsAnswers=0
    PublicDnsAnswers=0
    DnsChanged=$false
    Interface=$null
    Error=$null
}
function Save-Report { $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out 'dns-repair-v2.json') -Encoding UTF8 }
function Get-Answers([switch]$Public) {
    $args=@{Name='oldschool.config.runescape.com';Type='A';DnsOnly=$true;ErrorAction='Stop'}
    if($Public){$args.Server='1.1.1.1'}
    @(Resolve-DnsName @args | Where-Object {$_.Type -eq 'A' -and $_.IPAddress -match '^(?:[1-9][0-9]{0,2}|1[0-9]{0,2}|2[0-4][0-9]|25[0-5])(?:\.(?:[0-9]{1,3})){3}$'} | Select-Object -ExpandProperty IPAddress -Unique)
}
try {
    Save-Report
    $default=@(); try{$default=@(Get-Answers)}catch{}
    $public=@(); try{$public=@(Get-Answers -Public)}catch{}
    $report.DefaultDnsAnswers=$default.Count
    $report.PublicDnsAnswers=$public.Count
    if($default.Count -eq 0) {
        if($public.Count -lt 1 -or $public.Count -gt 8){throw 'Public DNS cannot provide a bounded official OSRS answer'}
        $interfaces=@([Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object {
            $_.OperationalStatus -eq 'Up' -and @($_.GetIPProperties().GatewayAddresses | Where-Object {$_.Address.AddressFamily -eq 'InterNetwork' -and $_.Address.ToString() -ne '0.0.0.0'}).Count -gt 0
        })
        if($interfaces.Count -ne 1){throw 'Expected one active guest IPv4 gateway interface'}
        $report.Interface=$interfaces[0].Name
        # netsh is used deliberately.  Set-DnsClientServerAddress is CIM-backed
        # and is the source of the recurring access-denied error in this guest.
        & netsh.exe interface ipv4 set dnsservers name="$($interfaces[0].Name)" static 1.1.1.1 primary validate=no | Out-Null
        if($LASTEXITCODE -ne 0){throw 'Native guest DNS update failed'}
        & ipconfig.exe /flushdns | Out-Null
        if($LASTEXITCODE -ne 0){throw 'Native guest DNS cache flush failed'}
        $after=@(Get-Answers)
        if($after.Count -lt 1 -or $after.Count -gt 8){throw 'Guest DNS did not return a bounded official OSRS answer after native repair'}
        $report.DefaultDnsAnswers=$after.Count
        $report.DnsChanged=$true
    }
    & 'C:\PreparedRuntime\dt1-network-ready-v1\Prepare-Dt1Network.ps1'
    if($LASTEXITCODE -ne 0){throw 'Original DT1 network preflight failed after DNS verification'}
    $report.Passed=$true
} catch {
    $report.Error=$_.Exception.Message
    throw
} finally {
    Save-Report
}
