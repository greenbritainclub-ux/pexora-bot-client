Set-StrictMode -Version Latest

function Get-ClientUiEvidenceV9 {
 param([Parameter(Mandatory=$true)][string]$LiveText,[AllowEmptyString()][string]$ClientText='', [Parameter(Mandatory=$true)][datetime]$StartedLocal)
 if($LiveText.Length -gt 1048576 -or $ClientText.Length -gt 1048576){throw 'UI evidence text bound'}
 $attached=$LiveText -match '(?m)^DIAGNOSTIC\[CHILD_NATIVE_JVM\]=MILESTONE=Client window attached\r?$'
 $resized=$LiveText -match '(?m)^DIAGNOSTIC\[CHILD_NATIVE_JVM\]=MILESTONE=Client window resized\r?$'
 $active=$false;$headless=$false;$startupFailed=$false
 foreach($line in ($ClientText -split '\r?\n')){
  if($line -match '^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d{3}) '){
   $stamp=[DateTime]::ParseExact($Matches[1],'yyyy-MM-dd HH:mm:ss.fff',[Globalization.CultureInfo]::InvariantCulture)
   $active=$stamp -ge $StartedLocal
  }
  if(!$active){continue}
  if($line -match 'java\.awt\.HeadlessException'){$headless=$true}
  if($line -match '\bERROR\s+c\.d\.c\.w\s+-\s+Error during startup'){$startupFailed=$true}
 }
 return @{WindowAttached=[bool]$attached;WindowResized=[bool]$resized;HeadlessException=[bool]$headless;StartupFailed=[bool]$startupFailed;Passed=[bool]($attached -and $resized -and !$headless -and !$startupFailed)}
}

function Read-ClientUiLogV9 {
 param([Parameter(Mandatory=$true)][string]$Path)
 if(!(Test-Path -LiteralPath $Path)){return ''}
 $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
 try {
  # Strict finite snapshot, including when another process appends to the file.
  $length=$stream.Length;$count=[int][Math]::Min(1048576L,$length)
  [void]$stream.Seek($length-$count,[IO.SeekOrigin]::Begin)
  $bytes=[byte[]]::new($count);$read=0
  while($read -lt $count){$n=$stream.Read($bytes,$read,$count-$read);if($n -eq 0){break};$read+=$n}
  return [Text.Encoding]::UTF8.GetString($bytes,0,$read)
 }finally{$stream.Dispose()}
}
