param([switch]$ValidateOnly,[ValidatePattern('^connected-v4-[0-9-]+$')][string]$Run)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$runtimeRoot=Split-Path -Parent $PSScriptRoot
$result=[ordered]@{StartedUtc=[DateTime]::UtcNow.ToString('o');CompletedUtc=$null;Passed=$false;Run=$null;GamePid=0;GameStartTicks=0L;Action=$null;PluginStartRequested=$false;Error=$null}
$mutex=$null;$held=$false
function Resolve-Artifact([string]$relative){
 if([IO.Path]::IsPathRooted($relative)){throw 'Relative extension path required'}
 $full=[IO.Path]::GetFullPath((Join-Path $runtimeRoot $relative))
 if(!$full.StartsWith($runtimeRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Extension path escapes runtime'}
 if(!(Test-Path -LiteralPath $full -PathType Leaf)){throw ('Missing extension artifact: '+$relative)}
 return $full
}
try{
 $manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw|ConvertFrom-Json
 if($manifest.schema -ne 'pexora-dt1-plugin-extensions-v9' -or $manifest.track -ne 'first-isolated-v113-dt1-v70'){throw 'Extension identity'}
 if((Get-FileHash -LiteralPath (Resolve-Artifact $manifest.baseManifest)).Hash -ne $manifest.baseManifestSHA256){throw 'Original DT1 manifest pin'}
 foreach($artifact in $manifest.artifacts){if((Get-FileHash -LiteralPath (Resolve-Artifact $artifact.path)).Hash -ne $artifact.sha256){throw ('Extension pin: '+$artifact.path)}}
 if(@($manifest.plugins).Count -ne 1){throw 'Expected one supported extension'}
 $plugin=$manifest.plugins[0]
 if($plugin.slug -ne 'detuks-delve' -or $plugin.candidate -ne 'v44' -or $plugin.helper -ne 'v55' -or $plugin.defaultEnabled -or $plugin.pluginStartRequested -or !$plugin.fixturesPassed){throw 'V43/V55 stopped-test contract'}
 if(@($manifest.artifacts|Where-Object path -CEQ $plugin.dispatcher).Count -ne 1){throw 'Dispatcher is not pinned'}
 $dispatcher=Resolve-Artifact $plugin.dispatcher
 if($ValidateOnly){& $dispatcher -ValidateOnly;Write-Output 'DT1_EXTENSION_MANIFEST_VALID=true;candidate=v44;helper=v55;startRequested=false';return}
 if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest execution only'}
 $mutex=[Threading.Mutex]::new($false,'Local\PexoraDt1PluginExtensionsV1')
 try{$held=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$held=$true}
 if(!$held){throw 'An extension test is already running'}
 if(!$Run){throw 'Explicit DT1 run required for either account mode'}
 & $dispatcher -Run $Run
 $receipt=Get-Content -LiteralPath 'C:\CanaryLogs\delve-dt1-v1\delve-test-v55-dispatch.json' -Raw|ConvertFrom-Json
 if(!$receipt.Passed -or $receipt.Run -cne $Run -or [DateTime]::Parse($receipt.StartedUtc) -lt [DateTime]::Parse($result.StartedUtc)){throw 'No fresh successful V55 receipt'}
 $result.Run=$receipt.Run;$result.GamePid=$receipt.GamePid;$result.GameStartTicks=$receipt.GameStartTicks;$result.Action=$receipt.Action;$result['SettingsInitialized']=$receipt.SettingsInitialized;$result.Passed=$true
}catch{$result.Error=$_.Exception.Message}finally{
 if($held){$mutex.ReleaseMutex()};if($mutex){$mutex.Dispose()}
 if(!$ValidateOnly -and $env:USERNAME -eq 'WDAGUtilityAccount'){
  [IO.Directory]::CreateDirectory('C:\CanaryLogs\delve-dt1-v1')|Out-Null
  $result.CompletedUtc=[DateTime]::UtcNow.ToString('o')
  $result|ConvertTo-Json -Depth 5|Set-Content -LiteralPath 'C:\CanaryLogs\delve-dt1-v1\dt1-plugin-extensions-v9.json' -Encoding UTF8
 }
}
if($result.Error){throw $result.Error}

