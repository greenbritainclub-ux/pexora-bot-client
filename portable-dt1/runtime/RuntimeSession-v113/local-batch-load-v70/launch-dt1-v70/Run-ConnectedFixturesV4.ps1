param([Parameter(Mandatory=$true)][ValidatePattern('^connected-v4-[0-9-]+$')][string]$Run)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
$case='C:\CanaryLogs\first-launch-20260906-v1';$work='C:\SandboxGuard\first-game-v1'
if((Get-FileHash -LiteralPath (Join-Path $case 'local-test-kit-v1\manifest.json') -Algorithm SHA256).Hash -ne 'C61205321E0DF60C3C32E64C3C62CFDE1BDA38CC1A3CD64B78DA16AA202361A4'){throw 'Runtime kit manifest pin'}
if((Get-FileHash -LiteralPath (Join-Path $case 'connected-build-v2.json') -Algorithm SHA256).Hash -ne '61B373EE90DF78FF307F8A77F0BCB35412E2A0ECB1C485004F0818A4EB42C0E5'){throw 'Connected build manifest pin'}
$manifest=Get-Content -LiteralPath (Join-Path $case 'local-test-kit-v1\manifest.json') -Raw|ConvertFrom-Json
foreach($f in $manifest.Files){if((Get-FileHash -LiteralPath (Join-Path $work $f.RelativePath) -Algorithm SHA256).Hash -ne $f.SHA256){throw 'Existing runtime kit changed'}}
$build=Get-Content -LiteralPath (Join-Path $case 'connected-build-v2.json') -Raw|ConvertFrom-Json
if(!$build.Passed){throw 'Build did not pass'}
foreach($f in $build.Files){if((Get-FileHash -LiteralPath (Join-Path $work $f.Name) -Algorithm SHA256).Hash -ne $f.SHA256){throw 'V2 artifact changed'}}
if((Get-FileHash -LiteralPath 'C:\SandboxGuard\first-game-v1\GameLoadTestOverlayV2.exe' -Algorithm SHA256).Hash -ne 'CE453CBB4BFD55B76B2525FE42D08649B8E107E3764F9E2DEE120A42DC959396'){throw 'Overlay harness changed'}
$r=[ordered]@{TimestampUtc=[DateTime]::UtcNow.ToString('o');RuntimeHashesPassed=$true;Fixtures=@();Passed=$false}
foreach($spec in @(@('logging','GameLoadTestOverlayV2.exe','--logging-fixture'),@('startup','GameLoadTestOverlayV2.exe','--startup-fixture'),@('harness','GameLoadTestOverlayV2.exe','--fixture'),@('bootstrap','LocalBootstrapFixture.exe',''),@('plugin','LocalPluginFixture.exe',''))){
    $output=Join-Path $case ($Run+'-'+$spec[0]+'-fixture.txt')
    if($spec[2]){& (Join-Path $work $spec[1]) $spec[2] *> $output}else{& (Join-Path $work $spec[1]) *> $output}
    $r.Fixtures+=@{Name=$spec[0];ExitCode=$LASTEXITCODE}
    if($LASTEXITCODE -ne 0){break}
}
$r.Passed=$r.Fixtures.Count -eq 5 -and @($r.Fixtures|Where-Object ExitCode -ne 0).Count -eq 0
$r|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $case ($Run+'-runtime-fixtures.json')) -Encoding UTF8
if(!$r.Passed){exit 2}
