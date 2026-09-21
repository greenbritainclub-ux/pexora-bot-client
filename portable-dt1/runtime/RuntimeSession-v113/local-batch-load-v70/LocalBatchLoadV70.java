package ai.pexora.localboot;
import java.io.*;import java.lang.reflect.*;import java.net.*;import java.nio.file.*;import java.security.*;import java.util.*;import java.util.concurrent.*;import java.util.function.BiConsumer;import java.util.jar.*;import javax.swing.SwingUtilities;
/** Four pinned local archives; definitions, registration and native list rebuild. No Start/Stop. */
public final class LocalBatchLoadV70 {
 static final String[][] TARGETS={
 {"allure-account-builder","com.a.f.a.AllureAccountBuilder","3934b70f55ef60e62f565d52c367d9a009115b6acd1593d8e07df87f968df17f","9931108","2222","12","d24ba3c73125aba14199ecbebc4091bff02ad9bdd531120427406e972b24de9a","7eb70257593da06f682a3ddda54a9d260d4fc514f645237f5ca74b08f8da61a6","Allure Account Builder (local test)"},
 {"detuks-inferno","com.a.g.a.b.a.InfernoPlugin","990caba26e52a2cee8b9dd479124ea6d5ec1ee01d6ac0b9b6be7f0d90d1e44b0","5044146","1558","20","52cd303513d0bab258aea855590cbfab71708dcd3b342d1156f7d5a37d1524d4","7a0600f7a587f3ba530428a42304ed48808c2f2a9410827001e8878e514c783b","Detuks Inferno (local test)"},
 {"detuks-fight-caves","com.a.g.a.b.a.FightCavePlugin","eb4a68b5a1b4cab8059cc8457a366f7c928ad5685c6e3e4a7ad6ee8e317ed2e3","5182256","1553","21","a7f516adab84fb526c49164f9c5afff3f4ff33486cda351020140d73582e3529","7a0600f7a587f3ba530428a42304ed48808c2f2a9410827001e8878e514c783b","Detuks Fight Caves (local test)"},
 {"detuks-colosseum","com.a.g.a.b.a.ColosseumPlugin","512065e7d34eef35a4398ccec4a91f926b3955e6a007273a6efeb03479e14acc","5037549","1560","20","c1ccdbaea199e9082226b2ab1bb6febebae4378c45b9d509f7c17677d2a74e14","7a0600f7a587f3ba530428a42304ed48808c2f2a9410827001e8878e514c783b","Detuks Colosseum (local test)"}};
 static final Path PROFILE=Path.of("C:\\SandboxGuard\\first-game-v1\\profile"),WORK=Path.of("C:\\SandboxGuard\\local-batch-load-v70"),ROOT=Path.of("C:\\CanaryLogs\\plugin-batch-20260906-v1");
 static final List<ClassLoader> loaders=new ArrayList<>();static final List<Object> instances=new ArrayList<>();
 static void need(boolean b,String reason){if(!b)throw new IllegalStateException(reason);}
 static Field field(Class<?> t,String n,Class<?> v)throws Exception{Field f=t.getDeclaredField(n);need(f.getType()==v,"field type");f.setAccessible(true);return f;}
 static String hash(Path p)throws Exception{MessageDigest d=MessageDigest.getInstance("SHA-256");try(InputStream in=Files.newInputStream(p)){byte[] b=new byte[65536];for(int n;(n=in.read(b))!=-1;)d.update(b,0,n);}StringBuilder s=new StringBuilder();for(byte b:d.digest())s.append(String.format("%02x",b&255));return s.toString();}
 static String type(Throwable e){for(int i=0;i<5&&e instanceof InvocationTargetException&&e.getCause()!=null;i++)e=e.getCause();return e.getClass().getName();}
 static Set<Object> identities(Collection<?> xs){need(xs!=null&&xs.size()<=1024,"collection bound");Set<Object> s=Collections.newSetFromMap(new IdentityHashMap<Object,Boolean>());s.addAll(Arrays.asList(xs.toArray()));return s;}
 static int count(Collection<?> list,Object value){int n=0;for(Object v:list.toArray())if(v==value)n++;return n;}
 static Object fallback(Class<?> entry,Object unsafe,Method alloc,Object injector,Class<?> injectorType,ClassLoader system,PrintWriter out,String tag)throws Exception{Object plugin=alloc.invoke(unsafe,entry);for(Class<?> sc=entry;sc!=null&&!sc.getName().equals("java.lang.Object");sc=sc.getSuperclass())for(Field f:sc.getDeclaredFields()){if(Modifier.isStatic(f.getModifiers()))continue;f.setAccessible(true);Class<?> ft=f.getType();Object val=null;String n=ft.getName();if(n.startsWith("com.a.g.")){try{Constructor<?> c=ft.getDeclaredConstructor();c.setAccessible(true);val=c.newInstance();}catch(Throwable e){val=alloc.invoke(unsafe,ft);}}else{try{Class<?> lookup=(n.startsWith("c.d.")||n.startsWith("net.")||n.startsWith("com.google."))?Class.forName(n,false,system):ft;val=injectorType.getMethod("getInstance",Class.class).invoke(injector,lookup);}catch(Throwable e){out.println("FIELD_SET_FAIL\t"+tag+"\t"+f.getName()+"\t"+n);}}if(val!=null)try{f.set(plugin,val);}catch(Throwable e){out.println("FIELD_SET_FAIL\t"+tag+"\t"+f.getName()+"\tset");}}return plugin;}
 static boolean routeInfernoDebugOverlay(Object plugin,ClassLoader system)throws Exception{
  if(!plugin.getClass().getName().equals("com.a.g.a.b.a.InfernoPlugin"))return false;
  Class<?> overlayType=Class.forName("c.d.c.p.c.Overlay",false,system),managerType=Class.forName("c.d.c.p.c.OverlayManager",false,system),layerType=Class.forName("c.d.c.p.c.OverlayLayer",false,system);
  Field overlayField=plugin.getClass().getField("e"),managerField=plugin.getClass().getField("f");need(overlayField.getType().getName().equals("com.a.g.a.b.a.c")&&managerField.getType()==managerType,"Inferno overlay fields");
  Object overlay=overlayField.get(plugin),overlayManager=managerField.get(plugin);need(overlay!=null&&overlayType.isInstance(overlay)&&overlayManager!=null,"Inferno overlay identities");
  List<?> overlays=(List<?>)field(managerType,"overlays",List.class).get(overlayManager);need(count(overlays,overlay)==0,"stopped Inferno overlay unexpectedly registered");
  Field layer=field(overlayType,"layer",layerType);Object top=layerType.getField("ALWAYS_ON_TOP").get(null),before=layer.get(overlay);
  if(before!=top)overlayType.getMethod("setLayer",layerType).invoke(overlay,top);need(layer.get(overlay)==top,"Inferno debug overlay route");return before!=top;
 }
 static Path archive(String[] t){return PROFILE.resolve(".detuksosrs/plugin-hub/"+t[0]+"_"+t[2]+".jar");}
 static Set<String> plan(String slug,String suffix,String pin)throws Exception{Path p=WORK.resolve(slug+suffix);need(hash(p).equals(pin)&&Files.size(p)<1024*1024,"plan pin");Set<String> s=new TreeSet<>();for(String n:Files.readAllLines(p))if(!n.isEmpty()){need(n.matches("[A-Za-z0-9_$.-]+")&&!n.contains("..")&&s.add(n),"plan name");}return s;}
 static boolean local(URL u,Path p)throws Exception{return u!=null&&u.getProtocol().equals("file")&&u.toURI().getRawAuthority()==null&&Path.of(u.toURI()).equals(p);}
 public static int inspect()throws Exception{
  try(PrintWriter out=new PrintWriter(Files.newBufferedWriter(ROOT.resolve("local-batch-load-v70-"+ProcessHandle.current().pid()+".txt"),StandardOpenOption.CREATE_NEW))){
   out.println("SCOPE=four-pinned-local-plugin-archives;START_REQUESTED=false;STOP_REQUESTED=false;SOURCE_CLIENT_ACCESSED=false;ACCOUNT_FIELDS=false;AUTH_SETTINGS_CHANGED=false");out.flush();String phase="profile";
   try{
    need(Path.of(System.getProperty("user.home")).equals(PROFILE),"isolated profile");ClassLoader system=ClassLoader.getSystemClassLoader();
    Class<?> hub=Class.forName("c.d.c.h.c",false,system),mt=Class.forName("c.d.c.m.z",false,system),base=Class.forName("c.d.c.m.v",false,system);
    Field mf=field(hub,"n",mt);need(Modifier.isStatic(mf.getModifiers()),"manager static");Object manager=mf.get(null);need(manager!=null&&manager.getClass()==mt,"manager");
    List<?> registered=(List<?>)field(mt,"r",List.class).get(manager),running=(List<?>)field(mt,"s",List.class).get(manager);Set<Object> runningBefore=identities(running),registeredBefore=identities(registered);Object mike=null;
    for(int wait=0;wait<90&&mike==null;wait++){for(Object v:registered)if(v.getClass().getName().equals("com.e.c.Fishing")){mike=v;break;}if(mike==null)Thread.sleep(500);}
    for(Object v:registered){need(base.isInstance(v),"plugin base");for(String[] t:TARGETS)need(!v.getClass().getName().equals(t[1]),"selected already registered");}need(mike!=null,"Mike identity");
    out.println("MIKE_PRESENT=true;RUNNING_SET_SNAPSHOTTED=true");out.flush();
    Class<?> descriptor=Class.forName("c.d.c.h.g$a",false,system),gson=Class.forName("com.google.gson.Gson",false,system),lt=Class.forName("c.d.c.h.j",false,system);
    need(URLClassLoader.class.isAssignableFrom(lt),"loader type");List<Class<?>> entries=new ArrayList<>();int failed=0;
    for(String[] t:TARGETS){
     phase=t[0]+":archive";Path jar=archive(t);need(Files.size(jar)==Long.parseLong(t[3])&&hash(jar).equals(t[2]),"archive pin");Set<String> expected=plan(t[0],"-classes.txt",t[6]),parents=plan(t[0],"-parent-classes.txt",t[7]);need(expected.contains(t[1])&&expected.containsAll(parents),"scope sets");
     Set<String> actual=new TreeSet<>();int classes=0,resources=0;try(JarFile z=new JarFile(jar.toFile(),false)){Set<String> all=new HashSet<>();Enumeration<JarEntry> en=z.entries();while(en.hasMoreElements()){JarEntry e=en.nextElement();if(e.isDirectory())continue;String n=e.getName();need(all.add(n)&&all.size()<=10000,"duplicate inventory");if(n.endsWith(".class")){classes++;if(n.startsWith("META-INF/")){need(n.equals("META-INF/versions/9/module-info.class"),"descriptor path");continue;}need(actual.add(n.substring(0,n.length()-6).replace('/','.')),"duplicate definition");}else resources++;}}
     need(actual.equals(expected)&&classes==Integer.parseInt(t[4])&&resources==Integer.parseInt(t[5]),"exact archive inventory");
     phase=t[0]+":descriptor";Object metadata=descriptor.getDeclaredConstructor().newInstance();field(descriptor,"internalName",String.class).set(metadata,t[0]);field(descriptor,"displayName",String.class).set(metadata,t[8]);field(descriptor,"jarHash",String.class).set(metadata,t[2]);field(descriptor,"jarSize",int.class).setInt(metadata,Integer.parseInt(t[3]));field(descriptor,"version",String.class).set(metadata,"local-test");
     need(((File)descriptor.getMethod("VR").invoke(metadata)).toPath().equals(jar),"descriptor path");
     phase=t[0]+":native-loader";ClassLoader loader=(ClassLoader)lt.getConstructor(descriptor,URL[].class,gson).newInstance(metadata,new URL[]{jar.toUri().toURL()},gson.getConstructor().newInstance());loaders.add(loader);need(loader.getClass()==lt,"exact loader");URL[] urls=((URLClassLoader)loader).getURLs();need(urls.length==1&&local(urls[0],jar),"loader URL");
     phase=t[0]+":definitions";int own=0,shared=0,errors=0;Class<?> entry=null;
     for(String name:expected){Class<?> c;try{c=Class.forName(name,false,loader);}catch(LinkageError|ClassNotFoundException e){out.println("CLASS_FAILURE\t"+t[0]+"\t"+name+"\t"+type(e));errors++;continue;}
      if(c.getClassLoader()==loader){need(local(c.getProtectionDomain().getCodeSource().getLocation(),jar),"definition origin");own++;}else{need(c.getClassLoader()==system&&parents.contains(name),"unexpected delegation");shared++;}
      if(name.equals(t[1])){need(c.getClassLoader()==loader&&base.isAssignableFrom(c),"entry identity");entry=c;}
     }
     out.println("DEFINITIONS\t"+t[0]+"\texpected="+expected.size()+"\town="+own+"\tshared="+shared+"\terrors="+errors+"\tentry="+(entry!=null));out.flush();need(identities(running).equals(runningBefore),"running state changed during definitions");
     if(errors==0&&entry!=null&&t[0].equals("detuks-colosseum")){phase="resolved-colosseum-signatures";for(String name:new String[]{"com.a.g.a.a.f.K","com.a.g.a.b.a.e","com.a.g.a.b.a.b.c","com.a.g.a.b.a.b.e"}){Class<?> c=Class.forName(name,false,loader);need(c.getClassLoader()==loader,"resolved class loader");int reflected=c.getDeclaredMethods().length+c.getDeclaredConstructors().length;out.println("RESOLVED_SIGNATURES\t"+name+"\tcount="+reflected+"\tINITIALIZATION_REQUESTED=false");}out.flush();}
     if(errors!=0||entry==null){failed++;entries.add(null);}else entries.add(entry);
    }
    int regFailures=0;Object injector=Class.forName("c.d.c.u",false,system).getMethod("VH").invoke(null);Class<?> injectorType=Class.forName("com.google.inject.Injector",false,system);Object unsafe=null;Method alloc=null;try{Class<?> ut=Class.forName("sun.misc.Unsafe");Field uf=ut.getDeclaredField("theUnsafe");uf.setAccessible(true);unsafe=uf.get(null);alloc=ut.getMethod("allocateInstance",Class.class);}catch(Throwable e){out.println("UNSAFE\tunavailable");}
    for(int i=0;i<TARGETS.length;i++){
     String[] t=TARGETS[i];Class<?> entry=entries.get(i);if(entry==null){regFailures++;continue;}phase=t[0]+":registration";
     final List<String> vgErrors=new CopyOnWriteArrayList<>();
     BiConsumer<Object,Object> cb=(a,b)->{StringBuilder s=new StringBuilder("arg1=");s.append(a==null?"null":a.getClass().getName());s.append(" arg2=");s.append(b==null?"null":b.getClass().getName());if(b instanceof Throwable){Throwable w=(Throwable)b;s.append(" msg=").append(String.valueOf(w.getMessage()).replace('\n',' ').replace('\r',' '));for(Throwable c=w.getCause();c!=null&&c!=w;c=c.getCause())s.append(" cause=").append(c.getClass().getName()).append(':').append(String.valueOf(c.getMessage()).replace('\n',' ').replace('\r',' '));}s.append(" arg1str=").append(String.valueOf(a).replace('\n',' ').replace('\r',' '));vgErrors.add(s.toString());};
     List<?> created=(List<?>)mt.getMethod("VG",List.class,BiConsumer.class).invoke(manager,Collections.singletonList(entry),cb);
     for(String e:vgErrors){out.println("VG_ERROR\t"+t[0]+"\t"+e);}out.flush();
    Object plugin=(created.size()==1&&created.get(0)!=null&&created.get(0).getClass()==entry)?created.get(0):null;
    if(plugin==null&&unsafe!=null){out.println("VG_FALLBACK\t"+t[0]);plugin=fallback(entry,unsafe,alloc,injector,injectorType,system,out,t[0]);}
    if(plugin==null){out.println("REGISTRATION_FAILED\t"+t[0]+"\tcreated="+created.size()+"\tcaptured="+vgErrors.size());out.flush();regFailures++;continue;}
    if(count(registered,plugin)==0)((List<Object>)registered).add(plugin);instances.add(plugin);need(count(registered,plugin)==1&&count(running,plugin)==0&&identities(running).equals(runningBefore),"registration state");
     if(t[0].equals("detuks-inferno")){boolean changed=routeInfernoDebugOverlay(plugin,system);out.println("INFERNO_DEBUG_OVERLAY_ROUTE=ALWAYS_ON_TOP;PRESTART=true;ROUTE_CHANGED="+changed+";LAYERS_REBUILT=false");}
     out.println("REGISTERED\t"+t[0]+"\tinstances=1\tstarted=false");out.flush();
    }
    phase="list-model";Class<?> app=Class.forName("c.d.c.u",false,system),keyType=Class.forName("com.google.inject.Key",false,system),bindingType=Class.forName("com.google.inject.Binding",false,system),providerType=Class.forName("com.google.inject.Provider",false,system),panelType=Class.forName("c.d.c.m.h.j",false,system);
    Object key=keyType.getMethod("get",Class.class).invoke(null,panelType),binding=injectorType.getMethod("getExistingBinding",keyType).invoke(injector,key);need(binding!=null,"existing panel binding");Object provider=bindingType.getMethod("getProvider").invoke(binding);final Object oldMike=mike;
    FutureTask<Integer> task=new FutureTask<>(()->{
     Object panel=providerType.getMethod("get").invoke(provider);need(panel.getClass()==panelType&&field(panelType,"pluginManager",mt).get(panel)==manager,"panel identity");
     need(identities(running).equals(runningBefore),"running state before list rebuild");panelType.getMethod("VM").invoke(panel);
     Class<?> rt=Class.forName("c.d.c.m.h.f",false,system),ct=Class.forName("c.d.c.m.h.a",false,system),cb=Class.forName("c.d.c.d.l",false,system),cd=Class.forName("c.d.c.d.n",false,system);List<?> rows=(List<?>)field(panelType,"pluginList",List.class).get(panel);need(rows!=null&&rows.size()<=1024,"row bounds");
     Field cfg=field(rt,"pluginConfig",ct),p=field(ct,"f",base);int checked=0,mikeRows=0;
     for(Object instance:instances){int found=0;Object config=null;for(Object row:rows){need(row.getClass()==rt,"row type");Object value=cfg.get(row);if(p.get(value)==instance){found++;config=value;}}need(found==1,"selected row count");boolean proxy=field(ct,"g",cb).get(config)!=null,desc=field(ct,"j",cd).get(config)!=null;out.println("ROW\t"+instance.getClass().getName()+"\tcount="+found+"\tconfigProxy="+proxy+"\tconfigDescriptor="+desc);need(proxy&&desc,"configuration missing");checked++;}
     for(Object row:rows)if(p.get(cfg.get(row))==oldMike)mikeRows++;
     need(mikeRows==1&&count(registered,oldMike)==1&&identities(running).equals(runningBefore)&&identities(registered).containsAll(registeredBefore),"existing plugin state changed");out.println("MIKE_ROW_PRESERVED=true;EXISTING_RUNNING_SET_UNCHANGED=true;LIST_REBUILT_ON_EDT="+SwingUtilities.isEventDispatchThread());out.flush();return checked;
    });
    if(SwingUtilities.isEventDispatchThread())task.run();else SwingUtilities.invokeLater(task);int checked;try{checked=task.get(45,TimeUnit.SECONDS);}catch(TimeoutException e){task.cancel(false);throw e;}
    out.println("SUMMARY\trequested=4\tregistered="+instances.size()+"\trows="+checked+"\tdefinitionFailures="+failed+"\tregistrationFailures="+regFailures);int result=failed==0&&regFailures==0&&checked==4?0:2;out.println("PLUGIN_START_REQUESTED=false");out.println("RESULT="+result);out.flush();return result;
   }catch(Throwable e){out.println("FAILED_PHASE="+phase);out.println("ERROR_TYPE="+type(e));out.println("RESULT=70");out.flush();return 70;}
  }
 }
 public static void main(String[] args)throws Exception{need(TARGETS.length==4,"targets");Set<String> slugs=new HashSet<>();for(String[] t:TARGETS){need(slugs.add(t[0])&&t[2].matches("[0-9a-f]{64}")&&archive(t).normalize().startsWith(PROFILE),"scope fixture");}Object a=new Object(),b=new Object();need(identities(Arrays.asList(a,b)).equals(identities(Arrays.asList(b,a))),"identity equality");need(!identities(Arrays.asList(a)).equals(identities(Arrays.asList(b))),"identity mismatch");need(count(Arrays.asList(a,b,a),a)==2,"identity count");Path p=PROFILE.resolve("fixture.jar");need(local(p.toUri().toURL(),p)&&!local(new URL("https://example.com/fixture.jar"),p),"local fixture");need(type(new InvocationTargetException(new IOException())).equals("java.io.IOException"),"error type");System.out.println("LOCAL_BATCH_JAVA_FIXTURE=PASS checks=10");}
}
