param([ValidatePattern('^[a-z0-9-]+$')][string]$Tag='v1',[int]$ExpectedProcessId=0,[long]$ExpectedStartTicks=0)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
$case='C:\SandboxLocalLogs132\first-launch-20260906-v1';$work='C:\SandboxGuard\first-game-v1';$report=Join-Path $case ('local-list-attach-'+$Tag+'.json')
if(Test-Path -LiteralPath $report){throw 'Preserve prior attachment; no automatic retry'}
$r=[ordered]@{TimestampUtc=[DateTime]::UtcNow.ToString('o');Stage='preflight';Passed=$false;ProcessId=0;Injected=$false;Detached=$false;Restored=$false;RespondingAfter=$false;NativeResult=$null;JavaResult=$null;StartRequested=$false;Error=$null}
try{
 $build=Get-Content -LiteralPath (Join-Path $case 'local-list-build-v39.json') -Raw|ConvertFrom-Json
 if(!$build.Passed){throw 'Build failed'}
 $expected=@{
  'LocalPluginListProbeV39.jar'='1BCF33C66E539D3E06B06F0102318AB0B532712F296BB0F14C6274AFE75D6CDE'
  'LocalPluginListAttachV39.dll'='E51A2101C72E13B972A0B4154829EEF857D9F9CC24893D5429122C09903B314B'
  'LocalPluginListFixtureV39.exe'='77C0D1268195F086FF8D065D152D819FB6C8D19810507CF30EFC1F158C8A9115'
  'LocalListInjectorV39.exe'='D16F0AE9D6ADB6328CDE1267A87921950C4249C9927BB756A427FBA655B42E69'
 }
 if($build.Files.Count -ne $expected.Count){throw 'Build inventory changed'}
 foreach($name in $expected.Keys){$entry=@($build.Files|Where-Object Name -eq $name);if($entry.Count -ne 1 -or $entry[0].SHA256 -ne $expected[$name]){throw 'Build pin changed'}}
 foreach($f in $build.Files){if((Get-FileHash -LiteralPath (Join-Path $work $f.Name) -Algorithm SHA256).Hash -ne $f.SHA256){throw 'Helper changed'}}
 $injector=Join-Path $work 'LocalListInjectorV39.exe'
 & $injector --fixture *> (Join-Path $case ('local-list-fresh-injector-'+$Tag+'.txt'));if($LASTEXITCODE -ne 0){throw 'Fresh injector fixture failed'}
 & (Join-Path $work 'LocalPluginListFixtureV39.exe') *> (Join-Path $case ('local-list-fresh-native-'+$Tag+'.txt'));if($LASTEXITCODE -ne 0){throw 'Fresh native fixture failed'}
 & 'C:\BuildJdk\bin\java.exe' -cp (Join-Path $work 'LocalPluginListProbeV39.jar') ai.pexora.localboot.LocalPluginListProbe *> (Join-Path $case ('local-list-fresh-java-'+$Tag+'.txt'));if($LASTEXITCODE -ne 0){throw 'Fresh Java fixture failed'}
 & powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File 'C:\SandboxLocalTools132\FirstLaunchV1\Validate-LocalListVm.ps1' -ReportName ('local-list-live-'+$Tag+'.json')
 if($LASTEXITCODE -ne 0){throw 'Fresh live validation failed'}
 $live=Get-Content -LiteralPath (Join-Path $case ('local-list-live-'+$Tag+'.json')) -Raw|ConvertFrom-Json
 if(!$live.Passed){throw 'Live pins failed'}
 $game=Get-Process -Id $live.ProcessId
 if($game.Path -ne (Join-Path $work 'osclient.exe') -or $game.StartTime.ToUniversalTime().Ticks -ne $live.ProcessStartTicks){throw 'Process identity changed'}
 if($ExpectedProcessId -and ($game.Id -ne $ExpectedProcessId -or $live.ProcessStartTicks -ne $ExpectedStartTicks)){throw 'Launcher target changed'}
 $r.ProcessId=$game.Id
 $native=Join-Path $case ('local-plugin-list-native-'+$game.Id+'.txt');$java=Join-Path $case ('local-plugin-list-'+$game.Id+'.txt')
 if((Test-Path -LiteralPath $native) -or (Test-Path -LiteralPath $java)){throw 'Existing list report, do not repeat'}
 $r.Stage='attaching';$r|ConvertTo-Json|Set-Content -LiteralPath $report -Encoding UTF8
 & $injector --load ([string]$game.Id) ([string]$game.StartTime.ToFileTimeUtc()) *> (Join-Path $case ('local-list-injector-'+$Tag+'.log'))
 $r['InjectorExitCode']=$LASTEXITCODE
 if($LASTEXITCODE -ne 0){throw 'Injector transport failed'}
 $r.Injected=$true;$r.Stage='waiting'
 $lines=@();for($attempt=0;$attempt -lt 80;$attempt++){
  if(Test-Path -LiteralPath $native){$lines=@(Get-Content -LiteralPath $native);if(@($lines|Where-Object {$_ -match '^RESULT='}).Count){break}}
  Start-Sleep -Milliseconds 500
 }
 $r.Detached=$lines -contains 'DETACH_RESULT=0';$r.Restored=$lines -contains 'THREAD_SLOT_RESTORED=true'
 $result=@($lines|Where-Object {$_ -match '^RESULT='});if($result.Count -eq 1){$r.NativeResult=[int]$result[0].Substring(7)}
 $r['ListAndConfigReady']=$false
 if(Test-Path -LiteralPath $java){
  $j=@(Get-Content -LiteralPath $java);$result=@($j|Where-Object {$_ -match '^RESULT='});if($result.Count -eq 1){$r.JavaResult=[int]$result[0].Substring(7)}
  $required=@('SELECTED_REGISTERED=true','SELECTED_RUNNING_BEFORE=0','SELECTED_ROWS_AFTER=1','SELECTED_RUNNING_AFTER=0','LIST_REBUILT_ON_EDT=true','SELECTED_CONFIG_PROXY_PRESENT=true','SELECTED_CONFIG_DESCRIPTOR_PRESENT=true','PLUGIN_START_REQUESTED=false')
  $r.ListAndConfigReady=@($required|Where-Object {$j -notcontains $_}).Count -eq 0
 }
 $after=Get-Process -Id $game.Id;$r.RespondingAfter=$after.Responding -and $after.StartTime.ToUniversalTime().Ticks -eq $live.ProcessStartTicks
 foreach($f in $build.Files){if((Get-FileHash -LiteralPath (Join-Path $work $f.Name) -Algorithm SHA256).Hash -ne $f.SHA256){throw 'Helper changed after attachment'}}
 if((Get-FileHash -LiteralPath (Join-Path $work 'core.dll') -Algorithm SHA256).Hash -ne '1DB85EAED5A2761453C81310EE0259F425BDA33EA05108744951E24D08EDBC39'){throw 'Runtime changed after attachment'}
 $plugin=Join-Path $work 'profile\.detuksosrs\plugin-hub\mikes-fishing_6dd9a405a4fd6c6610c63a8d8e3a63f13d64a5ec7de4ecd0bd23dcf44bedb5ae.jar'
 if((Get-FileHash -LiteralPath $plugin -Algorithm SHA256).Hash -ne '6DD9A405A4FD6C6610C63A8D8E3A63F13D64A5EC7DE4ECD0BD23DCF44BEDB5AE'){throw 'Plugin changed after attachment'}
 $r.Passed=$r.Detached -and $r.Restored -and $r.RespondingAfter -and $r.NativeResult -eq 0 -and $r.JavaResult -eq 0 -and $r.ListAndConfigReady
 $r.Stage='finished'
}catch{$r.Error=$_.Exception.Message;$r.Stage='stopped'}
$r|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $report -Encoding UTF8
if(!$r.Passed){exit 2}
