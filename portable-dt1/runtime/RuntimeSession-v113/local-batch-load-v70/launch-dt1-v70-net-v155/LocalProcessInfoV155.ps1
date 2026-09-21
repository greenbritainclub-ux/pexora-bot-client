if(-not ('PexoraLocalProcessInfoV155' -as [type])){
Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
public static class PexoraLocalProcessInfoV155 {
  [StructLayout(LayoutKind.Sequential)] struct PBI { public IntPtr R1, Peb, R20, R21, Pid, ParentPid; }
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Auto)] struct MSX { public uint Length; public uint Load; public ulong Total, Available, TotalPage, AvailablePage, TotalVirtual, AvailableVirtual, AvailableExtended; }
  [DllImport("ntdll.dll")] static extern int NtQueryInformationProcess(IntPtr h, int c, ref PBI p, uint n, out uint r);
  [DllImport("kernel32.dll", CharSet=CharSet.Auto, SetLastError=true)] static extern bool GlobalMemoryStatusEx(ref MSX s);
  public static int ParentId(int pid){ using(Process p=Process.GetProcessById(pid)){PBI b=new PBI();uint r;int n=NtQueryInformationProcess(p.Handle,0,ref b,(uint)Marshal.SizeOf(b),out r);if(n!=0)throw new InvalidOperationException("Parent process query failed: "+n);return b.ParentPid.ToInt32();} }
  public static long AvailablePhysicalMemory(){MSX s=new MSX();s.Length=(uint)Marshal.SizeOf(s);if(!GlobalMemoryStatusEx(ref s))throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());return checked((long)s.Available);}
}
'@
}
function Get-PexoraParentProcessIdV155([int]$ProcessId){[PexoraLocalProcessInfoV155]::ParentId($ProcessId)}
function Get-PexoraAvailablePhysicalMemoryV155{[PexoraLocalProcessInfoV155]::AvailablePhysicalMemory()}
