function Test-WatchdogReadyV34([string]$Text,[string]$Run) {
 if(!$Text -or $Text.Length -gt 4096){return $false}
 try{$taskR=ConvertFrom-Json -InputObject $Text -ErrorAction Stop}catch{return $false}
 foreach($taskName in @('Run','Ready','Finished','Error')){if(!$taskR -or !$taskR.PSObject.Properties[$taskName]){return $false}}
 return $taskR.Run -ceq $Run -and $taskR.Ready -is [bool] -and $taskR.Ready -and $taskR.Finished -is [bool] -and !$taskR.Finished -and $null -eq $taskR.Error
}
function Wait-WatchdogReadyV34 {
 param([scriptblock]$ReadReport,[scriptblock]$IsAlive,[string]$Run,[ValidateRange(1,30000)][int]$TimeoutMilliseconds=30000,[ValidateRange(1,250)][int]$PollMilliseconds=100)
 $taskClock=[Diagnostics.Stopwatch]::StartNew()
 do {
  if(!(& $IsAlive)){throw 'Cleanup watchdog exited before readiness'}
  $taskText=& $ReadReport
  if((Test-WatchdogReadyV34 -Text $taskText -Run $Run) -and (& $IsAlive)){return}
  if($taskClock.ElapsedMilliseconds -ge $TimeoutMilliseconds){break}
  Start-Sleep -Milliseconds ([Math]::Min($PollMilliseconds,[Math]::Max(1,$TimeoutMilliseconds-$taskClock.ElapsedMilliseconds)))
 }while($taskClock.ElapsedMilliseconds -lt $TimeoutMilliseconds)
 throw 'Cleanup watchdog readiness deadline reached'
}
