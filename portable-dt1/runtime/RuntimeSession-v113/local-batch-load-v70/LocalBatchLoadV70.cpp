#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <jni.h>
#include <fstream>
#include <string>
#include <vector>
#include <cstdio>
#include "PexoraResourcePins.h"
static std::ofstream report;
static void status(const char* text){report<<text<<'\n';report.flush();}
static bool readExact(const void* at,void* output,SIZE_T length){SIZE_T actual=0;return ReadProcessMemory(GetCurrentProcess(),at,output,length,&actual)&&actual==length;}
static bool matches(const unsigned char* base,uintptr_t rva,const unsigned char* expected,size_t length){std::vector<unsigned char> a(length);return readExact(base+rva,a.data(),length)&&memcmp(a.data(),expected,length)==0;}
static bool scoped(){wchar_t self[512]{},user[80]{},profile[256]{};GetModuleFileNameW(nullptr,self,512);GetEnvironmentVariableW(L"USERNAME",user,80);GetEnvironmentVariableW(L"USERPROFILE",profile,256);BOOL job{};IsProcessInJob(GetCurrentProcess(),nullptr,&job);return job&&!wcscmp(user,L"WDAGUtilityAccount")&&!wcscmp(profile,L"C:\\SandboxGuard\\first-game-v1\\profile")&&!_wcsicmp(self,L"C:\\SandboxGuard\\first-game-v1\\osclient.exe");}
static bool exception(JNIEnv* e){if(!e->ExceptionCheck())return false;e->ExceptionClear();status("JNI_EXCEPTION_MESSAGE_OMITTED=true");return true;}
static int inspect(JNIEnv* e){
 jclass url=e->FindClass("java/net/URL");if(exception(e)||!url)return 50;jmethodID ctor=e->GetMethodID(url,"<init>","(Ljava/lang/String;)V");if(exception(e)||!ctor)return 51;
 jstring path=e->NewStringUTF("file:/C:/SandboxGuard/local-batch-load-v70/LocalBatchLoadV70.jar");if(exception(e)||!path)return 52;jobject u=e->NewObject(url,ctor,path);if(exception(e)||!u)return 53;
 jobjectArray urls=e->NewObjectArray(1,url,u);if(exception(e)||!urls)return 54;jclass cl=e->FindClass("java/lang/ClassLoader");if(exception(e)||!cl)return 55;
 jmethodID get=e->GetStaticMethodID(cl,"getSystemClassLoader","()Ljava/lang/ClassLoader;");if(exception(e)||!get)return 56;jobject system=e->CallStaticObjectMethod(cl,get);if(exception(e)||!system)return 57;
 jclass ucl=e->FindClass("java/net/URLClassLoader");if(exception(e)||!ucl)return 58;jmethodID factory=e->GetStaticMethodID(ucl,"newInstance","([Ljava/net/URL;Ljava/lang/ClassLoader;)Ljava/net/URLClassLoader;");if(exception(e)||!factory)return 59;
 jobject loader=e->CallStaticObjectMethod(ucl,factory,urls,system);if(exception(e)||!loader)return 60;jmethodID load=e->GetMethodID(cl,"loadClass","(Ljava/lang/String;)Ljava/lang/Class;");if(exception(e)||!load)return 61;
 jstring name=e->NewStringUTF("ai.pexora.localboot.LocalBatchLoadV70");if(exception(e)||!name)return 62;jclass helper=(jclass)e->CallObjectMethod(loader,load,name);if(exception(e)||!helper)return 63;
 jmethodID run=e->GetStaticMethodID(helper,"inspect","()I");if(exception(e)||!run)return 64;jint code=e->CallStaticIntMethod(helper,run);if(exception(e))return 65;return code;
}
static bool reserve(volatile LONG* count,volatile LONG64* entry,LONG64 value,LONG64& prior){if(InterlockedCompareExchange(count,-1,0)!=0)return false;prior=InterlockedExchange64(entry,value);MemoryBarrier();InterlockedExchange(count,1);return true;}
static bool restore(volatile LONG* count,volatile LONG64* entry,LONG64 prior){if(InterlockedCompareExchange(count,-1,1)!=1)return false;InterlockedExchange64(entry,prior);MemoryBarrier();InterlockedExchange(count,0);return true;}
static DWORD WINAPI worker(void*){
 if(!scoped())return 40;wchar_t filename[256];swprintf_s(filename,L"C:\\CanaryLogs\\plugin-batch-20260906-v1\\local-batch-load-v70-native-%lu.txt",GetCurrentProcessId());if(GetFileAttributesW(filename)!=INVALID_FILE_ATTRIBUTES)return 67;report.open(filename,std::ios::out|std::ios::binary);if(!report)return 41;
 auto base=(unsigned char*)GetModuleHandleW(L"C:\\SandboxGuard\\first-game-v1\\core.dll");IMAGE_DOS_HEADER dos{};IMAGE_NT_HEADERS64 nt{};
 if(!base||!readExact(base,&dos,sizeof(dos))||dos.e_magic!=IMAGE_DOS_SIGNATURE||dos.e_lfanew<0||dos.e_lfanew>0x1000||!readExact(base+dos.e_lfanew,&nt,sizeof(nt))||nt.Signature!=IMAGE_NT_SIGNATURE||nt.FileHeader.TimeDateStamp!=kTimestamp||nt.OptionalHeader.SizeOfImage!=kImageSize){status("REFUSED=runtime-header");return 42;}
 for(const auto& p:kPins)if(!matches(base,p.rva,p.bytes,p.length)){status("REFUSED=code-pin");return 43;}
 void* table{};void* fns[8]{};if(!readExact(base+kVmRva,&table,8)||table!=base+kTableRva||!readExact(table,fns,sizeof(fns))){status("REFUSED=vm-table");return 44;}
 for(int i=0;i<8;i++)if(fns[i]!=(i<3?nullptr:base+kFunctions[i-3])){status("REFUSED=vm-functions");return 45;}
 LONG state{},value{};if(!readExact(base+kStateRva,&state,4)||state!=2||!readExact(base+kCountRva,&value,4)||value!=0){status("REFUSED=vm-not-ready-or-slot-busy");return 46;}
 auto count=(volatile LONG*)(base+kCountRva);auto entry=(volatile LONG64*)(base+kListRva);auto id=(unsigned long long(*)())(base+kThreadIdRva);LONG64 prior{};
 if(!reserve(count,entry,(LONG64)(id()^0x4F1E2D3C5B6A7980ULL),prior)){status("REFUSED=slot-busy");return 47;}
 JavaVM* vm=(JavaVM*)(base+kVmRva);JNIEnv* env{};jint attached=vm->AttachCurrentThreadAsDaemon((void**)&env,nullptr);report<<"ATTACH_RESULT="<<attached<<'\n';report.flush();int result=48;
 if(attached==JNI_OK&&env){result=inspect(env);jint detached=vm->DetachCurrentThread();report<<"DETACH_RESULT="<<detached<<'\n';if(detached!=JNI_OK)result=49;}
 if(restore(count,entry,prior))status("THREAD_SLOT_RESTORED=true");else{status("THREAD_SLOT_RESTORED=false");result=66;}
 report<<"RESULT="<<result<<'\n';report.flush();return result;
}
#ifdef LOCAL_BATCH_FIXTURE
int main(){volatile LONG c=0;volatile LONG64 e=77;LONG64 prior{};if(!reserve(&c,&e,123,prior)||prior!=77||c!=1||e!=123)return 1;LONG64 ignored{};if(reserve(&c,&e,999,ignored)||e!=123)return 2;if(!restore(&c,&e,prior)||c||e!=77)return 3;c=2;if(restore(&c,&e,99)||c!=2||e!=77)return 4;unsigned char a[]={1,2,3},b[]={1,2,4};if(!matches(a,0,a,3)||matches(a,0,b,3)||scoped())return 5;puts("LOCAL_PLUGIN_NATIVE_FIXTURE=PASS checks=7");return 0;}
#else
BOOL WINAPI DllMain(HINSTANCE h,DWORD reason,void*){if(reason==DLL_PROCESS_ATTACH){DisableThreadLibraryCalls(h);HANDLE t=CreateThread(nullptr,0,worker,nullptr,0,nullptr);if(!t)return FALSE;CloseHandle(t);}return TRUE;}
#endif
