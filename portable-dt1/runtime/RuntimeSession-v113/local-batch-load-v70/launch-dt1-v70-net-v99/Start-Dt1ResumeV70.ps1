param([switch]$ValidateOnly,[ValidatePattern('^connected-v4-[0-9-]+$')][string]$ObserveRun)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
. (Join-Path $PSScriptRoot 'Bounded-LocalReportV7.ps1')
. (Join-Path $PSScriptRoot 'Assert-AllureBehaviorKitV6.ps1')
. (Join-Path $PSScriptRoot 'ClientUiLaunchGateV9.ps1')
$taskFirst='C:\CanaryLogs\first-launch-20260906-v1'
$taskBatch='C:\CanaryLogs\plugin-batch-20260906-v1'
$taskOut=Join-Path $taskBatch ('stable-launch-v7-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')+'.json')
$taskResult=[ordered]@{CheckedUtc=[DateTime]::UtcNow.ToString('o');Passed=$false;Mode='launch';Run=$null;Stage='preflight';StartRequested=$false;ReadinessVerified=$false;GameId=0;GameStartTicks=0L;NativeCleanupVerified=$false;DisplayPreflightPassed=$false;UiStartupVerified=$false;WindowAttached=$false;WindowResized=$false;HeadlessException=$false;UiStartupFailed=$false;FailureCode=$null;PluginStartRequested=$false;OverlayAttachmentRequested=$false;ErrorType=$null}
try {
 Assert-AllureBehaviorKitV6
 if($env:PEXORA_LOCAL_RUNTIME -ne '1'){ & (Join-Path $PSScriptRoot 'Test-ClientUiLaunchGateV9.ps1') }
 if($ValidateOnly){$taskResult.Mode='validate-only';$taskResult.Passed=$true;$taskResult.Stage='validated'}
 else {
  if($ObserveRun){$taskResult.Mode='observe-existing';$taskResult.Run=$ObserveRun}
  else {
   if(@(Get-Process -Name osclient -ErrorAction SilentlyContinue|Where-Object Path -eq 'C:\SandboxGuard\first-game-v1\osclient.exe').Count){throw 'Existing local game; no duplicate'}
   if($env:PEXORA_LOCAL_RUNTIME -ne '1' -and [long](Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory -lt 2000000){throw 'Guest memory preflight'}
   if(@(Get-Process -Name powershell -ErrorAction SilentlyContinue|Where-Object PrivateMemorySize64 -gt 536870912).Count){throw 'PowerShell memory preflight'}
   if((Read-BoundedLocalTextV7 -Path (Join-Path $PSScriptRoot 'Attach-OverlaySessionV6.ps1')) -notmatch "(?m)^throw 'DISABLED:"){throw 'Unsafe prior helper not disabled'}
   # Require a usable guest display before the embedded JVM caches headless state.
   & powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Test-DisplayPreflightV9.ps1')
   if($LASTEXITCODE -ne 0){$taskResult.FailureCode='display-preflight';throw 'Guest display unavailable; connect Sandbox before starting'}
   $taskResult.DisplayPreflightPassed=$true
   Write-Host 'Verifying RuneScape HTTPS and the original DT1 network dependencies...'
   & 'C:\PreparedRuntime\dt1-network-dns-v2\Prepare-Dt1NetworkWithDnsRepairV2.ps1'
   $taskBefore=@(Get-ChildItem -LiteralPath $taskFirst -Filter 'connected-v4-*-launch.json' -File|ForEach-Object Name)
   # Startup truth is the new, validated session report, not inherited process handles.
   # The supervisor already owns its log files; the starter needs no redirected handles.
   $taskStarter=Start-Process -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ArgumentList @('-NoProfile','-NonInteractive','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File','C:\SandboxGuard\local-batch-load-v70\launch-dt1-v70-net-v99\Start-LocalBatchConsoleV70.ps1') -WindowStyle Hidden -PassThru
   $taskResult.StartRequested=$true;$taskResult.Stage='waiting-for-session'
   $taskUntil=[DateTime]::UtcNow.AddSeconds(45)
   do {
    $taskNew=@(Get-ChildItem -LiteralPath $taskFirst -Filter 'connected-v4-*-launch.json' -File|Where-Object {$taskBefore -notcontains $_.Name})
    if($taskNew.Count -gt 1){throw 'Ambiguous new session'}
    if($taskNew.Count -eq 1){$taskLaunch=ConvertFrom-Json -InputObject (Read-BoundedLocalTextV7 -Path $taskNew[0].FullName);$taskResult.Run=[string]$taskLaunch.Run;break}
    Start-Sleep -Milliseconds 250
   }while([DateTime]::UtcNow -lt $taskUntil)
   if(!$taskResult.Run){throw 'No session report; inspect before retrying'}
  }
  $taskResult.Stage='waiting-for-ready';Write-BoundedLocalReportV7 -Path $taskOut -Report $taskResult
  $taskUntil=[DateTime]::UtcNow.AddSeconds(900)
  do {
   $taskPath=Join-Path $taskFirst ($taskResult.Run+'-state.json')
   if(Test-Path -LiteralPath $taskPath){
    # State can briefly be empty while its existing producer overwrites it.
    $taskText=Read-BoundedLocalTextV7 -Path $taskPath
    if($taskText.Trim()){
     $taskState=ConvertFrom-Json -InputObject $taskText
     if($taskState.Run -ne $taskResult.Run -or $taskState.Finished -or $taskState.Error){throw 'Session failed or exited'}
     if($taskState.Phase -eq 'running' -and $taskState.PluginList -eq 'registered-stopped' -and $taskState.BatchPlugins -eq 'registered-stopped'){
      $taskGame=Get-Process -Id $taskState.GameProcessId
      $taskHarness=Get-Process -Id $taskState.HarnessId
      $taskSupervisor=Get-Process -Id $taskState.SupervisorId
      if($taskGame.Path -ne 'C:\SandboxGuard\first-game-v1\osclient.exe' -or $taskGame.StartTime.ToUniversalTime().Ticks -ne $taskState.GameStartTicks -or !$taskGame.Responding -or $taskHarness.Path -ne 'C:\SandboxGuard\first-game-v1\GameLoadTestOverlayV2.exe' -or $taskHarness.StartTime.ToUniversalTime().Ticks -ne $taskState.HarnessStartTicks -or $taskSupervisor.StartTime.ToUniversalTime().Ticks -ne $taskState.SupervisorStartTicks){throw 'Session process identity'}
      if($env:PEXORA_LOCAL_RUNTIME -ne '1' -and (Get-CimInstance Win32_Process -Filter ('ProcessId='+$taskGame.Id)).ParentProcessId -ne $taskHarness.Id){throw 'Game parent identity'}
      $taskLoaded=ConvertFrom-Json -InputObject (Read-BoundedLocalTextV7 -Path (Join-Path $taskBatch ('local-batch-attach-v70-'+$taskResult.Run+'.json')))
      if(!$taskLoaded.Passed -or !$taskLoaded.Detached -or !$taskLoaded.SlotRestored -or !$taskLoaded.PostPinsPassed -or $taskLoaded.ProcessId -ne $taskGame.Id -or $taskLoaded.ProcessStartTicks -ne $taskState.GameStartTicks -or $taskState.Networking -ne 'OSRS-endpoint-restricted'){throw 'Readiness or cleanup not established'}
      $taskResult.NativeCleanupVerified=$true
      $taskUi=Get-ClientUiEvidenceV9 -LiveText (Read-BoundedLocalTextV7 -Path (Join-Path $taskFirst ($taskResult.Run+'-live.log')) -MaximumBytes 1048576) -ClientText (Read-ClientUiLogV9 -Path 'C:\SandboxGuard\first-game-v1\profile\.detuksosrs\logs\client.log') -StartedLocal $taskGame.StartTime
      $taskResult.WindowAttached=$taskUi.WindowAttached;$taskResult.WindowResized=$taskUi.WindowResized;$taskResult.HeadlessException=$taskUi.HeadlessException;$taskResult.UiStartupFailed=$taskUi.StartupFailed
      if($taskUi.HeadlessException -or $taskUi.StartupFailed){$taskResult.FailureCode='client-ui-startup';throw 'Client GUI startup failed; JVM presence is insufficient'}
      if(!$taskUi.Passed){$taskResult.Stage='waiting-for-client-ui';Start-Sleep -Milliseconds 500;continue}
      $taskResult.UiStartupVerified=$true
      $taskResult.GameId=[int]$taskGame.Id;$taskResult.GameStartTicks=[long]$taskState.GameStartTicks;$taskResult.NativeCleanupVerified=$true;$taskResult.ReadinessVerified=$true;$taskResult.Passed=$true;$taskResult.Stage='ready';break
     }
    }
   }
   Start-Sleep -Milliseconds 500
  }while([DateTime]::UtcNow -lt $taskUntil)
  if(!$taskResult.ReadinessVerified){throw 'Readiness deadline; no automatic second launch'}
 }
}catch{$taskResult.ErrorType=$_.Exception.GetType().FullName;$taskResult.Error=$_.Exception.Message;$taskResult.Stage='refused-or-unconfirmed'}
Write-BoundedLocalReportV7 -Path $taskOut -Report $taskResult
if(!$taskResult.Passed){exit 2}
