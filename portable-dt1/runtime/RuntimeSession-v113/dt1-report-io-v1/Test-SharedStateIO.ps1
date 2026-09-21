param([string]$FixtureRoot=$env:TEMP)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'SharedStateIO.ps1')
$fixture=Join-Path $FixtureRoot ('pexora-state-io-fixture-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($fixture)|Out-Null
$path=Join-Path $fixture 'state.json'
$checks=0
try {
    $state=[ordered]@{Run='fixture';Phase='running';Finished=$false;Message=('x'*1024)}
    Write-Dt1SharedStateV1 -Path $path -State $state
    if((Get-Content -LiteralPath $path -Raw|ConvertFrom-Json).Message.Length -ne 1024){throw 'Initial round trip'};$checks++
    $state.Message='short'
    $reader=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    try {Write-Dt1SharedStateV1 -Path $path -State $state} finally {$reader.Dispose()}
    if((Get-Content -LiteralPath $path -Raw|ConvertFrom-Json).Message -ne 'short'){throw 'Shared reader / truncation'};$checks++
    $held=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $worker=[PowerShell]::Create()
    try {
        [void]$worker.AddScript({param($handle) Start-Sleep -Milliseconds 300;$handle.Dispose()}).AddArgument($held)
        $pending=$worker.BeginInvoke()
        $state.Phase='ready'
        Write-Dt1SharedStateV1 -Path $path -State $state
        $worker.EndInvoke($pending)|Out-Null
        if((Get-Content -LiteralPath $path -Raw|ConvertFrom-Json).Phase -ne 'ready'){throw 'Transient lock retry'};$checks++
    } finally {$held.Dispose();$worker.Dispose()}
    $before=[IO.File]::ReadAllText($path)
    $held=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $refused=$false
    try {try {Write-Dt1SharedStateV1 -Path $path -State @{Run='not-written'} -TimeoutMilliseconds 100}catch{$refused=$true}}finally{$held.Dispose()}
    if(!$refused -or [IO.File]::ReadAllText($path) -cne $before){throw 'Permanent lock must fail without truncation'};$checks++
    $refused=$false
    try {Write-Dt1SharedStateV1 -Path $path -State @{Message=('x'*70000)}}catch{$refused=$true}
    if(!$refused -or [IO.File]::ReadAllText($path) -cne $before){throw 'Oversize input must preserve report'};$checks++
    Write-Output ('DT1_SHARED_STATE_FIXTURES='+$checks+';RESULT=0')
} finally {
    # Only this newly-created, validated fixture directory is removed.
    $resolved=[IO.Path]::GetFullPath($fixture)
    $parent=[IO.Path]::GetFullPath($FixtureRoot).TrimEnd('\')+'\'
    if(!$resolved.StartsWith($parent,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notmatch '^pexora-state-io-fixture-[0-9a-f]{32}$'){throw 'Fixture cleanup path refused'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
