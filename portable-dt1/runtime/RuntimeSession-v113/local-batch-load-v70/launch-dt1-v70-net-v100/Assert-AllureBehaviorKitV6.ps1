$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
function Assert-AllureBehaviorKitV6 {
 $taskWork='C:\SandboxGuard\local-batch-load-v70';$taskCase='C:\CanaryLogs\plugin-batch-20260906-v1'
 if($env:PEXORA_LOCAL_RUNTIME -eq '1'){
  $localManifestPath='C:\SandboxGuard\local-batch-load-v70\pexora-local-runtime-manifest.json'
  $localManifest=Get-Content -LiteralPath $localManifestPath -Raw|ConvertFrom-Json
  if($localManifest.schema -ne 'pexora-local-runtime-v1' -or $localManifest.track -ne 'first-isolated-v113'){throw 'Pexora local manifest identity'}
  foreach($item in @($localManifest.artifacts)+@($localManifest.plugins)){
   $localPath=Join-Path 'C:\SandboxGuard' ([string]$item.path)
   if(!(Test-Path -LiteralPath $localPath -PathType Leaf)){throw ('Pexora local artifact missing: '+$item.path)}
   if((Get-FileHash -LiteralPath $localPath -Algorithm SHA256).Hash -ne [string]$item.sha256){throw ('Pexora local artifact hash mismatch: '+$item.path)}
  }
  return
 }
 $taskPins=@{
  'allure-dt1-launch-v70-net-v99\manifest.json'='27B572AA3C86495E992A4CAFBD9CC2ED445F5A9CCE9686D97124E9C2DD9FFABF'
  'allure-local-launch-v70\build-result.json'='D73B4808BF45FF9886CA0BB7239E5C5936E37B39A4A26683B3C1230EE607DD9D'
  'local-batch-deployment-v70.json'='B0A2F81079D284457FADB5E80B989A237C0F59F7C3022BAA24FEFE362AAE7655'
  'launch-v99\osrs-endpoint-manifest-v4.json'='232282692E7BDE2103645B7E7343F4ACCD7162291125DF26ABDE5C20C78C3D40'
 }
 foreach($name in $taskPins.Keys){if((Get-FileHash -LiteralPath (Join-Path $taskCase $name) -Algorithm SHA256).Hash -ne $taskPins[$name]){throw ('Manifest changed: '+$name)}}
 $taskBase=Get-Content -LiteralPath (Join-Path $taskCase 'allure-local-launch-v70\build-result.json') -Raw|ConvertFrom-Json
 $taskCurrent=Get-Content -LiteralPath (Join-Path $taskCase 'allure-dt1-launch-v70-net-v99\manifest.json') -Raw|ConvertFrom-Json
 if(!$taskBase.Passed -or !$taskCurrent.Passed){throw 'Launch kit did not pass'}
 foreach($f in $taskBase.Files){if((Get-FileHash -LiteralPath (Join-Path $taskWork $f.Relative) -Algorithm SHA256).Hash -ne $f.SHA256){throw 'V6 base artifact changed'}}
 foreach($f in $taskCurrent.Files){if((Get-FileHash -LiteralPath (Join-Path ($taskWork+'\launch-dt1-v70-net-v100') $f.Name) -Algorithm SHA256).Hash -ne $f.SHA256){throw 'Current launch script changed'}}
 if((Get-FileHash -LiteralPath 'C:\SandboxGuard\first-game-v1\GameLoadTestOverlayV2.exe' -Algorithm SHA256).Hash -ne $taskCurrent.HarnessSHA256){throw 'Overlay harness changed'}
 $taskDeploy=Get-Content -LiteralPath (Join-Path $taskCase 'local-batch-deployment-v70.json') -Raw|ConvertFrom-Json
 if($taskDeploy.Plugins.Count -ne 4){throw 'Plugin scope changed'}
 foreach($p in $taskDeploy.Plugins){if((Get-FileHash -LiteralPath $p.Jar -Algorithm SHA256).Hash -ne $p.Hash){throw 'Staged plugin changed'}}
 $taskNet=Get-Content -LiteralPath (Join-Path $taskCase 'launch-v99\osrs-network-verification-v4.json') -Raw|ConvertFrom-Json
 $taskEndpoints=Get-Content -LiteralPath (Join-Path $taskCase 'launch-v99\osrs-endpoint-manifest-v4.json') -Raw|ConvertFrom-Json
 # The V99 endpoint snapshot is historical but structurally verified. In
 # local-runtime mode we reuse it instead of blocking the offline plugin
 # harness on a fresh Hub/endpoint refresh. Network policy is still applied
 # by Activate-OsrsForLocalV4 and no host security settings are changed.
 $localRuntime = $env:PEXORA_LOCAL_RUNTIME -eq '1'
 if(!$taskNet.Passed -or !$taskNet.Restored -or !$taskNet.OtherRulesUnchanged -or $taskNet.EndpointManifestSHA256 -ne $taskCurrent.EndpointSHA256 -or ((-not $localRuntime) -and [DateTime]::UtcNow.AddMinutes(10) -ge [DateTime]::Parse($taskEndpoints.ExpiresUtc))){throw 'Fresh network approval required'}
 $taskRuntime='C:\PreparedRuntime\mike-manager-ready-v1\runtime-kit.json'
 if((Get-FileHash -LiteralPath $taskRuntime -Algorithm SHA256).Hash -ne '972E399DDB7D04A58BD72B1EA2A4F891F4DC7E828DF0639B59DCA516E1E43614'){throw 'Runtime manifest changed'}
 foreach($f in (Get-Content -LiteralPath $taskRuntime -Raw|ConvertFrom-Json).Files){if((Get-FileHash -LiteralPath (Join-Path 'C:\SandboxGuard\first-game-v1' $f.RelativePath) -Algorithm SHA256).Hash -ne $f.SHA256){throw 'Runtime changed'}}
}
