param([switch]$NegativeFixture)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
. (Join-Path $PSScriptRoot 'Bounded-LocalReportV7.ps1')
$taskOut='C:\CanaryLogs\plugin-batch-20260906-v1\display-preflight-v9-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')+'.json'
$taskReport=[ordered]@{CheckedUtc=[DateTime]::UtcNow.ToString('o');Passed=$false;NegativeFixture=[bool]$NegativeFixture;SessionId=[int](Get-Process -Id $PID).SessionId;Headless=$null;UsableScreens=0;JavaFeature=0;ExitCode=-1;NoWindowsCreated=$true;RuntimeAttached=$false;ErrorType=$null}
try {
 $taskInfo=[Diagnostics.ProcessStartInfo]::new()
 $taskInfo.FileName='C:\BuildJdk\bin\java.exe'
 $taskInfo.Arguments='-Xmx96m '+$(if($NegativeFixture){'-Djava.awt.headless=true '}else{''})+'C:\CanaryTools\NextPluginsV1\DisplayPreflightV9.java'
 $taskInfo.UseShellExecute=$false;$taskInfo.CreateNoWindow=$true
 $taskInfo.RedirectStandardOutput=$true;$taskInfo.RedirectStandardError=$true
 $taskInfo.EnvironmentVariables.Clear()
 foreach($taskPair in @{
   ALLUSERSPROFILE='C:\ProgramData';APPDATA='C:\SandboxGuard\first-game-v1\profile\AppData\Roaming';
   LOCALAPPDATA='C:\SandboxGuard\first-game-v1\profile\AppData\Local';PATH='C:\Windows\System32;C:\Windows';
   SystemDrive='C:';SystemRoot='C:\Windows';WINDIR='C:\Windows';USERNAME='WDAGUtilityAccount';
   USERPROFILE='C:\SandboxGuard\first-game-v1\profile';TEMP='C:\SandboxGuard\first-game-v1\temp';TMP='C:\SandboxGuard\first-game-v1\temp'
 }.GetEnumerator()){$taskInfo.EnvironmentVariables.Add($taskPair.Key,$taskPair.Value)}
 $taskChild=[Diagnostics.Process]::Start($taskInfo)
 try {
  if(!$taskChild.WaitForExit(25000)){$taskChild.Kill();throw 'Display probe timeout'}
  $taskText=$taskChild.StandardOutput.ReadToEnd();$taskError=$taskChild.StandardError.ReadToEnd()
  if($taskText.Length -gt 2048 -or $taskError.Length -gt 8192){throw 'Display probe output limit'}
  $taskReport.ExitCode=[int]$taskChild.ExitCode
 }finally{$taskChild.Dispose()}
 if($taskText -match '(?m)^HEADLESS=(true|false)\r?$'){$taskReport.Headless=$Matches[1] -eq 'true'}
 if($taskText -match '(?m)^USABLE_SCREENS=([0-9]{1,3})\r?$'){$taskReport.UsableScreens=[int]$Matches[1]}
 if($taskText -match '(?m)^JAVA_FEATURE=([0-9]{1,3})\r?$'){$taskReport.JavaFeature=[int]$Matches[1]}
 if($NegativeFixture){$taskReport.Passed=$taskReport.ExitCode -eq 2 -and $taskReport.Headless -eq $true}
 else{$taskReport.Passed=$taskReport.ExitCode -eq 0 -and $taskReport.Headless -eq $false -and $taskReport.UsableScreens -gt 0 -and $taskText -match '(?m)^DISPLAY_PREFLIGHT=passed\r?$'}
}catch{$taskReport.ErrorType=$_.Exception.GetType().FullName}
Write-BoundedLocalReportV7 -Path $taskOut -Report $taskReport
if(!$taskReport.Passed){exit 2}
