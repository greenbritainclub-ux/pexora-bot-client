$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ClientUiLaunchGateV9.ps1')
$start=[datetime]::ParseExact('2026-09-06 19:00:14.000','yyyy-MM-dd HH:mm:ss.fff',[Globalization.CultureInfo]::InvariantCulture)
$good="DIAGNOSTIC[CHILD_NATIVE_JVM]=MILESTONE=Client window attached`nDIAGNOSTIC[CHILD_NATIVE_JVM]=MILESTONE=Client window resized"
$fatal="2026-09-06 19:01:09.939 [main] ERROR c.d.c.w - Error during startup`nCaused by: java.awt.HeadlessException:"
$old="2026-09-06 18:59:09.939 [main] ERROR c.d.c.w - Error during startup`nCaused by: java.awt.HeadlessException:"
$tests=@(
 @{Live=$good;Client='';Expected=$true},
 @{Live='JVM Engine initialized';Client='';Expected=$false},
 @{Live=$good;Client=$fatal;Expected=$false},
 @{Live=$good;Client=$old;Expected=$true},
 @{Live=$good;Client="2026-09-06 19:01:09.939 [main] WARN library - java.net.SocketException: Permission denied";Expected=$true},
 @{Live='untrusted prefix DIAGNOSTIC[CHILD_NATIVE_JVM]=MILESTONE=Client window attached';Client='';Expected=$false},
 @{Live=$good;Client="2026-09-06 19:01:09.939 [main] WARN test - java.awt.HeadlessException:";Expected=$false}
)
foreach($t in $tests){$r=Get-ClientUiEvidenceV9 -LiveText $t.Live -ClientText $t.Client -StartedLocal $start;if($r.Passed -ne $t.Expected){throw 'UI readiness fixture failed'}}
Write-Output ('UI_READINESS_FIXTURES_PASSED='+$tests.Count)
