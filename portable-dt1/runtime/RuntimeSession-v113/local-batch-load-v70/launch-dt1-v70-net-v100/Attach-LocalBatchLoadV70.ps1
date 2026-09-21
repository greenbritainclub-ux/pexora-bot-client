param([Parameter(Mandatory=$true)][ValidatePattern('^connected-v4-[0-9-]+$')][string]$Run,[Parameter(Mandatory=$true)][int]$ExpectedProcessId,[Parameter(Mandatory=$true)][long]$ExpectedStartTicks)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
$taskCase='C:\CanaryLogs\plugin-batch-20260906-v1';$taskWork='C:\SandboxGuard\local-batch-load-v70'
$taskReport=Join-Path $taskCase ('local-batch-attach-v70-'+$Run+'.json')
$taskNative=Join-Path $taskCase ('local-batch-load-v70-native-'+$ExpectedProcessId+'.txt')
$taskJava=Join-Path $taskCase ('local-batch-load-v70-'+$ExpectedProcessId+'.txt')
if((Test-Path -LiteralPath $taskReport) -or (Test-Path -LiteralPath $taskNative) -or (Test-Path -LiteralPath $taskJava)){throw 'No repeated attachment or report overwrite'}
$taskPins=@{
 'LocalBatchLoadV70.jar'='F6DDC2D5616B86ED88BD71278401990347D7E7BACF5F8CB0E7B2BAD17AB6CB4E'
 'LocalBatchLoadV70.dll'='BF64805F6A8A9A514471C84BE9EA4FA8EE011D67C122DFEBB73DAF69E1EBE18D'
 'LocalBatchFixtureV70.exe'='F4C197344A63171BDB725943941FD28CDB19E84187866C7025AE82C4C86394D9'
 'LocalBatchInjectorV70.exe'='539CD32F5D1703C7CA8551210F54D4C71BE4AABEBD26684F330217B3C1FCF33A'
 'PexoraResourcePins.h'='F9EE999CB5FAC230E9F617EA0CB62F5E2949536029C14177D55D5216EB009D77'
}
$taskResult=[ordered]@{Run=$Run;CheckedUtc=[DateTime]::UtcNow.ToString('o');ProcessId=$ExpectedProcessId;ProcessStartTicks=$ExpectedStartTicks;Stage='preflight';Passed=$false;Injected=$false;Detached=$false;SlotRestored=$false;Responding=$false;PostPinsPassed=$false;NativeLines=@();JavaLines=@();StartRequested=$false;StopRequested=$false;Error=$null}
function Save-BatchAttach {$taskResult|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $taskReport -Encoding UTF8}
function Read-BatchText([string]$Path){$stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite);$reader=[IO.StreamReader]::new($stream);try{if($stream.Length -gt 2097152){throw 'Helper report size bound'};$reader.ReadToEnd()}finally{$reader.Dispose()}}
try{
 Save-BatchAttach
 foreach($name in $taskPins.Keys){if((Get-FileHash -LiteralPath (Join-Path $taskWork $name) -Algorithm SHA256).Hash -ne $taskPins[$name]){throw 'V6 helper pin'}}
 $deploy=Get-Content -LiteralPath (Join-Path $taskCase 'local-batch-deployment-v70.json') -Raw|ConvertFrom-Json
 if($deploy.Plugins.Count -ne 4){throw 'Four-plugin deployment required'}
 foreach($p in $deploy.Plugins){if((Get-FileHash -LiteralPath $p.Jar -Algorithm SHA256).Hash -ne $p.Hash -or (Get-FileHash -LiteralPath (Join-Path $taskWork ($p.Plugin+'-classes.txt')) -Algorithm SHA256).Hash -ne $p.PlanHash -or (Get-FileHash -LiteralPath (Join-Path $taskWork ($p.Plugin+'-parent-classes.txt')) -Algorithm SHA256).Hash -ne $p.ParentPlanHash){throw 'Archive or exact scope changed'}}
 & 'C:\SandboxGuard\local-batch-load-v70\launch-dt1-v70-net-v100\Test-LocalBatchSessionGateV4.ps1' *> (Join-Path $taskCase ($Run+'-session-fixture.txt'))
 & 'C:\BuildJdk\bin\java.exe' -cp (Join-Path $taskWork 'LocalBatchLoadV70.jar') ai.pexora.localboot.LocalBatchLoadV70 *> (Join-Path $taskCase ($Run+'-batch-java-fixture.txt'));if($LASTEXITCODE -ne 0){throw 'Java fixture'}
 & (Join-Path $taskWork 'LocalBatchFixtureV70.exe') *> (Join-Path $taskCase ($Run+'-batch-native-fixture.txt'));if($LASTEXITCODE -ne 0){throw 'Native fixture'}
 & (Join-Path $taskWork 'LocalBatchInjectorV70.exe') --fixture *> (Join-Path $taskCase ($Run+'-batch-injector-fixture.txt'));if($LASTEXITCODE -ne 0){throw 'Injector fixture'}
 & powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File 'C:\SandboxGuard\local-batch-load-v70\launch-dt1-v70-net-v100\Validate-LocalBatchVmV70.ps1' -Run $Run -ExpectedProcessId $ExpectedProcessId -ExpectedStartTicks $ExpectedStartTicks
 if($LASTEXITCODE -ne 0){throw 'Fresh native VM validation failed'}
 $check=Get-Content -LiteralPath (Join-Path $taskCase ('local-batch-vm-v70-'+$Run+'-before.json')) -Raw|ConvertFrom-Json
 if(!$check.Passed -or $check.ProcessId -ne $ExpectedProcessId -or $check.ProcessStartTicks -ne $ExpectedStartTicks){throw 'Native session identity'}
 $game=Get-Process -Id $ExpectedProcessId
 if($game.Path -ne 'C:\SandboxGuard\first-game-v1\osclient.exe' -or $game.StartTime.ToUniversalTime().Ticks -ne $ExpectedStartTicks -or !$game.Responding){throw 'Target changed'}
 & (Join-Path $taskWork 'LocalBatchInjectorV70.exe') --check ([string]$game.Id) ([string]$game.StartTime.ToFileTimeUtc()) *> (Join-Path $taskCase ($Run+'-batch-injector-check.txt'));if($LASTEXITCODE -ne 0){throw 'System-loader target check failed'}
 $taskResult.Stage='attaching';Save-BatchAttach
 & (Join-Path $taskWork 'LocalBatchInjectorV70.exe') --load ([string]$game.Id) ([string]$game.StartTime.ToFileTimeUtc()) *> (Join-Path $taskCase ($Run+'-batch-injector-load.txt'))
 if($LASTEXITCODE -ne 0){throw 'Injector failure; no automatic retry'};$taskResult.Injected=$true;$taskResult.Stage='waiting';Save-BatchAttach
 for($i=0;$i -lt 480;$i++){
  if(Test-Path -LiteralPath $taskNative){$lines=@((Read-BatchText $taskNative) -split '\r?\n');if(@($lines|Where-Object {$_ -match '^RESULT='}).Count){$taskResult.NativeLines=$lines;break}}
  Start-Sleep -Milliseconds 500
 }
 $taskResult.Detached=$taskResult.NativeLines -contains 'DETACH_RESULT=0'
 $taskResult.SlotRestored=$taskResult.NativeLines -contains 'THREAD_SLOT_RESTORED=true'
 if(Test-Path -LiteralPath $taskJava){$taskResult.JavaLines=@((Read-BatchText $taskJava) -split '\r?\n')}
 if(!$taskResult.Detached -or !$taskResult.SlotRestored -or $taskResult.NativeLines -notcontains 'RESULT=0'){throw 'Native helper failed or cleanup unverified; no retry'}
 $required=@("SUMMARY`trequested=4`tregistered=4`trows=4`tdefinitionFailures=0",'RESULT=0','PLUGIN_START_REQUESTED=false','MIKE_ROW_PRESERVED=true;EXISTING_RUNNING_SET_UNCHANGED=true;LIST_REBUILT_ON_EDT=true')
 foreach($line in $required){if($taskResult.JavaLines -notcontains $line){throw 'Complete registration evidence missing'}}
 if(!($taskResult.JavaLines|Where-Object {$_ -match '^INFERNO_DEBUG_OVERLAY_ROUTE=ALWAYS_ON_TOP;PRESTART=true;ROUTE_CHANGED=(true|false);LAYERS_REBUILT=false$'})){throw 'Inferno debug overlay pre-start route missing'}
 foreach($p in $deploy.Plugins){$line="REGISTERED`t"+$p.Plugin+"`tinstances=1`tstarted=false";if($taskResult.JavaLines -notcontains $line){throw 'Selected plugin registration missing'}}
 & powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File 'C:\SandboxGuard\local-batch-load-v70\launch-dt1-v70-net-v100\Validate-LocalBatchVmV70.ps1' -Run $Run -ExpectedProcessId $ExpectedProcessId -ExpectedStartTicks $ExpectedStartTicks -AfterAttachment
 if($LASTEXITCODE -ne 0){throw 'Post-attachment VM/cleanup pins failed'}
 $post=Get-Content -LiteralPath (Join-Path $taskCase ('local-batch-vm-v70-'+$Run+'-after.json')) -Raw|ConvertFrom-Json
 $taskResult.PostPinsPassed=$post.Passed -and $post.ThreadSlotFree
 $after=Get-Process -Id $ExpectedProcessId;$taskResult.Responding=$after.Responding -and $after.StartTime.ToUniversalTime().Ticks -eq $ExpectedStartTicks
 foreach($name in $taskPins.Keys){if((Get-FileHash -LiteralPath (Join-Path $taskWork $name) -Algorithm SHA256).Hash -ne $taskPins[$name]){throw 'Helper changed after attachment'}}
 foreach($p in $deploy.Plugins){if((Get-FileHash -LiteralPath $p.Jar -Algorithm SHA256).Hash -ne $p.Hash){throw 'Plugin changed after attachment'}}
 $taskResult.Passed=$taskResult.PostPinsPassed -and $taskResult.Responding;$taskResult.Stage='finished'
}catch{$taskResult.Error=$_.Exception.Message;$taskResult.Stage='stopped'}
Save-BatchAttach
if(!$taskResult.Passed){exit 2}
