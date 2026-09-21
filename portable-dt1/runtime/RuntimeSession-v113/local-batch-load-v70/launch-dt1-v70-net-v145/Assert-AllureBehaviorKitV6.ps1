$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
function Assert-AllureBehaviorKitV6 {
 $taskWork='C:\SandboxGuard\local-batch-load-v70';$taskCase='C:\SandboxLocalLogs132\plugin-batch-20260906-v1'
 $taskPins=@{
  'allure-dt1-launch-v70-net-v145\manifest.json'='32FCAC4F22F2AC07461081189561E08C920A00FAC24888DAF52845B8CAB5ECEE'
  'allure-local-launch-v70\build-result.json'='D73B4808BF45FF9886CA0BB7239E5C5936E37B39A4A26683B3C1230EE607DD9D'
  'local-batch-deployment-v70.json'='B0A2F81079D284457FADB5E80B989A237C0F59F7C3022BAA24FEFE362AAE7655'
  'launch-v145\osrs-endpoint-manifest-v4.json'='1C721EA64DA352430CF69DAC474AD989A55C149AD859E17DD18AECC2422A8756'
 }
 foreach($name in $taskPins.Keys){if((Get-FileHash -LiteralPath (Join-Path $taskCase $name) -Algorithm SHA256).Hash -ne $taskPins[$name]){throw ('Manifest changed: '+$name)}}
 $taskBase=Get-Content -LiteralPath (Join-Path $taskCase 'allure-local-launch-v70\build-result.json') -Raw|ConvertFrom-Json
 $taskCurrent=Get-Content -LiteralPath (Join-Path $taskCase 'allure-dt1-launch-v70-net-v145\manifest.json') -Raw|ConvertFrom-Json
 if(!$taskBase.Passed -or !$taskCurrent.Passed){throw 'Launch kit did not pass'}
 foreach($f in $taskBase.Files){if((Get-FileHash -LiteralPath (Join-Path $taskWork $f.Relative) -Algorithm SHA256).Hash -ne $f.SHA256){throw 'V6 base artifact changed'}}
 foreach($f in $taskCurrent.Files){if((Get-FileHash -LiteralPath (Join-Path ($taskWork+'\launch-dt1-v70-net-v145') $f.Name) -Algorithm SHA256).Hash -ne $f.SHA256){throw 'Current launch script changed'}}
 if((Get-FileHash -LiteralPath 'C:\SandboxGuard\first-game-v1\GameLoadTestOverlayV2.exe' -Algorithm SHA256).Hash -ne $taskCurrent.HarnessSHA256){throw 'Overlay harness changed'}
 $taskDeploy=Get-Content -LiteralPath (Join-Path $taskCase 'local-batch-deployment-v70.json') -Raw|ConvertFrom-Json
 if($taskDeploy.Plugins.Count -ne 4){throw 'Plugin scope changed'}
 foreach($p in $taskDeploy.Plugins){if((Get-FileHash -LiteralPath $p.Jar -Algorithm SHA256).Hash -ne $p.Hash){throw 'Staged plugin changed'}}
 $taskNet=Get-Content -LiteralPath (Join-Path $taskCase 'launch-v145\osrs-network-verification-v4.json') -Raw|ConvertFrom-Json
 $taskEndpoints=Get-Content -LiteralPath (Join-Path $taskCase 'launch-v145\osrs-endpoint-manifest-v4.json') -Raw|ConvertFrom-Json
 if(!$taskNet.Passed -or !$taskNet.Restored -or !$taskNet.OtherRulesUnchanged -or $taskNet.EndpointManifestSHA256 -ne $taskCurrent.EndpointSHA256 -or [DateTime]::UtcNow.AddMinutes(10) -ge [DateTime]::Parse($taskEndpoints.ExpiresUtc)){throw 'Fresh network approval required'}
 $taskRuntime='C:\SandboxLocalLogs132\first-launch-20260906-v1\local-test-kit-v1\manifest.json'
 if((Get-FileHash -LiteralPath $taskRuntime -Algorithm SHA256).Hash -ne 'C61205321E0DF60C3C32E64C3C62CFDE1BDA38CC1A3CD64B78DA16AA202361A4'){throw 'Runtime manifest changed'}
 foreach($f in (Get-Content -LiteralPath $taskRuntime -Raw|ConvertFrom-Json).Files){if((Get-FileHash -LiteralPath (Join-Path 'C:\SandboxGuard\first-game-v1' $f.RelativePath) -Algorithm SHA256).Hash -ne $f.SHA256){throw 'Runtime changed'}}
}
