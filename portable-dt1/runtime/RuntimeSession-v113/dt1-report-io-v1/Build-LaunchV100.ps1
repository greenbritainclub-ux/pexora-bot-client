$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$runtime=Split-Path -Parent $PSScriptRoot
$source=Join-Path $runtime 'local-batch-load-v70\launch-dt1-v70-net-v99'
$target=Join-Path $runtime 'local-batch-load-v70\launch-dt1-v70-net-v100'
if(Test-Path -LiteralPath $target){throw 'V100 already exists; do not overwrite a staged version'}
$inventory=@(Get-ChildItem -LiteralPath $source -File|ForEach-Object {@{Name=$_.Name;SHA256=(Get-FileHash -LiteralPath $_.FullName).Hash}})
Copy-Item -LiteralPath $source -Destination $target -Recurse
# Mechanical relocation of the original launcher scripts; all native/JAR artifacts are reused unchanged.
foreach($file in Get-ChildItem -LiteralPath $target -File -Filter '*.ps1'){
    $text=[IO.File]::ReadAllText($file.FullName)
    $text=$text.Replace('launch-dt1-v70-net-v99','launch-dt1-v70-net-v100')
    [IO.File]::WriteAllText($file.FullName,$text,[Text.UTF8Encoding]::new($false))
}
$supervisor=Join-Path $target 'Run-LocalBatchConsoleV70.ps1'
$text=[IO.File]::ReadAllText($supervisor)
$old='function Save-State {$state|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $statePath -Encoding UTF8}'
if($text.Split(@($old),[StringSplitOptions]::None).Count -ne 2){throw 'Expected one original Save-State'}
$new=". (Join-Path `$PSScriptRoot 'SharedStateIO.ps1')`r`nfunction Save-State {Write-Dt1SharedStateV1 -Path `$statePath -State `$state}"
[IO.File]::WriteAllText($supervisor,$text.Replace($old,$new),[Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'SharedStateIO.ps1') -Destination $target
# A reader may sample the single-write snapshot during replacement; never mistake partial JSON for client failure.
$starter=Join-Path $target 'Start-Dt1ResumeV70.ps1'
$text=[IO.File]::ReadAllText($starter)
$old='     $taskState=ConvertFrom-Json -InputObject $taskText'
if($text.Split(@($old),[StringSplitOptions]::None).Count -ne 2){throw 'Expected one state parse'}
$new='     try {$taskState=ConvertFrom-Json -InputObject $taskText} catch {Start-Sleep -Milliseconds 40;continue}'
[IO.File]::WriteAllText($starter,$text.Replace($old,$new),[Text.UTF8Encoding]::new($false))
foreach($item in $inventory){if((Get-FileHash -LiteralPath (Join-Path $source $item.Name)).Hash -ne $item.SHA256){throw 'Original V99 changed'}}
foreach($file in Get-ChildItem -LiteralPath $target -File -Filter '*.ps1'){
    $tokens=$null;$errors=$null
    [Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)|Out-Null
    if($errors.Count){throw ('Parse failed: '+$file.Name)}
}
$artifacts=@(Get-ChildItem -LiteralPath $target -File|ForEach-Object {@{Name=$_.Name;SHA256=(Get-FileHash -LiteralPath $_.FullName).Hash}})
[ordered]@{Schema='pexora-dt1-launcher-io-v100';BuiltUtc=[DateTime]::UtcNow.ToString('o');OriginalPreserved=$true;OriginalFiles=$inventory;Artifacts=$artifacts;RuntimeAndPluginsChanged=$false;LivePassed=$false}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $target 'launcher-io-manifest.json') -Encoding UTF8
Write-Output 'DT1_V100_STAGED=true;originalV99Unchanged=true'
