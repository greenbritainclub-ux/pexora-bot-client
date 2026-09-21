Set-StrictMode -Version Latest

function Read-BoundedLocalTextV7 {
 param([Parameter(Mandatory=$true)][string]$Path,[ValidateRange(1,1048576)][int]$MaximumBytes=262144)
 $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
 try {
  if($stream.Length -gt $MaximumBytes){throw 'Report input exceeds byte bound'}
  # Read at most the bound plus one byte, including files that grow during the read.
  $bytes=[byte[]]::new($MaximumBytes+1);$count=0
  while($count -lt $bytes.Length){$n=$stream.Read($bytes,$count,$bytes.Length-$count);if($n -eq 0){break};$count+=$n}
  if($count -gt $MaximumBytes){throw 'Report input grew beyond byte bound'}
  return [Text.UTF8Encoding]::new($false,$true).GetString($bytes,0,$count).TrimStart([char]0xFEFF)
 } finally {$stream.Dispose()}
}

function ConvertTo-BoundedLocalJsonV7 {
 param([Parameter(Mandatory=$true)][Collections.IDictionary]$Report,[ValidateRange(1024,1048576)][int]$MaximumBytes=262144)
 $budget=@{Nodes=0;Chars=0}
 function Copy-ScalarTreeV7($Value,[int]$Depth) {
  $budget.Nodes++
  if($Depth -gt 6 -or $budget.Nodes -gt 4096){throw 'Report structure bound'}
  if($null -eq $Value){return $null}
  if($Value -is [string]){
   $budget.Chars+=$Value.Length
   if($budget.Chars -gt $MaximumBytes){throw 'Report string bound'}
   # New System.String deliberately drops Get-Content's provider note properties.
   return [string]::new($Value.ToCharArray())
  }
  if($Value -is [bool]){return [bool]$Value}
  if($Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64]){return [long]$Value}
  if($Value -is [Collections.IDictionary]){
   $copy=[ordered]@{}
   foreach($key in $Value.Keys){
    if($key -isnot [string] -or $key.Length -gt 128 -or $key -notmatch '^[A-Za-z][A-Za-z0-9_]*$'){throw 'Report key refused'}
    $copy[[string]::new($key.ToCharArray())]=Copy-ScalarTreeV7 $Value[$key] ($Depth+1)
   }
   return $copy
  }
  if($Value -is [array]){
   if($Value.Length -gt 1024){throw 'Report array bound'}
   $copy=[object[]]::new($Value.Length)
   for($i=0;$i -lt $Value.Length;$i++){$copy[$i]=Copy-ScalarTreeV7 $Value[$i] ($Depth+1)}
   return ,$copy
  }
  throw 'Only explicit scalar dictionaries and arrays may be serialized'
 }
 $clean=Copy-ScalarTreeV7 $Report 0
 $json=ConvertTo-Json -InputObject $clean -Depth 8 -Compress
 if([Text.Encoding]::UTF8.GetByteCount($json) -gt $MaximumBytes){throw 'Report output byte bound'}
 return $json
}

function Write-BoundedLocalReportV7 {
 param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][Collections.IDictionary]$Report)
 $json=ConvertTo-BoundedLocalJsonV7 -Report $Report
 [IO.File]::WriteAllText($Path,$json,[Text.UTF8Encoding]::new($false))
}
