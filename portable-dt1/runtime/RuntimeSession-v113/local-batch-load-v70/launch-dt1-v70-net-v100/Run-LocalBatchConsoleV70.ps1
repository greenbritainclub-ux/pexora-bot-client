param([ValidatePattern('^connected-v4-[0-9-]+$')][string]$Run)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
. 'C:\CanaryTools\FirstLaunchV1\PluginListLaunchGate.ps1'
. (Join-Path $PSScriptRoot 'StartupPhaseGateV35.ps1')
$listGate=New-PluginListLaunchGate;$listWorker=$null;$listReported=$false;$batchWorker=$null;$batchReported=$false;$batchStartedUtc=$null
$case='C:\CanaryLogs\first-launch-20260906-v1';$work='C:\SandboxGuard\first-game-v1'
$Host.UI.RawUI.WindowTitle='PEXORA LOCAL TEST - OSRS connectivity / live diagnostics'
$mutex=[Threading.Mutex]::new($false,'Local\PexoraConnectedV2Exclusive')
$mutexHeld=$false
try{$mutexHeld=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$mutexHeld=$true}
if(!$mutexHeld){$mutex.Dispose();throw 'Another local launch is in progress'}
$coreStartedUtc=$null;$listStartedUtc=$null
$state=[ordered]@{SupervisorStartTicks=(Get-Process -Id $PID).StartTime.ToUniversalTime().Ticks;GameProcessId=0;GameStartTicks=0;AllureLocalStateBackend='v1';AllureLocalBehavior='v1';Dt1ResumePolicy='v70';BatchPlugins='waiting-for-Mike-list';Run=$Run;SupervisorId=$PID;HarnessId=0;HarnessStartTicks=0;Phase='preflight';Networking='blocked';AutoStopSeconds=$null;PluginStartRequested=$false;PluginList='waiting-for-plugin-load';Error=$null;Finished=$false}
$statePath=Join-Path $case ($Run+'-state.json');$stdout=Join-Path $case ($Run+'-live.log');$stderr=Join-Path $case ($Run+'-stderr.log');$harness=$null;$reader=$null
. (Join-Path $PSScriptRoot 'SharedStateIO.ps1')
function Save-State {Write-Dt1SharedStateV1 -Path $statePath -State $state}
try{
    Save-State
    Write-Host 'PEXORA LOCAL TEST - separate from the original Bot Client'
    Write-Host 'No automatic time limit. Close this console/client to stop this test.'
    Write-Host 'Mike and four additional local plugins are registered stopped. No plugin Start is requested.'
    Write-Host 'Use the native plugin row controls; actual fishing and clean Stop still require a functional test.'
    Write-Host 'Preparing reviewed OSRS IPv4/TCP endpoints; other direct destinations remain blocked.'
    $self=Get-Process -Id $PID
    $watcher=Start-Process -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ArgumentList @('-NoProfile','-NonInteractive','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File','C:\SandboxGuard\local-batch-load-v70\launch-dt1-v70-net-v100\Watch-LocalBatchConsoleV4.ps1','-SupervisorId',$PID,'-SupervisorStartTicks',$self.StartTime.ToUniversalTime().Ticks,'-Run',$Run) -WindowStyle Hidden -PassThru
    $watchFile=Join-Path $case ($Run+'-watchdog.json')
    . (Join-Path $PSScriptRoot 'WatchdogReadyGateV34.ps1')
    Wait-WatchdogReadyV34 -Run $Run -IsAlive { $watcher.Refresh(); !$watcher.HasExited } -ReadReport {
        if(!(Test-Path -LiteralPath $watchFile)){return ''}
        $taskInfo=Get-Item -LiteralPath $watchFile
        if($taskInfo.Length -gt 4096){throw 'Watchdog report exceeded bound'}
        [IO.File]::ReadAllText($watchFile)
    }
    & 'C:\SandboxGuard\local-batch-load-v70\launch-dt1-v70-net-v100\Activate-OsrsForLocalV4.ps1' -Run $Run
    if($LASTEXITCODE -ne 0){throw 'Network activation failed'}
    $state.Networking='OSRS-endpoint-restricted';$state.Phase='launching';Save-State
    Write-Host 'NETWORK POLICY READY - direct outbound access is restricted to the reviewed OSRS endpoints.' -ForegroundColor Green
    $harness=Start-Process -FilePath (Join-Path $work 'GameLoadTestOverlayV2.exe') -ArgumentList '--local-connected-test' -WorkingDirectory $work -NoNewWindow -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $coreStartedUtc=$harness.StartTime.ToUniversalTime();$state.HarnessId=$harness.Id;$state.HarnessStartTicks=$harness.StartTime.ToUniversalTime().Ticks;$state.Phase='running';Save-State
    $stream=[IO.File]::Open($stdout,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    $reader=[IO.StreamReader]::new($stream)
    while(!$harness.HasExited){
        while(!$reader.EndOfStream){
            $line=$reader.ReadLine();Write-Host $line
            if(Update-PluginListLaunchGate $listGate $line){
                $game=Get-Process -Id $listGate.ChildId
                $identity=if($env:PEXORA_LOCAL_RUNTIME -eq '1'){$null}else{Get-CimInstance Win32_Process -Filter ('ProcessId='+$game.Id)}
                if($game.Path -ne (Join-Path $work 'osclient.exe') -or ($env:PEXORA_LOCAL_RUNTIME -ne '1' -and $identity.ParentProcessId -ne $harness.Id)){throw 'Local list target is not this harness child'}
                $state.GameProcessId=$game.Id;$state.GameStartTicks=$game.StartTime.ToUniversalTime().Ticks;$state.PluginList='attaching';Save-State
                Write-Host 'Registering Mike in the native plugin list; Start is not requested.'
                $listStartedUtc=[DateTime]::UtcNow;$listWorker=Start-Process -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ArgumentList @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File','C:\SandboxGuard\local-batch-load-v70\launch-dt1-v70-net-v100\Attach-LocalPluginListV39.ps1','-Tag',$Run,'-ExpectedProcessId',$game.Id,'-ExpectedStartTicks',$game.StartTime.ToUniversalTime().Ticks) -WindowStyle Hidden -PassThru
            }
        }
        if($listWorker -and !$listReported){
            $listWorker.Refresh()
            if($listWorker.HasExited){
                $listReported=$true;$listResultPath=Join-Path $case ('local-list-attach-'+$Run+'.json')
                $listPassed=$false
                if(Test-Path -LiteralPath $listResultPath){$listResult=Get-Content -LiteralPath $listResultPath -Raw|ConvertFrom-Json;$listPassed=$listResult.Passed -and $listResult.ProcessId -eq $listGate.ChildId}
                if($listWorker.ExitCode -eq 0 -and $listPassed){$state.PluginList='registered-stopped';Write-Host 'LOCAL_PLUGIN_LIST_READY=true; START_REQUESTED=false - reopen Plugins and search Mike.' -ForegroundColor Green}
                else{$state.PluginList='failed-no-retry';throw 'Mike list registration failed; batch not attached'}
                Save-State
            }
        }
        if($state.PluginList -eq 'registered-stopped' -and !$batchWorker -and !$batchReported){
            $game=Get-Process -Id $state.GameProcessId
            if($game.Path -ne (Join-Path $work 'osclient.exe') -or $game.StartTime.ToUniversalTime().Ticks -ne $state.GameStartTicks){throw 'Batch target changed'}
            $state.BatchPlugins='attaching';Save-State;$batchStartedUtc=[DateTime]::UtcNow
            Write-Host 'Registering Allure, Inferno, Fight Caves and Colosseum; all remain stopped.'
            $batchWorker=Start-Process -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ArgumentList @('-NoProfile','-NonInteractive','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File','C:\SandboxGuard\local-batch-load-v70\launch-dt1-v70-net-v100\Attach-LocalBatchLoadV70.ps1','-Run',$Run,'-ExpectedProcessId',$game.Id,'-ExpectedStartTicks',$state.GameStartTicks) -WindowStyle Hidden -PassThru
        }
        if($batchWorker -and !$batchReported){
            $batchWorker.Refresh()
            if($batchWorker.HasExited){
                $batchReported=$true
                $batchResultPath='C:\CanaryLogs\plugin-batch-20260906-v1\local-batch-attach-v70-'+$Run+'.json'
                if(!(Test-Path -LiteralPath $batchResultPath)){throw 'Batch helper produced no final report'}
                $batchResult=Get-Content -LiteralPath $batchResultPath -Raw|ConvertFrom-Json
                if($batchWorker.ExitCode -ne 0 -or !$batchResult.Passed -or $batchResult.ProcessId -ne $state.GameProcessId -or $batchResult.ProcessStartTicks -ne $state.GameStartTicks){$state.BatchPlugins='failed-no-retry';throw 'Four-plugin registration or cleanup failed; test closed without retry'}
                $state.BatchPlugins='registered-stopped';Save-State
                Write-Host 'LOCAL_BATCH_READY=true; PLUGINS=Mike,Allure,Inferno,FightCaves,Colosseum; START_REQUESTED=false' -ForegroundColor Green
            }elseif(([DateTime]::UtcNow-$batchStartedUtc).TotalSeconds -gt 300){throw 'Batch helper deadline reached; no repeat attachment'}
        }
        $phaseFailure=Get-StartupPhaseFailureV35 -ListStarted ([bool]$listWorker) -ListReported $listReported -BatchStarted ([bool]$batchWorker) -BatchReported $batchReported -CoreSeconds (([DateTime]::UtcNow-$coreStartedUtc).TotalSeconds) -ListSeconds $(if($listStartedUtc){([DateTime]::UtcNow-$listStartedUtc).TotalSeconds}else{0})
        if($phaseFailure){throw $phaseFailure}
        Start-Sleep -Milliseconds 150;$harness.Refresh()
    }
    while(!$reader.EndOfStream){Write-Host $reader.ReadLine()}
    $state.Phase='exited';Write-Host ('Local harness exit code: '+$harness.ExitCode)
}catch{$state.Error=$_.Exception.Message;$state.Phase='failed';Write-Host ('LOCAL TEST ERROR: '+$state.Error) -ForegroundColor Red}
finally{
    try{
        & 'C:\CanaryTools\NextPluginsV1\Restore-OsrsForLocalV4.ps1' -Run $Run
        if($LASTEXITCODE -ne 0){throw 'Network restoration failed'}
        $state.Networking='blocked'
        Write-Host 'Local test networking restored to block-all.'
    }catch{$state.Networking='RESTORATION_ERROR';Write-Host 'Network restoration needs checking; watchdog remains active.' -ForegroundColor Red}
    if($harness -and !$harness.HasExited){Stop-Process -InputObject $harness}
    if($reader){$reader.Dispose()}
    $state.Finished=$true;Save-State;$mutex.ReleaseMutex();$mutex.Dispose()
}
if($state.Error){exit 2}
