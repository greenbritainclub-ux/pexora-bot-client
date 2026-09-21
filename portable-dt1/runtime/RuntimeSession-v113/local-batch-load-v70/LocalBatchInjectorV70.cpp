#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <tlhelp32.h>
#include <cstdio>
#include <cwchar>
#include <vector>
#include <cstdint>
static const wchar_t* target=L"C:\\SandboxGuard\\first-game-v1\\osclient.exe";
static const wchar_t* dll=L"C:\\SandboxGuard\\local-batch-load-v70\\LocalBatchLoadV70.dll";
static bool same(const wchar_t* a,const wchar_t* b){return a&&b&&!_wcsicmp(a,b);}
static bool module(DWORD pid,const wchar_t* path,MODULEENTRY32W& out){
 HANDLE snap=CreateToolhelp32Snapshot(TH32CS_SNAPMODULE|TH32CS_SNAPMODULE32,pid);if(snap==INVALID_HANDLE_VALUE)return false;
 MODULEENTRY32W m{sizeof(m)};bool found=false;if(Module32FirstW(snap,&m))do{if(same(m.szExePath,path)){out=m;found=true;break;}}while(Module32NextW(snap,&m));CloseHandle(snap);return found;
}
static int run(bool load,DWORD pid,ULONGLONG expected){
 HANDLE process=OpenProcess(PROCESS_CREATE_THREAD|PROCESS_QUERY_INFORMATION|PROCESS_VM_OPERATION|PROCESS_VM_WRITE|PROCESS_VM_READ,FALSE,pid);if(!process)return 10;
 struct Owner{HANDLE h;~Owner(){CloseHandle(h);}} ownerProcess{process};
 wchar_t path[512]{};DWORD size=512;FILETIME c{},x{},k{},u{};BOOL job{};
 if(!QueryFullProcessImageNameW(process,0,path,&size)||!same(path,target))return 11;
 if(!GetProcessTimes(process,&c,&x,&k,&u)||((ULONGLONG)c.dwHighDateTime<<32|c.dwLowDateTime)!=expected)return 12;
 if(!IsProcessInJob(process,nullptr,&job)||!job)return 13;
 MODULEENTRY32W core{},prior{};
 if(!module(pid,L"C:\\SandboxGuard\\first-game-v1\\core.dll",core)||core.modBaseSize!=63610880)return 14;
 if(module(pid,dll,prior))return 15;
 FARPROC loader=GetProcAddress(GetModuleHandleW(L"kernel32.dll"),"LoadLibraryW");HMODULE owner{};
 if(!loader||!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS|GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,(LPCWSTR)loader,&owner))return 16;
 wchar_t systemPath[512]{};GetModuleFileNameW(owner,systemPath,512);
 if(!same(systemPath,L"C:\\Windows\\System32\\KERNELBASE.dll")&&!same(systemPath,L"C:\\Windows\\System32\\kernel32.dll"))return 17;
 MODULEENTRY32W remote{};if(!module(pid,systemPath,remote))return 18;
 uintptr_t offset=(uintptr_t)loader-(uintptr_t)owner;if(remote.modBaseSize<32||offset>remote.modBaseSize-32)return 19;
 BYTE* remoteLoader=remote.modBaseAddr+offset;BYTE pin[32]{};SIZE_T n{};
 if(!ReadProcessMemory(process,remoteLoader,pin,32,&n)||n!=32||memcmp(pin,(void*)loader,32))return 20;
 puts("LOCAL_TARGET_IDENTITY_AND_SYSTEM_LOADER=PASS");fflush(stdout);if(!load)return 0;
 SIZE_T bytes=(wcslen(dll)+1)*sizeof(wchar_t);void* allocation=VirtualAllocEx(process,nullptr,bytes,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE);if(!allocation)return 21;
 std::vector<BYTE> back(bytes);
 if(!WriteProcessMemory(process,allocation,dll,bytes,&n)||n!=bytes||!ReadProcessMemory(process,allocation,back.data(),bytes,&n)||n!=bytes||memcmp(back.data(),dll,bytes)){VirtualFreeEx(process,allocation,0,MEM_RELEASE);return 22;}
 HANDLE thread=CreateRemoteThread(process,nullptr,0,(LPTHREAD_START_ROUTINE)remoteLoader,allocation,0,nullptr);
 if(!thread){VirtualFreeEx(process,allocation,0,MEM_RELEASE);return 23;}
 DWORD waited=WaitForSingleObject(thread,7000);CloseHandle(thread);
 if(waited!=WAIT_OBJECT_0){puts("LOADER_TIMEOUT_NO_RETRY=1");return 24;}
 VirtualFreeEx(process,allocation,0,MEM_RELEASE);
 bool found=module(pid,dll,prior);printf("EXACT_LOCAL_LIST_MODULE_PRESENT=%d\n",found);return found?0:25;
}
int wmain(int argc,wchar_t** argv){
 if(argc==2&&same(argv[1],L"--fixture")){
  if(!same(target,L"c:\\sandboxguard\\first-game-v1\\osclient.exe")||same(target,L"C:\\Users\\WDAGUtilityAccount\\AppData\\Local\\.dc\\l\\client\\240.11\\osclient.exe")||same(dll,target)||same(nullptr,target))return 1;
  puts("LOCAL_LIST_INJECTOR_FIXTURE=PASS checks=4");return 0;
 }
 wchar_t user[128]{};DWORD length=128;if(!GetUserNameW(user,&length)||!same(user,L"WDAGUtilityAccount"))return 30;
 if(argc!=4||(!same(argv[1],L"--check")&&!same(argv[1],L"--load")))return 31;
 wchar_t* end{};ULONGLONG value=wcstoull(argv[2],&end,10);if(!value||value>MAXDWORD||!end||*end)return 32;
 ULONGLONG stamp=wcstoull(argv[3],&end,10);if(!stamp||!end||*end)return 33;
 int result=run(same(argv[1],L"--load"),(DWORD)value,stamp);printf("INJECTOR_RESULT=%d\n",result);return result;
}
