package ai.pexora.localboot;
import java.io.*;import java.lang.reflect.*;import java.net.*;import java.nio.file.*;import java.security.*;import java.util.*;import java.util.jar.*;import java.util.function.BiConsumer;
public final class LocalPluginProbe {
 private static final String HASH="6dd9a405a4fd6c6610c63a8d8e3a63f13d64a5ec7de4ecd0bd23dcf44bedb5ae";
 private static final Path PROFILE=Path.of("C:\\SandboxGuard\\first-game-v1\\profile");
 private static final Path JAR=PROFILE.resolve(".detuksosrs/plugin-hub/mikes-fishing_"+HASH+".jar");
 private static volatile Object fixtureManager;
 private static Object awaitManager(Field field,long timeoutMs)throws Exception{
  long started=System.nanoTime();Object value;
  while((value=field.get(null))==null){
   if((System.nanoTime()-started)/1_000_000L>=timeoutMs)throw new IllegalStateException("Manager readiness deadline");
   Thread.sleep(100);
  }
  return value;
 }
 private static ClassLoader retainedLoader;private static List<?> retainedPlugins;
 private static String hash(Path p)throws Exception{MessageDigest md=MessageDigest.getInstance("SHA-256");try(InputStream s=Files.newInputStream(p)){byte[] b=new byte[8192];int n;while((n=s.read(b))>0)md.update(b,0,n);}StringBuilder h=new StringBuilder();for(byte b:md.digest())h.append(String.format("%02x",b&255));return h.toString();}
 private static void set(Object o,String name,Object value)throws Exception{Field f=o.getClass().getDeclaredField(name);f.setAccessible(true);f.set(o,value);}
 private static String errorType(Throwable e){for(int i=0;i<5&&e instanceof InvocationTargetException&&((InvocationTargetException)e).getCause()!=null;i++)e=e.getCause();return e.getClass().getName();}
 public static int inspect()throws Exception{
  Path output=Path.of("C:\\CanaryLogs\\first-launch-20260906-v1\\local-plugin-"+ProcessHandle.current().pid()+".txt");
  try(PrintWriter out=new PrintWriter(Files.newBufferedWriter(output,StandardOpenOption.CREATE_NEW))){
   out.println("SCOPE=one-local-mikes-fishing-plugin;START_REQUESTED=false;SOURCE_CLIENT_ACCESSED=false");out.flush();
   String phase="profile";
   try{
    boolean home=Path.of(System.getProperty("user.home")).toAbsolutePath().normalize().equals(PROFILE);out.println("JAVA_PROFILE_ISOLATED="+home);out.flush();if(!home)return 20;
    if(!hash(JAR).equals(HASH)||Files.size(JAR)!=641174)throw new IllegalStateException("Software pin");
    SortedSet<String> names=new TreeSet<>();
    try(JarFile file=new JarFile(JAR.toFile())){Enumeration<JarEntry> es=file.entries();int total=0;while(es.hasMoreElements()){
     JarEntry e=es.nextElement();if(++total>1000)throw new IOException("Entry bound");String n=e.getName();if(n.endsWith(".class")){
      if(!n.matches("[A-Za-z_$][A-Za-z0-9_$/]*\\.class")||n.contains("//")||!names.add(n.substring(0,n.length()-6).replace('/','.')))throw new IOException("Class scope");
     }
    }}
    if(names.size()!=129||!names.contains("com.e.c.Fishing"))throw new IllegalStateException("Wrong plugin inventory");out.println("EXPECTED_CLASSES="+names.size());out.flush();
    ClassLoader system=ClassLoader.getSystemClassLoader();Class<?> descriptor=Class.forName("c.d.c.h.g$a",true,system);
    Object metadata=descriptor.getDeclaredConstructor().newInstance();set(metadata,"internalName","mikes-fishing");set(metadata,"displayName","Mike's Fishing (local test)");set(metadata,"jarHash",HASH);set(metadata,"jarSize",641174);set(metadata,"version","local-test");
    phase="plugin-path";File resolved=(File)descriptor.getMethod("VR").invoke(metadata);if(!resolved.toPath().toAbsolutePath().normalize().equals(JAR))throw new IllegalStateException("Plugin path escaped profile");
    phase="loader";Class<?> gson=Class.forName("com.google.gson.Gson",true,system);Class<?> loaderType=Class.forName("c.d.c.h.j",true,system);
    retainedLoader=(ClassLoader)loaderType.getConstructor(descriptor,URL[].class,gson).newInstance(metadata,new URL[]{JAR.toUri().toURL()},gson.getConstructor().newInstance());
    out.println("NATIVE_PLUGIN_LOADER_CREATED=true");out.flush();
    phase="definitions";int success=0;Class<?> entry=null;
    for(String name:names){try{Class<?> c=Class.forName(name,false,retainedLoader);if(c.getClassLoader()!=retainedLoader)throw new LinkageError("Unexpected loader");success++;if(name.equals("com.e.c.Fishing"))entry=c;}catch(Throwable e){out.println("CLASS_FAILURE="+name+":"+errorType(e));}}
    out.println("DEFINED_CLASSES="+success);out.flush();if(success!=129||entry==null)return 21;
    phase="manager";Class<?> hub=Class.forName("c.d.c.h.c",false,system);Class<?> managerType=Class.forName("c.d.c.m.z",false,system);Field managerField=hub.getDeclaredField("n");
    if(managerField.getType()!=managerType||!Modifier.isStatic(managerField.getModifiers())){out.println("MANAGER_METADATA_MATCH=false");out.flush();throw new IllegalStateException("Manager metadata changed");}out.println("MANAGER_METADATA_MATCH=true");out.println("MANAGER_WAIT_LIMIT_MS=45000");out.flush();long managerStarted=System.nanoTime();Object manager=awaitManager(managerField,45000);out.println("MANAGER_READY_AFTER_MS="+((System.nanoTime()-managerStarted)/1_000_000L));out.flush();
    phase="load-single-plugin";Method load=managerType.getMethod("VG",List.class,BiConsumer.class);
    retainedPlugins=(List<?>)load.invoke(manager,Collections.singletonList(entry),null);
    if(retainedPlugins.size()!=1||retainedPlugins.get(0).getClass()!=entry)throw new IllegalStateException("Unexpected plugin result");
    out.println("LOCAL_PLUGIN_INSTANCES=1");out.println("PLUGIN_START_REQUESTED=false");out.println("RESULT=0");out.flush();return 0;
   }catch(Throwable e){out.println("FAILED_PHASE="+phase);out.println("ERROR_TYPE="+errorType(e));out.println("RESULT=22");out.flush();return 22;}
  }
 }
 public static void main(String[] args)throws Exception{
  if(!"com/e/c/Fishing.class".matches("[A-Za-z_$][A-Za-z0-9_$/]*\\.class")||"../Bad.class".matches("[A-Za-z_$][A-Za-z0-9_$/]*\\.class"))throw new AssertionError();
  if(!errorType(new InvocationTargetException(new IOException())).equals("java.io.IOException"))throw new AssertionError();
  if(!JAR.normalize().startsWith(PROFILE)||!JAR.getFileName().toString().equals("mikes-fishing_"+HASH+".jar"))throw new AssertionError();
  Field f=LocalPluginProbe.class.getDeclaredField("fixtureManager");
  Object expected=new Object();Thread publisher=new Thread(()->{try{Thread.sleep(150);}catch(InterruptedException e){throw new RuntimeException(e);}fixtureManager=expected;});
  publisher.start();if(awaitManager(f,2000)!=expected)throw new AssertionError("delayed manager");publisher.join();
  fixtureManager=null;boolean timedOut=false;try{awaitManager(f,100);}catch(IllegalStateException e){timedOut=true;}if(!timedOut)throw new AssertionError("manager timeout");
  System.out.println("LOCAL_PLUGIN_FIXTURE=PASS checks=5;DELAYED_MANAGER=PASS;MISSING_MANAGER=REFUSED");
 }
}
