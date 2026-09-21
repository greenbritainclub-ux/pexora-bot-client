package ai.pexora.localboot;

import java.awt.*;
import java.io.*;
import java.lang.annotation.Annotation;
import java.lang.reflect.*;
import java.nio.file.*;
import java.util.*;
import java.util.List;
import java.util.concurrent.*;
import javax.swing.*;

/** Initialize missing Delve defaults with the normal client config service. Never start a plugin. */
public final class DelveConfigV3 {
    static final String ENTRY="com.a.g.a.b.a.DelvePlugin", CONFIG="com.a.g.a.b.a.g", GROUP="detuksdelve";
    static final Set<String> KEYS=new HashSet<>(Arrays.asList("shouldUseDeathCharge","blowpipeDartStrength","resupplyMethod","minimumFood","superCombatAmount","rangingPotionAmount","restorePotionAmount","antivenomAmount","lootThreshold","maxDelveLevel","debug","removeInfoBox"));
    static void need(boolean b,String message){if(!b)throw new IllegalStateException(message);}
    static Field field(Class<?> c,String n)throws Exception{Field f=c.getDeclaredField(n);f.setAccessible(true);return f;}
    static Set<Object> identities(Collection<?> values){Set<Object>s=Collections.newSetFromMap(new IdentityHashMap<>());s.addAll(values);return s;}
    static boolean existingPreserved(Map<String,String> before,Map<String,String> after){for(Map.Entry<String,String> e:before.entrySet())if(e.getValue()!=null&&!e.getValue().equals(after.get(e.getKey())))return false;return true;}
    static Component find(Class<?> type){for(Window w:Window.getWindows()){ArrayDeque<Component> q=new ArrayDeque<>();q.add(w);while(!q.isEmpty()){Component c=q.removeFirst();if(type.isInstance(c))return c;if(c instanceof Container)q.addAll(Arrays.asList(((Container)c).getComponents()));}}return null;}
    static Map<String,String> values(Object manager,Method read)throws Exception{Map<String,String> out=new TreeMap<>();for(String key:KEYS)out.put(key,(String)read.invoke(manager,GROUP,key));return out;}
    public static int inspect()throws Exception{
        Path root=Path.of("C:\\CanaryLogs\\delve-dt1-v1");Files.createDirectories(root);
        Path report=root.resolve("delve-config-v3-"+ProcessHandle.current().pid()+".txt");
        try(PrintWriter out=new PrintWriter(Files.newBufferedWriter(report,StandardOpenOption.CREATE_NEW))){
            try {
                need(System.getProperty("user.home").equals("C:\\SandboxGuard\\first-game-v1\\profile"),"isolated profile");
                ClassLoader system=ClassLoader.getSystemClassLoader();
                Class<?> mt=Class.forName("c.d.c.m.z",false,system),hub=Class.forName("c.d.c.h.c",false,system),pt=Class.forName("c.d.c.m.h.j",false,system),ct=Class.forName("c.d.c.m.h.a",false,system),baseConfig=Class.forName("c.d.c.d.l",false,system);
                Object manager=field(hub,"n").get(null);
                List<?> registered=(List<?>)field(mt,"r").get(manager),running=(List<?>)field(mt,"s").get(manager);
                Set<Object> registeredBefore=identities(registered),runningBefore=identities(running);
                Object target=null;for(Object p:registeredBefore)if(p.getClass().getName().equals(ENTRY)){need(target==null,"duplicate Delve");target=p;}need(target!=null,"Delve registration missing");
                Object plugin=target;
                String origin=plugin.getClass().getProtectionDomain().getCodeSource().getLocation().toURI().toString();
                need(origin.endsWith("/detuks-delve_d3257b0eb6b3580979336c796b06b15068e7b0b8b6d76011b2da0c595290e96c.jar"),"Delve candidate origin");
                FutureTask<Void> task=new FutureTask<>(()->{
                    Object panel=find(pt);need(panel!=null,"visible plugin list panel");need(field(pt,"pluginManager").get(panel)==manager,"panel manager");
                    Class<?> rt=Class.forName("c.d.c.m.h.f",false,system);
                    Object config=null;int found=0;for(Object row:(List<?>)field(pt,"pluginList").get(panel)){Object c=field(rt,"pluginConfig").get(row);if(field(ct,"f").get(c)==plugin){config=c;found++;}}
                    need(found==1,"Delve row count");Object proxy=field(ct,"g").get(config),descriptor=field(ct,"j").get(config);need(proxy!=null&&descriptor!=null,"Delve config proxy/descriptor");
                    Class<?> iface=Class.forName(CONFIG,false,plugin.getClass().getClassLoader());need(iface.isInstance(proxy),"Delve configuration type");
                    @SuppressWarnings("unchecked") Class<? extends Annotation> groupType=(Class<? extends Annotation>)Class.forName("c.d.c.d.o",false,system);
                    @SuppressWarnings("unchecked") Class<? extends Annotation> itemType=(Class<? extends Annotation>)Class.forName("c.d.c.d.q",false,system);
                    need(GROUP.equals(groupType.getMethod("value").invoke(iface.getAnnotation(groupType))),"Delve config group");
                    Map<String,Method> methods=new TreeMap<>();for(Method m:iface.getMethods()){Annotation a=m.getAnnotation(itemType);if(a!=null){String key=(String)itemType.getMethod("N9").invoke(a);need(KEYS.contains(key)&&m.isDefault()&&m.getParameterCount()==0,"reviewed default method");need(methods.put(key,m)==null,"duplicate config key");}}
                    need(methods.keySet().equals(KEYS),"complete Delve config key set");
                    Object configManager=field(pt,"configManager").get(panel);Class<?> cm=configManager.getClass();Method read=cm.getMethod("Wr",String.class,String.class);
                    Map<String,String> before=values(configManager,read);long missing=before.values().stream().filter(Objects::isNull).count();
                    out.println("CONFIG_ITEMS="+KEYS.size());out.println("MISSING_DEFAULTS_BEFORE="+missing);out.flush();
                    cm.getMethod("WN",baseConfig,boolean.class).invoke(configManager,proxy,false);
                    Map<String,String> after=values(configManager,read);need(existingPreserved(before,after),"existing settings changed");
                    for(Map.Entry<String,Method> e:methods.entrySet()){
                        String value=after.get(e.getKey());need(value!=null,"missing default: "+e.getKey());Class<?> type=e.getValue().getReturnType();
                        if(type.isEnum()){@SuppressWarnings({"rawtypes","unchecked"}) Object choice=Enum.valueOf((Class)type,value);need(choice!=null,"enum setting");}
                    }
                    out.println("MISSING_DEFAULTS_AFTER=0");out.println("EXISTING_SETTINGS_PRESERVED=true");
                    // Exercise the exact settings-open route used by the row's cog.
                    Method open=pt.getDeclaredMethod("VT",ct);open.setAccessible(true);open.invoke(panel,config);
                    Class<?> settingsType=Class.forName("c.d.c.m.h.g",false,system);Component settings=find(settingsType);need(settings!=null,"settings panel attached");
                    int combos=0,spinners=0,buttons=0;ArrayDeque<Component> q=new ArrayDeque<>();q.add(settings);
                    while(!q.isEmpty()){Component c=q.removeFirst();if(c instanceof JComboBox){combos++;need(((JComboBox<?>)c).getSelectedItem()!=null,"dropdown selection missing");}if(c instanceof JSpinner)spinners++;if(c instanceof AbstractButton)buttons++;if(c instanceof Container)q.addAll(Arrays.asList(((Container)c).getComponents()));}
                    need(combos>=1&&spinners>=1&&buttons>=1,"settings controls missing");
                    out.println("SETTINGS_PANEL_OPENED=true");out.println("SETTINGS_CONTROLS=combos:"+combos+",spinners:"+spinners+",buttons:"+buttons);
                    need(identities(registered).equals(registeredBefore)&&identities(running).equals(runningBefore),"plugin lifecycle changed");
                    out.println("PLUGIN_IDENTITIES_AND_RUNNING_SET_UNCHANGED=true");return null;
                });
                if(SwingUtilities.isEventDispatchThread())task.run();else SwingUtilities.invokeLater(task);try{task.get(30,TimeUnit.SECONDS);}catch(TimeoutException timeout){task.cancel(false);throw timeout;}
                out.println("PLUGIN_START_REQUESTED=false");out.println("RESULT=0");return 0;
            }catch(Throwable e){while(e.getCause()!=null&&(e instanceof InvocationTargetException||e instanceof ExecutionException||e instanceof RuntimeException))e=e.getCause();out.println("ERROR_TYPE="+e.getClass().getName());out.println("ERROR_MESSAGE="+String.valueOf(e.getMessage()).replace('\n',' '));out.println("PLUGIN_START_REQUESTED=false");out.println("RESULT=72");return 72;}
        }
    }
    public static void main(String[] args){Map<String,String> before=new HashMap<>(),after=new HashMap<>();before.put("saved","user");before.put("missing",null);after.put("saved","user");after.put("missing","default");need(existingPreserved(before,after),"missing-only fixture");after.put("saved","reset");need(!existingPreserved(before,after),"overwrite rejection fixture");need(KEYS.size()==12&&!KEYS.contains("enabled"),"configuration scope");System.out.println("DELVE_CONFIG_FIXTURE=PASS checks=3");}
}

