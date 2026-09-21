$ErrorActionPreference='Stop'
if($PSCommandPath -ne 'C:\CanaryTools\Start-GpuSession.ps1' -or $env:USERNAME -ne 'WDAGUtilityAccount'){throw 'Guest only.'}
New-Item -ItemType Directory -Force -Path 'C:\CanaryLogs','C:\SandboxGuard' | Out-Null
[ordered]@{TimestampUtc=[DateTime]::UtcNow.ToString('o');Success=$true;SecurityControlsChanged=$false;AccountStateUsed=$false}|ConvertTo-Json|Set-Content -LiteralPath 'C:\CanaryLogs\session-start.json' -Encoding UTF8
