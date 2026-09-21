$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=Split-Path -Parent $PSCommandPath
$bundle=Join-Path $repo 'portable-dt1'
$logs=Join-Path $bundle 'logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$wsb=Join-Path $logs 'Pexora-Portable-DT1.wsb'
$xml=@"
<Configuration>
  <MemoryInMB>8192</MemoryInMB>
  <vGPU>Disable</vGPU>
  <Networking>Enable</Networking>
  <AudioInput>Disable</AudioInput>
  <VideoInput>Disable</VideoInput>
  <PrinterRedirection>Disable</PrinterRedirection>
  <ClipboardRedirection>Enable</ClipboardRedirection>
  <MappedFolders>
    <MappedFolder><HostFolder>$bundle\input\SandboxGuard</HostFolder><SandboxFolder>C:\CanaryTools</SandboxFolder><ReadOnly>true</ReadOnly></MappedFolder>
    <MappedFolder><HostFolder>$logs</HostFolder><SandboxFolder>C:\CanaryLogs</SandboxFolder><ReadOnly>false</ReadOnly></MappedFolder>
    <MappedFolder><HostFolder>$bundle\runtime\RuntimeSession-v113</HostFolder><SandboxFolder>C:\PreparedRuntime</SandboxFolder><ReadOnly>true</ReadOnly></MappedFolder>
    <MappedFolder><HostFolder>$bundle\runtime\BuildJdk</HostFolder><SandboxFolder>C:\BuildJdk</SandboxFolder><ReadOnly>true</ReadOnly></MappedFolder>
  </MappedFolders>
  <LogonCommand><Command>powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\CanaryTools\Start-PexoraFirstIsolatedBatch.ps1</Command></LogonCommand>
</Configuration>
"@
Set-Content -LiteralPath $wsb -Value $xml -Encoding UTF8
Start-Process -FilePath $wsb | Out-Null
Write-Output "Started portable DT1 Sandbox using $wsb"
