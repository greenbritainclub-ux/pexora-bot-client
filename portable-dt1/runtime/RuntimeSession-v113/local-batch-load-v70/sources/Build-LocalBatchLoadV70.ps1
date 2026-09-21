$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only'}
$case='C:\CanaryLogs\plugin-batch-20260906-v1';$work='C:\SandboxGuard\local-batch-load-v70';$report=Join-Path $case 'local-batch-build-v70.json'
if(Test-Path -LiteralPath $report){throw 'Preserve prior build'}
$r=[ordered]@{Passed=$false;Files=@();Error=$null}
try{
 foreach($name in @('LocalBatchLoadV70.java','LocalBatchLoadV70.cpp','LocalBatchInjectorV70.cpp')){if(Test-Path -LiteralPath (Join-Path $work $name)){throw 'Existing source copy'};Copy-Item -LiteralPath ('C:\SandboxGuard\local-batch-load-v70\sources\'+$name) -Destination $work}
 $native=[IO.File]::ReadAllText((Join-Path $work 'LocalBatchLoadV70.cpp'));$injector=[IO.File]::ReadAllText((Join-Path $work 'LocalBatchInjectorV70.cpp'))
 if(!$native.Contains('local-batch-load-v70-native-') -or $native.Contains('local-plugin-native-') -or !$injector.Contains('local-batch-load-v70') -or $injector.Contains('LocalOverlayOrientationV1.dll')){throw 'Source scope regression'}
 Copy-Item -LiteralPath 'C:\CanaryLogs\resource-export-20260906-v3\helper-build\PexoraResourcePins.h' -Destination $work
 if((Get-FileHash -LiteralPath (Join-Path $work 'PexoraResourcePins.h') -Algorithm SHA256).Hash -ne 'F9EE999CB5FAC230E9F617EA0CB62F5E2949536029C14177D55D5216EB009D77'){throw 'Header pin'}
 $env:INCLUDE='C:\BuildJdk\include;C:\BuildJdk\include\win32;C:\BuildMsvc\include;C:\BuildSdk\Include\10.0.26100.0\ucrt;C:\BuildSdk\Include\10.0.26100.0\shared;C:\BuildSdk\Include\10.0.26100.0\um'
 $env:LIB='C:\BuildMsvc\lib\x64;C:\BuildSdk\Lib\10.0.26100.0\ucrt\x64;C:\BuildSdk\Lib\10.0.26100.0\um\x64'
 $env:PATH='C:\BuildMsvc\bin\Hostx64\x64;C:\Windows\System32;C:\Windows';$env:TEMP=$work;$env:TMP=$work
 Push-Location $work
 try{
  New-Item -ItemType Directory -Path classes|Out-Null
  & 'C:\BuildJdk\bin\javac.exe' --release 11 -d classes LocalBatchLoadV70.java *> (Join-Path $case 'local-batch-java-build-v70.log');if($LASTEXITCODE -ne 0){throw 'Java compile'}
  & 'C:\BuildJdk\bin\jar.exe' --create --file LocalBatchLoadV70.jar -C classes .;if($LASTEXITCODE -ne 0){throw 'Jar build'}
  & 'C:\BuildJdk\bin\java.exe' -cp LocalBatchLoadV70.jar ai.pexora.localboot.LocalBatchLoadV70 *> (Join-Path $case 'local-batch-java-fixture-v70.txt');if($LASTEXITCODE -ne 0){throw 'Java fixture'}
  & 'C:\BuildMsvc\bin\Hostx64\x64\cl.exe' /nologo /std:c++17 /W4 /O2 /MT /EHsc /LD LocalBatchLoadV70.cpp /Fe:LocalBatchLoadV70.dll *> (Join-Path $case 'local-batch-native-build-v70.log');if($LASTEXITCODE -ne 0){throw 'Native build'}
  & 'C:\BuildMsvc\bin\Hostx64\x64\cl.exe' /nologo /std:c++17 /W4 /O2 /MT /EHsc /DLOCAL_BATCH_FIXTURE LocalBatchLoadV70.cpp /Fe:LocalBatchFixtureV70.exe *> (Join-Path $case 'local-batch-native-fixture-build-v70.log');if($LASTEXITCODE -ne 0){throw 'Native fixture build'}
  & '.\LocalBatchFixtureV70.exe' *> (Join-Path $case 'local-batch-native-fixture-v70.txt');if($LASTEXITCODE -ne 0){throw 'Native fixture'}
  & 'C:\BuildMsvc\bin\Hostx64\x64\cl.exe' /nologo /std:c++17 /W4 /O2 /MT /EHsc LocalBatchInjectorV70.cpp /Fe:LocalBatchInjectorV70.exe /link Advapi32.lib *> (Join-Path $case 'local-batch-injector-build-v70.log');if($LASTEXITCODE -ne 0){throw 'Injector build'}
  & '.\LocalBatchInjectorV70.exe' --fixture *> (Join-Path $case 'local-batch-injector-fixture-v70.txt');if($LASTEXITCODE -ne 0){throw 'Injector fixture'}
 }finally{Pop-Location}
 foreach($n in @('LocalBatchLoadV70.java','LocalBatchLoadV70.cpp','LocalBatchInjectorV70.cpp','LocalBatchLoadV70.jar','LocalBatchLoadV70.dll','LocalBatchFixtureV70.exe','LocalBatchInjectorV70.exe','PexoraResourcePins.h')){$r.Files+=@{Name=$n;SHA256=(Get-FileHash -LiteralPath (Join-Path $work $n) -Algorithm SHA256).Hash}}
 $r.Passed=$true
}catch{$r.Error=$_.Exception.Message}
$r|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $report -Encoding UTF8
if(!$r.Passed){exit 2}
