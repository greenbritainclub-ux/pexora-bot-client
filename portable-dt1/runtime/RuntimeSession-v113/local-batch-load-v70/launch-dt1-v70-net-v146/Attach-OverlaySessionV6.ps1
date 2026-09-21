$ErrorActionPreference='Stop'
throw 'DISABLED: this wrapper caused severe guest memory pressure on 2026-09-06; report serialization is the suspected defect. Use the preserved checkpoint; no repeat attachment.'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
$taskFirst='C:\SandboxLocalLogs132\first-launch-20260906-v1'
$taskBatch='C:\SandboxLocalLogs132\plugin-batch-20260906-v1'
$taskWork='C:\SandboxGuard\first-game-v1'
$taskKit='C:\SandboxGuard\overlay-session-v6-attach'
$taskRun='connected-v4-20260906-163512-941'
$taskReport=Join-Path $taskFirst 'overlay-session-v6-attach.json'
$taskNative=Join-Path $taskFirst 'local-overlay-session-v6-native-11204.txt'
$taskJava=Join-Path $taskFirst 'local-overlay-session-v6-11204.txt'
if((Test-Path -LiteralPath $taskReport) -or (Test-Path -LiteralPath $taskNative) -or (Test-Path -LiteralPath $taskJava)){throw 'No repeat attachment'}
$taskResult=[ordered]@{CheckedUtc=[DateTime]::UtcNow.ToString('o');Run=$taskRun;ProcessId=11204;StartTicks=639243093481550749L;Passed=$false;Stage='preflight';Injected=$false;Detached=$false;ThreadSlotRestored=$false;RenderFlagsChanged=$false;SessionFixKept=$false;DrawingDaemonKept=$false;PostPinsPassed=$false;Responding=$false;NativeLines=@();JavaLines=@();PluginStartRequested=$false;PluginSettingsChanged=$false;NativeRenderModeChanged=$false;Error=$null}
function Save-Overlay {$taskResult|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $taskReport -Encoding UTF8}
function Assert-Hash([string]$Path,[string]$Hash){if((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Hash){throw ('Pinned artifact differs: '+$Path)}}
try{
 Save-Overlay
 Assert-Hash (Join-Path $taskFirst 'overlay-session-v6-build\manifest.json') 'DAF8F8CA7D4AC17D869D02ED763D212D90FA187F17406F15DD33549325270DC2'
 Assert-Hash (Join-Path $taskFirst 'overlay-session-v6-attach-kit\manifest.json') '9BE9882F62D7B2079F8A3383AB6D6BD2653953326248E89296DAED3524633B26'
 $taskBuild=Get-Content -LiteralPath (Join-Path $taskFirst 'overlay-session-v6-build\manifest.json') -Raw|ConvertFrom-Json
 $taskGuard=Get-Content -LiteralPath (Join-Path $taskFirst 'overlay-session-v6-attach-kit\manifest.json') -Raw|ConvertFrom-Json
 if(!$taskBuild.Passed -or !$taskGuard.Passed){throw 'Build/guard not passed'}
 foreach($f in $taskBuild.Files){Assert-Hash (Join-Path $taskWork $f.Name) $f.SHA256}
 foreach($f in $taskGuard.Files){Assert-Hash (Join-Path $taskKit $f.Name) $f.SHA256}
 Assert-Hash 'C:\SandboxGuard\renderer-external-behavior-v6-r3\RenderLiveCodePinsV6.h' 'FAD0C48B5D5D523315A2C0E99DFD26BF631510726709A4A3159CBAFF073F32FC'
 $taskReview=Get-Content -LiteralPath (Join-Path $taskFirst 'overlay-session-v6-pin-review.json') -Raw|ConvertFrom-Json
 if(!$taskReview.Passed -or $taskReview.GameId -ne 11204 -or $taskReview.GameStartTicks -ne 639243093481550749L -or $taskReview.HeaderSHA256 -ne $taskBuild.HeaderSHA256){throw 'Exact renderer pin review required'}
 $taskState=Get-Content -LiteralPath (Join-Path $taskFirst ($taskRun+'-state.json')) -Raw|ConvertFrom-Json
 if($taskState.Run -ne $taskRun -or $taskState.GameProcessId -ne 11204 -or $taskState.GameStartTicks -ne 639243093481550749L -or $taskState.HarnessId -ne 7192 -or $taskState.HarnessStartTicks -ne 639243093477763276L -or $taskState.SupervisorId -ne 5128 -or $taskState.SupervisorStartTicks -ne 639243093170604560L -or $taskState.Finished -or $taskState.Phase -ne 'running'){throw 'Reviewed V6 session no longer current'}
 $taskStartup=Get-Content -LiteralPath (Join-Path $taskFirst ($taskRun+'-live.log'))
 foreach($taskMethod in @('onRender0','renderGraphics')){foreach($taskOption in @('exclude','dontinline')){if($taskStartup -notcontains ('DIAGNOSTIC[CHILD_NATIVE_JVM]=RENDER_COMPILER_OPTION_ACCEPTED='+$taskMethod+':'+$taskOption)){throw 'Required compiler setting unproven'}}}
 $taskPrior=Get-Content -LiteralPath (Join-Path $taskBatch ('local-batch-attach-v70-'+$taskRun+'.json')) -Raw|ConvertFrom-Json
 if(!$taskPrior.Passed -or !$taskPrior.Detached -or !$taskPrior.SlotRestored -or !$taskPrior.PostPinsPassed -or $taskPrior.ProcessId -ne 11204 -or $taskPrior.ProcessStartTicks -ne 639243093481550749L){throw 'Prior helper cleanup unproven'}
 & powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File (Join-Path $taskKit 'Test-LocalBatchSessionGateV4.ps1') *> (Join-Path $taskFirst 'overlay-session-v6-fresh-session-fixture.txt');if($LASTEXITCODE -ne 0){throw 'Ownership fixture'}
 & 'C:\BuildJdk\bin\java.exe' -cp (Join-Path $taskWork 'LocalOverlaySessionV6.jar') ai.pexora.localboot.LocalOverlaySessionV6 *> (Join-Path $taskFirst 'overlay-session-v6-fresh-java-fixture.txt');if($LASTEXITCODE -ne 0){throw 'Java fixture'}
 & (Join-Path $taskWork 'LocalOverlaySessionFixtureV6.exe') *> (Join-Path $taskFirst 'overlay-session-v6-fresh-native-fixture.txt');if($LASTEXITCODE -ne 0){throw 'Native fixture'}
 & (Join-Path $taskWork 'LocalOverlaySessionInjectorV6.exe') --fixture *> (Join-Path $taskFirst 'overlay-session-v6-fresh-injector-fixture.txt');if($LASTEXITCODE -ne 0){throw 'Injector fixture'}
 & powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File (Join-Path $taskKit 'Validate-OverlaySessionV6.ps1') -Run $taskRun -ExpectedProcessId 11204 -ExpectedStartTicks 639243093481550749
 if($LASTEXITCODE -ne 0){throw 'Fresh native VM guard refused; no attachment'}
 $taskBefore=Get-Content -LiteralPath (Join-Path $taskBatch ('overlay-session-v6-vm-'+$taskRun+'-before.json')) -Raw|ConvertFrom-Json
 if(!$taskBefore.Passed -or !$taskBefore.ThreadSlotFree -or $taskBefore.ProcessId -ne 11204 -or $taskBefore.ProcessStartTicks -ne 639243093481550749L){throw 'Fresh native state differs'}
 $taskGame=Get-Process -Id 11204
 if($taskGame.Path -ne ($taskWork+'\osclient.exe') -or $taskGame.StartTime.ToUniversalTime().Ticks -ne 639243093481550749L -or !$taskGame.Responding){throw 'Game changed'}
 $taskResult.Stage='attaching';Save-Overlay
 & (Join-Path $taskWork 'LocalOverlaySessionInjectorV6.exe') --load '11204' ([string]$taskGame.StartTime.ToFileTimeUtc()) *> (Join-Path $taskFirst 'overlay-session-v6-injector-load.txt')
 if($LASTEXITCODE -ne 0){throw 'Injector refused; no retry'}
 $taskResult.Injected=$true;$taskResult.Stage='waiting';Save-Overlay
 for($i=0;$i -lt 80;$i++){
  if(Test-Path -LiteralPath $taskNative){$taskLines=@(Get-Content -LiteralPath $taskNative);if(@($taskLines|Where-Object {$_ -match '^RESULT='}).Count){$taskResult.NativeLines=$taskLines;break}}
  Start-Sleep -Milliseconds 500
 }
 if(Test-Path -LiteralPath $taskJava){$taskResult.JavaLines=@(Get-Content -LiteralPath $taskJava)}
 $taskResult.Detached=$taskResult.NativeLines -contains 'DETACH_RESULT=0'
 $taskResult.ThreadSlotRestored=$taskResult.NativeLines -contains 'THREAD_SLOT_RESTORED=true'
 $taskResult.RenderFlagsChanged=$taskResult.NativeLines -contains 'SESSION_RENDER_CONFIGURATION_CHANGE_REQUESTED=true;NATIVE_RENDER_MODE_UNCHANGED=true'
 $taskResult.SessionFixKept=$taskResult.NativeLines -contains 'SESSION_FIX_KEPT=true;RESIZE_ADAPTER_ACTIVE=true;PERSISTENT_LAUNCH_FIX=false;VISUAL_CONFIRMATION_REQUIRED=true'
 $taskResult.DrawingDaemonKept=$taskResult.JavaLines -contains 'VERIFY=PASS;UPRIGHT_SURFACE=true;RESIZE_ADAPTER_ACTIVE=true;WORKER_DAEMON=true;NATIVE_UPLOAD_BUFFER_UNCHANGED=true;VISUAL_CONFIRMATION_REQUIRED=true'
 if(!$taskResult.Detached -or !$taskResult.ThreadSlotRestored -or !$taskResult.SessionFixKept -or !$taskResult.DrawingDaemonKept -or $taskResult.NativeLines -notcontains 'RESULT=0'){throw 'Overlay preflight, render verification, or restoration failed; no stacked attachment'}
 & powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File (Join-Path $taskKit 'Validate-OverlaySessionV6.ps1') -Run $taskRun -ExpectedProcessId 11204 -ExpectedStartTicks 639243093481550749 -AfterAttachment
 if($LASTEXITCODE -ne 0){throw 'Post-attachment guard failed'}
 $taskAfter=Get-Content -LiteralPath (Join-Path $taskBatch ('overlay-session-v6-vm-'+$taskRun+'-after.json')) -Raw|ConvertFrom-Json
 $taskResult.PostPinsPassed=$taskAfter.Passed -and $taskAfter.ThreadSlotFree
 foreach($f in $taskBuild.Files){Assert-Hash (Join-Path $taskWork $f.Name) $f.SHA256}
 $taskGame=Get-Process -Id 11204;$taskResult.Responding=$taskGame.Responding -and $taskGame.StartTime.ToUniversalTime().Ticks -eq 639243093481550749L
 $taskResult.Passed=$taskResult.PostPinsPassed -and $taskResult.Responding;$taskResult.Stage='finished'
}catch{$taskResult.Error=$_.Exception.Message;$taskResult.Stage='stopped'}
Save-Overlay
if(!$taskResult.Passed){exit 2}
