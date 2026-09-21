$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$runtime=Split-Path -Parent $PSScriptRoot
$target=Join-Path $runtime 'local-batch-load-v70\launch-dt1-v70-net-v100'
$original=Join-Path $runtime 'local-batch-load-v70\launch-dt1-v70-net-v99'
$manifest=Get-Content -LiteralPath (Join-Path $target 'launcher-io-manifest.json') -Raw|ConvertFrom-Json
if($manifest.Schema -cne 'pexora-dt1-launcher-io-v100' -or !$manifest.OriginalPreserved -or $manifest.RuntimeAndPluginsChanged){throw 'V100 manifest contract'}
foreach($entry in @($manifest.Artifacts)+@($manifest.OriginalFiles)){
    if($entry.Name -notmatch '^[A-Za-z0-9.-]+\.(ps1|json)$'){throw 'Launcher artifact name refused'}
}
foreach($entry in $manifest.Artifacts){if((Get-FileHash -LiteralPath (Join-Path $target $entry.Name)).Hash -ne $entry.SHA256){throw ('V100 launcher pin: '+$entry.Name)}}
foreach($entry in $manifest.OriginalFiles){if((Get-FileHash -LiteralPath (Join-Path $original $entry.Name)).Hash -ne $entry.SHA256){throw ('Original V99 pin changed: '+$entry.Name)}}
Write-Output 'DT1_V100_VALIDATED=true;originalV99Preserved=true'
