$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSCommandPath
$runtime=Join-Path $root 'portable-dt1\runtime\RuntimeSession-v113'
$base=Get-Content -Raw (Join-Path $runtime 'local-batch-load-v70\pexora-local-runtime-manifest.json')|ConvertFrom-Json
foreach($item in @($base.artifacts)+@($base.plugins)){
    $path=Join-Path $runtime ([string]$item.path)
    if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw ('Missing base artifact: '+$item.path)}
    if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $item.sha256){throw ('Base hash mismatch: '+$item.path)}
}
$ext=Get-Content -Raw (Join-Path $runtime 'dt1-plugin-extensions-v9\manifest.json')|ConvertFrom-Json
if((Get-FileHash -LiteralPath (Join-Path $runtime $ext.baseManifest)).Hash -ne $ext.baseManifestSHA256){throw 'Extension base-manifest mismatch'}
foreach($item in $ext.artifacts){
    $path=Join-Path $runtime ([string]$item.path)
    if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw ('Missing extension artifact: '+$item.path)}
    if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $item.sha256){throw ('Extension hash mismatch: '+$item.path)}
}
$settings=Get-Content -Raw (Join-Path $runtime 'first-game-v1\profile\.detuksosrs\settings.properties')
if($settings -match '(?im)^(breakhandler\.(username|password)|autobankpin\.pin|rsprofile\.loginSalt)='){throw 'Private profile setting detected'}
$privateFiles=@(Get-ChildItem -LiteralPath (Join-Path $runtime 'first-game-v1\profile') -Recurse -Force -File|Where-Object {$_.Name -match '(?i)(\.uid$|preferences_totp|LootTracker\.db|OpOrder\.json|CrashLogDump|auth\.dpapi|cookie|session)'} )
if($privateFiles.Count){throw ('Private profile file detected: '+$privateFiles[0].FullName)}
foreach($script in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.ps1'){
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($script.FullName,[ref]$tokens,[ref]$errors)
    if($errors.Count){throw ('PowerShell parse error: '+$script.FullName+' '+$errors[0].Message)}
}
Write-Output 'PORTABLE_DT1_VALID=true;PRIVATE_PROFILE_STATE=false;PLUGIN_START_REQUESTED=false'
