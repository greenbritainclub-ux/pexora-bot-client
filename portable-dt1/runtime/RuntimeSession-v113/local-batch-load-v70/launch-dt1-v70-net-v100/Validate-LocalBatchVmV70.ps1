param([Parameter(Mandatory=$true)][ValidatePattern('^connected-v4-[0-9-]+$')][string]$Run,[Parameter(Mandatory=$true)][int]$ExpectedProcessId,[Parameter(Mandatory=$true)][long]$ExpectedStartTicks,[switch]$AfterAttachment)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:USERNAME -ne 'WDAGUtilityAccount' -or $env:USERPROFILE -ne 'C:\Users\WDAGUtilityAccount') {throw 'Windows Sandbox guest only.'}
$caseRoot='C:\CanaryLogs\first-launch-20260906-v1'
$target=Join-Path 'C:\CanaryLogs\plugin-batch-20260906-v1' ('local-batch-vm-v70-'+$Run+$(if($AfterAttachment){'-after'}else{'-before'})+'.json')
if(Test-Path -LiteralPath $target) {throw 'Existing validation must not be overwritten.'}
$profilePath='C:\CanaryLogs\resource-export-20260906-v3\current-vm-profile.json'
if((Get-FileHash -LiteralPath $profilePath -Algorithm SHA256).Hash -ne 'CA4D132B0E653FE351DA711666BF14AC2E4928D79FC5C9924A5305028C2BDA6D'){throw 'Profile pin mismatch'}
$profile=Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
$work='C:\SandboxGuard\live-resource-validation-v1'
New-Item -ItemType Directory -Path $work -Force | Out-Null
$env:TEMP=$work;$env:TMP=$work
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public sealed class PexoraBoundedRead : IDisposable {
    [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenProcess(uint rights,bool inherit,int pid);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool ReadProcessMemory(IntPtr process,IntPtr address,byte[] result,UIntPtr size,out UIntPtr actual);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    IntPtr handle;long start;long size;
    public PexoraBoundedRead(int pid,long moduleBase,long imageSize) {start=moduleBase;size=imageSize;handle=OpenProcess(0x1010,false,pid);if(handle==IntPtr.Zero)throw new InvalidOperationException("Read-only process handle unavailable");}
    public byte[] Read(long rva,int length) {
        if(rva<0 || length<1 || length>4096 || rva>size-length)throw new ArgumentOutOfRangeException();
        byte[] output=new byte[length];UIntPtr actual;
        if(!ReadProcessMemory(handle,new IntPtr(start+rva),output,new UIntPtr((uint)length),out actual) || actual.ToUInt64()!=(ulong)length)throw new InvalidOperationException("Bounded software read failed");
        return output;
    }
    public void Dispose(){if(handle!=IntPtr.Zero){CloseHandle(handle);handle=IntPtr.Zero;}}
}
'@
$result=[ordered]@{TimestampUtc=[DateTime]::UtcNow.ToString('o');ProfileSHA256=(Get-FileHash -LiteralPath $profilePath -Algorithm SHA256).Hash;ProcessId=$null;CodePins=@();RuntimeFileHashMatches=$false;HeaderMatches=$false;VmTablePointerMatches=$false;VmFunctionsMatch=$false;Ready=$false;ThreadSlotFree=$false;ExistingInstrumentation=@();BytesRead=0;ReadOnlyHandle=$true;LiveMemoryWritten=$false;AttachmentPerformed=$false;Passed=$false;ErrorType=$null}
$reader=$null
try {
    $games=@(Get-Process -Name osclient -ErrorAction Stop|Where-Object Path -eq 'C:\SandboxGuard\first-game-v1\osclient.exe')
    if($games.Count -ne 1){throw 'Expected one owned local game'}
    $game=$games[0];$result.ProcessId=$game.Id
    if(!$game.Responding){throw 'Local game unresponsive'}
    $result['ProcessStartTicks']=$game.StartTime.ToUniversalTime().Ticks
    $modules=@($game.Modules);$runtime=@($modules|Where-Object FileName -eq 'C:\SandboxGuard\first-game-v1\core.dll')
    if($runtime.Count -ne 1){throw 'Runtime identity'}
    $batchModules=@($modules|Where-Object ModuleName -like 'LocalBatch*')
    if(!$AfterAttachment -and $batchModules.Count){throw 'Batch helper already attached'}
    if($AfterAttachment -and ($batchModules.Count -ne 1 -or $batchModules[0].FileName -ne 'C:\SandboxGuard\local-batch-load-v70\LocalBatchLoadV70.dll' -or (Get-FileHash -LiteralPath $batchModules[0].FileName -Algorithm SHA256).Hash -ne 'BF64805F6A8A9A514471C84BE9EA4FA8EE011D67C122DFEBB73DAF69E1EBE18D')){throw 'Post-attachment module identity'}
    . 'C:\SandboxGuard\local-batch-load-v70\launch-dt1-v70-net-v100\LocalBatchSessionGateV4.ps1'
    $state=Get-Content -LiteralPath (Join-Path $caseRoot ($Run+'-state.json')) -Raw|ConvertFrom-Json
    $harness=Get-Process -Id $state.HarnessId
    $supervisor=Get-Process -Id $state.SupervisorId
    $parent=if($env:PEXORA_LOCAL_RUNTIME -eq '1'){$null}else{(Get-CimInstance Win32_Process -Filter ('ProcessId='+$game.Id)).ParentProcessId}
    Assert-LocalBatchSessionV4 $Run $ExpectedProcessId $ExpectedStartTicks $state @{Path=$game.Path;Id=$game.Id;StartTicks=$game.StartTime.ToUniversalTime().Ticks;Responding=$game.Responding} @{Path=$harness.Path;Id=$harness.Id;StartTicks=$harness.StartTime.ToUniversalTime().Ticks} @{Path=$supervisor.Path;Id=$supervisor.Id;StartTicks=$supervisor.StartTime.ToUniversalTime().Ticks} $parent
    if((Get-FileHash -LiteralPath $harness.Path -Algorithm SHA256).Hash -ne 'CE453CBB4BFD55B76B2525FE42D08649B8E107E3764F9E2DEE120A42DC959396'){throw 'Reviewed overlay harness pin'}
    $kitPath='C:\PreparedRuntime\mike-manager-ready-v1\runtime-kit.json'
    if((Get-FileHash -LiteralPath $kitPath -Algorithm SHA256).Hash -ne '972E399DDB7D04A58BD72B1EA2A4F891F4DC7E828DF0639B59DCA516E1E43614'){throw 'Runtime kit manifest pin'}
    $kit=Get-Content -LiteralPath $kitPath -Raw|ConvertFrom-Json
    foreach($f in $kit.Files){if((Get-FileHash -LiteralPath (Join-Path 'C:\SandboxGuard\first-game-v1' $f.RelativePath) -Algorithm SHA256).Hash -ne $f.SHA256){throw 'Runtime kit changed'}}
    foreach($prefix in @('local-plugin-native-','local-plugin-list-native-')){
        $priorReport=Join-Path $caseRoot ($prefix+$game.Id+'.txt')
        if((Get-Item -LiteralPath $priorReport).LastWriteTimeUtc -lt $game.StartTime.ToUniversalTime()){throw 'Stale prior helper report'}
        $lines=@(Get-Content -LiteralPath $priorReport)
        foreach($required in @('ATTACH_RESULT=0','DETACH_RESULT=0','THREAD_SLOT_RESTORED=true','RESULT=0')){if($lines -notcontains $required){throw 'Prior helper cleanup failed'}}
    }
    $instrumentation=@($modules|Where-Object {$_.ModuleName -match '^Local|^Pexora|^Fishing' -and $_.ModuleName -notlike 'LocalBatch*'})
    $result.ExistingInstrumentation=@($instrumentation|ForEach-Object ModuleName)
    $allowed=@{
        'LocalBootstrap.dll'='8484B2475C031D7CB409D68A4227704207991E7C27F91BC97DA1DC915F335AFD'
        'LocalPluginAttach.dll'='E2E7191129B16073ED23C5E4B1D053C716F67DD105E568B28A3E55DD62468280'
        'LocalPluginListAttachV39.dll'='E51A2101C72E13B972A0B4154829EEF857D9F9CC24893D5429122C09903B314B'
    }
    if($instrumentation.Count -ne $allowed.Count){throw 'Unexpected instrumentation inventory'}
    foreach($name in $allowed.Keys){
        $path='C:\SandboxGuard\first-game-v1\'+$name
        if(@($instrumentation|Where-Object FileName -eq $path).Count -ne 1 -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $allowed[$name]){throw 'Instrumentation identity or hash'}
    }
    $hash=(Get-FileHash -LiteralPath $runtime[0].FileName -Algorithm SHA256).Hash
    $result.RuntimeFileHashMatches=$hash -eq $profile.RuntimeSHA256
    if(-not $result.RuntimeFileHashMatches -or $runtime[0].ModuleMemorySize -ne $profile.ImageSize) {throw 'Runtime changed.'}
    $moduleBase=$runtime[0].BaseAddress.ToInt64()
    $reader=New-Object PexoraBoundedRead($game.Id,$moduleBase,$profile.ImageSize)
    $header=$reader.Read(0,1024);$result.BytesRead+=1024
    $pe=[BitConverter]::ToUInt32($header,60)
    if($pe -gt 700) {throw 'Unexpected PE header offset.'}
    $result.HeaderMatches=([BitConverter]::ToUInt16($header,0) -eq 0x5a4d -and [BitConverter]::ToUInt32($header,$pe) -eq 0x4550 -and [BitConverter]::ToUInt32($header,$pe+8) -eq $profile.PETimeDateStamp -and [BitConverter]::ToUInt32($header,$pe+24+56) -eq $profile.ImageSize)
    foreach($pin in $profile.Pins) {
        $bytes=$reader.Read($pin.RVA,$pin.Length);$result.BytesRead+=$pin.Length
        $actual=([BitConverter]::ToString($bytes)).Replace('-','').ToLowerInvariant()
        $result.CodePins+=[pscustomobject]@{Name=$pin.Name;Matches=$actual -ceq $pin.Bytes;Length=$pin.Length}
    }
    $vm=$reader.Read($profile.VmObjectRVA,8);$result.BytesRead+=8
    $result.VmTablePointerMatches=[BitConverter]::ToInt64($vm,0) -eq ($moduleBase+$profile.InvocationTableRVA)
    $table=$reader.Read($profile.InvocationTableRVA,64);$result.BytesRead+=64
    $result.VmFunctionsMatch=$true
    for($index=0;$index -lt 8;$index++) {
        $expected=if($index -lt 3){0L}else{$moduleBase+$profile.InvocationFunctionRVAs[$index-3]}
        if([BitConverter]::ToInt64($table,8*$index) -ne $expected) {$result.VmFunctionsMatch=$false}
    }
    $result.Ready=[BitConverter]::ToInt32($reader.Read($profile.ReadinessRVA,4),0) -eq 2
    $result.ThreadSlotFree=[BitConverter]::ToInt32($reader.Read($profile.ThreadCountRVA,4),0) -eq 0
    $result.BytesRead+=8
    $result.Passed=$result.HeaderMatches -and $result.VmTablePointerMatches -and $result.VmFunctionsMatch -and $result.Ready -and $result.ThreadSlotFree -and @($result.CodePins | Where-Object {-not $_.Matches}).Count -eq 0
} catch {$result.ErrorType=$_.Exception.GetType().Name;$result['GuardError']=$_.Exception.Message} finally {if($reader){$reader.Dispose()}}
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $target -Encoding UTF8
if(-not $result.Passed) {exit 2}
