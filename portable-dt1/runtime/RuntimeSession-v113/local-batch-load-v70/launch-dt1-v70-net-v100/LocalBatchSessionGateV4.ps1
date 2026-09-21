# Pure session-evidence validation; no process access or mutation.
function Assert-LocalBatchSessionV4 {
 param([string]$Run,[int]$ExpectedProcessId,[long]$ExpectedStartTicks,$State,$Game,$Harness,$Supervisor,[int]$ParentId)
 if($Run -cnotmatch '^connected-v4-[0-9-]+$' -or $ExpectedProcessId -lt 1 -or $ExpectedStartTicks -lt 1){throw 'Invalid session request'}
 if($State.Run -cne $Run -or $State.Finished -or $State.Phase -cne 'running' -or $State.PluginList -cne 'registered-stopped' -or $State.BatchPlugins -cne 'attaching'){throw 'Supervisor not ready for one batch attachment'}
 if($Game.Path -ine 'C:\SandboxGuard\first-game-v1\osclient.exe' -or $Game.Id -ne $ExpectedProcessId -or $Game.StartTicks -ne $ExpectedStartTicks -or !$Game.Responding -or $State.GameProcessId -ne $Game.Id -or $State.GameStartTicks -ne $Game.StartTicks){throw 'Local game session identity mismatch'}
 # Guest CIM parent lookup is unavailable in this Sandbox.  Local validation
 # therefore passes a null/zero parent, but a non-zero conflicting parent must
 # still be rejected so the fixture cannot silently accept the wrong process.
 $parentMismatch=if($env:PEXORA_LOCAL_RUNTIME -eq '1'){($ParentId -notin @($null,0,$Harness.Id))}else{$ParentId -ne $Harness.Id}
 if($Harness.Path -ine 'C:\SandboxGuard\first-game-v1\GameLoadTestOverlayV2.exe' -or $Harness.Id -ne $State.HarnessId -or $Harness.StartTicks -ne $State.HarnessStartTicks -or $parentMismatch){throw 'Local harness ownership mismatch'}
 if($Supervisor.Path -ine 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -or $Supervisor.Id -ne $State.SupervisorId -or $Supervisor.StartTicks -ne $State.SupervisorStartTicks){throw 'Local supervisor identity mismatch'}
 if($Supervisor.StartTicks -gt $Harness.StartTicks -or $Harness.StartTicks -gt $Game.StartTicks){throw 'Invalid process creation ordering'}
}
