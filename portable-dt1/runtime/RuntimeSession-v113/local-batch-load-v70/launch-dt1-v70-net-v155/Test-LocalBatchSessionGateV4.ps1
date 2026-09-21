$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'LocalBatchSessionGateV4.ps1')
$state=@{Run='connected-v4-20260906-100000';Finished=$false;Phase='running';PluginList='registered-stopped';BatchPlugins='attaching';GameProcessId=300;GameStartTicks=3000L;HarnessId=200;HarnessStartTicks=2000L;SupervisorId=100;SupervisorStartTicks=1000L}
$game=@{Path='C:\SandboxGuard\first-game-v1\osclient.exe';Id=300;StartTicks=3000L;Responding=$true}
$harness=@{Path='C:\SandboxGuard\first-game-v1\GameLoadTestOverlayV2.exe';Id=200;StartTicks=2000L}
$supervisor=@{Path='C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe';Id=100;StartTicks=1000L}
$checks=0
Assert-LocalBatchSessionV4 $state.Run 300 3000 $state $game $harness $supervisor 200
$checks++
foreach($variant in @('original-game','stale-game','wrong-parent','old-harness','wrong-harness','stale-harness','stale-supervisor','ended','wrong-run','not-ready','duplicate-batch','unresponsive','wrong-order')){
 $s=$state.Clone();$g=$game.Clone();$h=$harness.Clone();$v=$supervisor.Clone();$parent=200
 switch($variant){
 'original-game'{$g.Path='C:\Users\WDAGUtilityAccount\AppData\Local\.dc\l\client\240.11\osclient.exe'}
 'stale-game'{$g.StartTicks=2999L}
 'old-harness'{$h.Path='C:\SandboxGuard\first-game-v1\GameLoadTestV2.exe'}
 'wrong-parent'{$parent=999}
 'wrong-harness'{$h.Path='C:\Windows\explorer.exe'}
 'stale-harness'{$h.StartTicks=1999L}
 'stale-supervisor'{$v.StartTicks=999L}
 'ended'{$s.Finished=$true}
 'wrong-run'{$s.Run='connected-v2-20260906-063340-369'}
 'not-ready'{$s.PluginList='attaching'}
 'duplicate-batch'{$s.BatchPlugins='registered-stopped'}
 'unresponsive'{$g.Responding=$false}
 'wrong-order'{$v.StartTicks=4000L;$s.SupervisorStartTicks=4000L}
 }
 $refused=$false;try{Assert-LocalBatchSessionV4 $state.Run 300 3000 $s $g $h $v $parent}catch{$refused=$true}
 if(!$refused){throw ('Session fixture accepted '+$variant)};$checks++
}
Write-Output ('LOCAL_BATCH_SESSION_FIXTURE=PASS checks='+$checks)
