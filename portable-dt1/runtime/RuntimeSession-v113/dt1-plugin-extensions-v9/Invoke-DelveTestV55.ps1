param([switch]$ValidateOnly,[ValidatePattern('^connected-v4-[0-9-]+$')][string]$Run)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$artifactRoot=Join-Path (Split-Path $PSScriptRoot -Parent) 'delve-dt1-v1\test-v55'
$pins=@{
 'detuks-delve-v44.jar'='BA6CF9EF3FCE3E1D1D3633D11973F648764319023E3367CAD99D082582D011BA'
 'DelveTestV55.jar'='1364D3A5488DE31F86A86E29A46E012024F123FF4E21C9723B28CBBDE30267C1'
 'DelveTestV55.dll'='9567D0CA56E50463E91BE07114FCF2CF0B8EB38C40737E4A9E779C541105BA05'
 'DelveTestInjectorV55.exe'='DB2D8338279B1CF481086221062667E52BB6B73F82310282C53F0CFA26EF4403'
}
function Assert-Pins {foreach($name in $pins.Keys){if((Get-FileHash -LiteralPath (Join-Path $artifactRoot $name)).Hash -ne $pins[$name]){throw ('V55 artifact pin: '+$name)}}}
if($ValidateOnly){Assert-Pins;Write-Output 'DELVE_V55_ARTIFACTS_VALID=true';return}
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
$reportRoot='C:\CanaryLogs\delve-dt1-v1';[IO.Directory]::CreateDirectory($reportRoot)|Out-Null
$reportPath=Join-Path $reportRoot 'delve-test-v55-dispatch.json'
$result=[ordered]@{StartedUtc=[DateTime]::UtcNow.ToString('o');CompletedUtc=$null;Passed=$false;Stage='preflight';Run=$null;GamePid=0;GameStartTicks=0L;Action=$null;PluginStartRequested=$false;Error=$null}
function Phase([string]$name){$result.Stage=$name;$result|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $reportRoot 'delve-test-v55-progress.json') -Encoding UTF8}
try {
 Assert-Pins
 if(!$Run){throw 'An explicit ready DT1 run is required'}
 $state=Get-Content -LiteralPath ('C:\CanaryLogs\first-launch-20260906-v1\'+$Run+'-state.json') -Raw|ConvertFrom-Json
 if($state.Run -cne $Run -or $state.PluginList -ne 'registered-stopped' -or $state.BatchPlugins -ne 'registered-stopped' -or $state.Error){throw 'Base plugin readiness is not established'}
 $games=@(Get-Process -Name osclient -ErrorAction SilentlyContinue)
 if($games.Count -ne 1){throw 'Expected one running original DT1 game'}
 $game=$games[0]
 if($state.Phase -ne 'running' -or $state.Finished -or $state.Dt1ResumePolicy -ne 'v70' -or $game.Id -ne $state.GameProcessId -or $game.StartTime.ToUniversalTime().Ticks -ne $state.GameStartTicks -or $game.Path -ne 'C:\SandboxGuard\first-game-v1\osclient.exe'){throw 'DT1 game identity mismatch'}
 $batch=Get-Content -LiteralPath ('C:\CanaryLogs\plugin-batch-20260906-v1\local-batch-attach-v70-'+$Run+'.json') -Raw|ConvertFrom-Json
 if(!$batch.Passed -or !$batch.Detached -or !$batch.SlotRestored -or !$batch.PostPinsPassed -or $batch.ProcessId -ne $game.Id -or $batch.ProcessStartTicks -ne $state.GameStartTicks){throw 'Base attachment cleanup or identity differs'}
 $result.Run=$Run;$result.GamePid=$game.Id;$result.GameStartTicks=$state.GameStartTicks
 $nativePath=Join-Path $reportRoot ('delve-test-native-v55-'+$game.Id+'.txt')
 $javaPath=Join-Path $reportRoot ('delve-test-v55-'+$game.Id+'.txt')
 $configPath=Join-Path $reportRoot ('delve-config-v3-'+$game.Id+'.txt')
 if(Test-Path -LiteralPath $nativePath){
  if(!(Test-Path -LiteralPath $reportPath)){throw 'Previous attachment without identity receipt; no duplicate load'}
  $old=Get-Content -LiteralPath $reportPath -Raw|ConvertFrom-Json
  if(!$old.Passed -or $old.Run -ne $state.Run -or $old.GamePid -ne $game.Id -or $old.GameStartTicks -ne $state.GameStartTicks){throw 'Prior V55 attachment is stale or failed; refusing reinjection'}
  $result.Action='preserved-registered-plugin'
 }else{
  $previous=@(Get-ChildItem -LiteralPath $reportRoot -Filter ('delve-no-start-native-*-'+$game.Id+'.txt'))
  if($previous.Count){throw 'A prior Delve candidate was attached to this JVM; no mixed-version loading'}
  Phase 'stage-pinned-jar'
  $target='C:\SandboxGuard\first-game-v1\profile\.detuksosrs\plugin-hub\detuks-delve_'+$pins['detuks-delve-v44.jar'].ToLowerInvariant()+'.jar'
  if(!(Test-Path -LiteralPath $target)){Copy-Item -LiteralPath (Join-Path $artifactRoot 'detuks-delve-v44.jar') -Destination $target}
  if((Get-FileHash -LiteralPath $target).Hash -ne $pins['detuks-delve-v44.jar']){throw 'Guest candidate pin'}
  $injector=Join-Path $artifactRoot 'DelveTestInjectorV55.exe'
  Phase 'native-preflight'
  & $injector --check ([string]$game.Id) ([string]$game.StartTime.ToFileTimeUtc())
  if($LASTEXITCODE -ne 0){throw ('V55 injector preflight: '+$LASTEXITCODE)}
  Phase 'register-stopped-and-initialize-settings'
  & $injector --load ([string]$game.Id) ([string]$game.StartTime.ToFileTimeUtc())
  if($LASTEXITCODE -ne 0){throw ('V55 injector load: '+$LASTEXITCODE)}
  $result.Action='register-stopped'
 }
 $deadline=[DateTime]::UtcNow.AddSeconds(45)
 do{
  $native=@();$java=@();$config=@()
  if(Test-Path -LiteralPath $nativePath){$native=@(Get-Content -LiteralPath $nativePath)}
  if(Test-Path -LiteralPath $javaPath){$java=@(Get-Content -LiteralPath $javaPath)}
  if(Test-Path -LiteralPath $configPath){$config=@(Get-Content -LiteralPath $configPath)}
  if(@($native -match '^RESULT=').Count -and @($java -match '^RESULT=').Count){break}
  Start-Sleep -Milliseconds 250
 }while([DateTime]::UtcNow -lt $deadline)
 $result['NativeReport']=$nativePath;$result['JavaReport']=$javaPath;$result['ConfigReport']=$configPath
 foreach($proof in @('ATTACH_RESULT=0','DETACH_RESULT=0','THREAD_SLOT_RESTORED=true','RESULT=0')){if($native -notcontains $proof){throw ('Native/Java failure: '+(@($java+$config -match '^(FAILED_PHASE|ERROR_|RESULT=)') -join '; '))}}
 foreach($proof in @('ROW_VISIBLE=detuks-delve;count=1','LIFECYCLE_CONTRACT=DT1_START_VQ_STOP_VN','SETTINGS_INITIALIZED=true','PLUGIN_START_REQUESTED=false','RESULT=0')){if($java -notcontains $proof){throw ('Java proof missing: '+$proof)}}
 foreach($proof in @('MISSING_DEFAULTS_AFTER=0','EXISTING_SETTINGS_PRESERVED=true','SETTINGS_PANEL_OPENED=true','PLUGIN_IDENTITIES_AND_RUNNING_SET_UNCHANGED=true','RESULT=0')){if($config -notcontains $proof){throw ('Config proof missing: '+$proof)}}
 $result['SettingsInitialized']=$true;$result.Stage='ready-stopped';$result.Passed=$true
}catch{$result.Error=$_.Exception.Message}
$result.CompletedUtc=[DateTime]::UtcNow.ToString('o')
$result|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $reportPath -Encoding UTF8
if(!$result.Passed){throw $result.Error}
Write-Output ('DELVE_V55_READY=true;GamePid='+$result.GamePid+';startRequested=false')

