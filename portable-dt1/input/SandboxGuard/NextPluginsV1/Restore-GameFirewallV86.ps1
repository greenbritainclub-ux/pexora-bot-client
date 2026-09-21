$ErrorActionPreference='Stop'
$reportPath='C:\CanaryLogs\ram-restart-v76\firewall-v86.json'
[IO.Directory]::CreateDirectory((Split-Path -Parent $reportPath))|Out-Null
$report=[ordered]@{Passed=$false;Rules=@();Utc=[DateTime]::UtcNow.ToString('o');Error=$null;ExceptionType=$null}
try {
 if(-not (Test-Path -LiteralPath 'C:\SandboxGuard\first-game-v1\osclient.exe')){throw 'Guest runtime only'}
 if(Get-Process osclient -ErrorAction SilentlyContinue){throw 'Game running'}
 $p='C:\SandboxGuard\first-game-v1\osclient.exe'
 $fw=New-Object -ComObject HNetCfg.FwPolicy2
 $rows=@()
 foreach($direction in @('Inbound','Outbound')){
  $name='Pexora-FirstGame-v1-osclient.exe-'+$direction
  $directionValue=if($direction -eq 'Inbound'){1}else{2}
  $found=@($fw.Rules|Where-Object{$_.Name -ceq $name})
  if($found.Count -gt 1){throw ('Firewall rule is ambiguous: '+$name)}
  if(!$found.Count){
   $r=New-Object -ComObject HNetCfg.FWRule
   $r.Name=$name;$r.ApplicationName=$p;$r.Direction=$directionValue;$r.Action=0
   $r.Enabled=$true;$r.Profiles=2147483647;$r.InterfaceTypes='All';$r.Protocol=256
   $r.LocalAddresses='*';$r.RemoteAddresses='*';$r.EdgeTraversal=$false
   $fw.Rules.Add($r)
  } else {
   if([int]$found[0].Action -ne 0 -or [int]$found[0].Direction -ne $directionValue -or -not [string]::Equals($found[0].ApplicationName,$p,[StringComparison]::OrdinalIgnoreCase)){throw ('Refusing to alter unowned firewall rule: '+$name)}
   $found[0].Enabled=$true
  }
  $found=@($fw.Rules|Where-Object{$_.Name -ceq $name})
  if($found.Count -ne 1 -or [int]$found[0].Action -ne 0 -or [int]$found[0].Direction -ne $directionValue -or -not [string]::Equals($found[0].ApplicationName,$p,[StringComparison]::OrdinalIgnoreCase) -or -not [bool]$found[0].Enabled -or $found[0].RemoteAddresses -notin @('*','Any')){throw ('Firewall differs: '+$name+' enabled='+[bool]$found[0].Enabled+' action='+[int]$found[0].Action+' direction='+[int]$found[0].Direction+' remote='+[string]$found[0].RemoteAddresses)}
  $rows+=@{Name=$name;BlockVerified=$true}
 }
 $report.Rules=$rows
 $report.Passed=$true
} catch {
 $report.Error=$_.Exception.Message
 $report.ExceptionType=$_.Exception.GetType().FullName
}
$report|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $reportPath -Encoding UTF8
if(-not $report.Passed){exit 2}
exit 0
