Set-StrictMode -Version Latest

function Write-Dt1SharedStateV1 {
    param([Parameter(Mandatory=$true)][string]$Path,
          [Parameter(Mandatory=$true)][Collections.IDictionary]$State,
          [ValidateRange(100,10000)][int]$TimeoutMilliseconds=4000)
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($State|ConvertTo-Json -Depth 4))
    if($bytes.Length -gt 65536){throw 'DT1 state exceeds 64 KiB bound'}
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while($true){
        $stream=$null
        try {
            # Do not truncate until the sharing-compatible writer handle is acquired.
            $stream=[IO.File]::Open($Path,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
            $stream.Write($bytes,0,$bytes.Length)
            $stream.SetLength($bytes.Length)
            $stream.Flush()
            return
        } catch {
            $cause=$_.Exception
            while($cause.InnerException){$cause=$cause.InnerException}
            $code=$cause.HResult -band 65535
            if($cause -isnot [IO.IOException] -or $code -notin @(32,33) -or $timer.ElapsedMilliseconds -ge $TimeoutMilliseconds){throw}
            Start-Sleep -Milliseconds 40
        } finally {if($stream){$stream.Dispose()}}
    }
}
