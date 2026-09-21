$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
function Assert-AllureBehaviorKitV6 {
 $taskWork='C:\SandboxGuard\local-batch-load-v70';$taskCase='C:\CanaryLogs\plugin-batch-20260906-v1'
 $taskPins=@{
  'allure-dt1-launch-v70-net-v84\manifest.json'='5EF4C81BD20486FDFD94F445C2E476019E15DEDCAEFF2D2678A12A96EF16D78F'
  'allure-local-launch-v70\build-result.json'='D73B4808BF45FF9886CA0BB7239E5C5936E37B39A4A26683B3C1230EE607DD9D'
  'local-batch-deployment-v70.json'='B0A2F81079D284457FADB5E80B989A237C0F59F7C3022BAA24FEFE362AAE7655'
  'launch-v84\osrs-endpoint-manifest-v4.json'='BE71B864F493DE7C69E930015083B175C13AA76F9620455965F02EB18913CF41'
 }
 foreach($name in $taskPins.Keys){if((Get-FileHash -LiteralPath (Join-Path $taskCase $name) -Algorithm SHA256).Hash -ne $taskPins[$name]){throw ('Manifest changed: '+$name)}}
 $taskBase=Get-Content -LiteralPath (Join-Path $taskCase 'allure-local-launch-v70\build-result.json') -Raw|ConvertFrom-Json
 $taskCurrent=Get-Content -LiteralPath (Join-Path $taskCase 'allure-dt1-launch-v70-net-v84\manifest.json') -Raw|ConvertFrom-Json
 if(!$taskBase.Passed -or !$taskCurrent.Passed){throw 'Launch kit did not pass'}
 foreach($f in $taskBase.Files){if((Get-FileHash -LiteralPath (Join-Path $taskWork $f.Relative) -Algorithm SHA256).Hash -ne $f.SHA256){throw 'V6 base artifact changed'}}
 foreach($f in $taskCurrent.Files){if((Get-FileHash -LiteralPath (Join-Path ($taskWork+'\launch-dt1-v70-net-v84') $f.Name) -Algorithm SHA256).Hash -ne $f.SHA256){throw 'Current launch script changed'}}
 if((Get-FileHash -LiteralPath 'C:\SandboxGuard\first-game-v1\GameLoadTestOverlayV2.exe' -Algorithm SHA256).Hash -ne $taskCurrent.HarnessSHA256){throw 'Overlay harness changed'}
 $taskDeploy=Get-Content -LiteralPath (Join-Path $taskCase 'local-batch-deployment-v70.json') -Raw|ConvertFrom-Json
 if($taskDeploy.Plugins.Count -ne 4){throw 'Plugin scope changed'}
 foreach($p in $taskDeploy.Plugins){if((Get-FileHash -LiteralPath $p.Jar -Algorithm SHA256).Hash -ne $p.Hash){throw 'Staged plugin changed'}}
 $taskNet=Get-Content -LiteralPath (Join-Path $taskCase 'launch-v84\osrs-network-verification-v4.json') -Raw|ConvertFrom-Json
 $taskEndpoints=Get-Content -LiteralPath (Join-Path $taskCase 'launch-v84\osrs-endpoint-manifest-v4.json') -Raw|ConvertFrom-Json
 if(!$taskNet.Passed -or !$taskNet.Restored -or !$taskNet.OtherRulesUnchanged -or $taskNet.EndpointManifestSHA256 -ne $taskCurrent.EndpointSHA256 -or [DateTime]::UtcNow.AddMinutes(10) -ge [DateTime]::Parse($taskEndpoints.ExpiresUtc)){throw 'Fresh network approval required'}
 $taskRuntime='C:\CanaryLogs\first-launch-20260906-v1\local-test-kit-v1\manifest.json'
 if((Get-FileHash -LiteralPath $taskRuntime -Algorithm SHA256).Hash -ne 'C61205321E0DF60C3C32E64C3C62CFDE1BDA38CC1A3CD64B78DA16AA202361A4'){throw 'Runtime manifest changed'}
 foreach($f in (Get-Content -LiteralPath $taskRuntime -Raw|ConvertFrom-Json).Files){if((Get-FileHash -LiteralPath (Join-Path 'C:\SandboxGuard\first-game-v1' $f.RelativePath) -Algorithm SHA256).Hash -ne $f.SHA256){throw 'Runtime changed'}}
}
