param([switch]$Fixture)
$ErrorActionPreference='Stop'
function Test-PluginReportName([string]$Name){return $Name -cmatch '^(local-plugin-[1-9][0-9]{0,9}|local-plugin-(?:native|list)-[1-9][0-9]{0,9})\.txt$'}
if($Fixture){
 foreach($name in @('local-plugin-8824.txt','local-plugin-8828.txt','local-plugin-1.txt','local-plugin-native-8824.txt','local-plugin-list-8824.txt')){if(!(Test-PluginReportName $name)){throw 'Positive filename fixture failed'}}
 foreach($name in @('..\local-plugin-8824.txt','local-plugin-8824.txt.bak','settings.properties','local-plugin-0.txt','LOCAL-plugin-1.txt')){if(Test-PluginReportName $name){throw 'Negative filename fixture failed'}}
 Write-Output 'REPORT_ARCHIVE_FIXTURES=9;PASSED=true';return
}
if(!(Test-Path -LiteralPath 'C:\PreparedRuntime\Resume-FirstIsolatedDt1.ps1')){throw 'Exact DT1 Sandbox required'}
if(Get-Process -Name osclient,GameLoadTestOverlayV2,GameLoadTestJagexV1 -ErrorAction SilentlyContinue){throw 'Cannot archive reports while a client or harness is active'}
$root=[IO.Path]::GetFullPath('C:\CanaryLogs\first-launch-20260906-v1')
$archive=Join-Path $root ('stale-plugin-reports-'+[Guid]::NewGuid().ToString('N'))
 $files=@(Get-ChildItem -LiteralPath $root -File|Where-Object {Test-PluginReportName $_.Name})
# The old Java helper uses CREATE_NEW and a PID-only filename. A reused PID
# otherwise throws before its own exception reporting and aborts readiness.
foreach($file in $files){
 if($file.Length -gt 65536 -or $file.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Diagnostic report bound or file type refused'}
 $source=[IO.Path]::GetFullPath($file.FullName)
 if([IO.Path]::GetDirectoryName($source) -cne $root){throw 'Diagnostic source escaped exact directory'}
 $reader=[IO.StreamReader]::new($source)
 try {$first=$reader.ReadLine()} finally {$reader.Dispose()}
 $acceptedSchemas=@('SCOPE=one-local-mikes-fishing-plugin;START_REQUESTED=false;SOURCE_CLIENT_ACCESSED=false','SCOPE=one-local-mikes-fishing-list;START_REQUESTED=false;SOURCE_CLIENT_ACCESSED=false','ATTACH_RESULT=0')
 if($acceptedSchemas -notcontains $first){throw 'Unexpected diagnostic report schema'}
}
if($files.Count){[IO.Directory]::CreateDirectory($archive)|Out-Null}
foreach($file in $files){
 $destination=[IO.Path]::GetFullPath((Join-Path $archive $file.Name))
 if([IO.Path]::GetDirectoryName($destination) -cne $archive -or !$archive.StartsWith($root+'\',[StringComparison]::Ordinal)){throw 'Diagnostic destination escaped exact archive'}
 Move-Item -LiteralPath $file.FullName -Destination $destination
}
Write-Output ('STALE_PLUGIN_REPORTS_ARCHIVED='+$files.Count)
