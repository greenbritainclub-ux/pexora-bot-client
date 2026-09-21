package ai.pexora.localboot;

import java.io.*;
import java.lang.reflect.*;
import java.net.*;
import java.nio.file.*;
import java.security.*;
import java.util.*;
import java.util.function.BiConsumer;
import java.util.jar.*;

/** Delve-only, stopped registration probe for the pinned V113 DT1 runtime. */
public final class DelveNoStartV55 {
    static final Path PROFILE = Path.of("C:\\SandboxGuard\\first-game-v1\\profile");
    static final Path JAR = Path.of("C:\\SandboxGuard\\first-game-v1\\profile\\.detuksosrs\\plugin-hub\\detuks-delve_d3257b0eb6b3580979336c796b06b15068e7b0b8b6d76011b2da0c595290e96c.jar");
    static final Path REPORT_ROOT = Path.of("C:\\CanaryLogs\\delve-dt1-v1");
    static final String ENTRY = "com.a.g.a.b.a.DelvePlugin";
    static final String HASH = "d3257b0eb6b3580979336c796b06b15068e7b0b8b6d76011b2da0c595290e96c";

    static void need(boolean ok, String message) { if (!ok) throw new IllegalStateException(message); }
    static Field field(Class<?> type, String name, Class<?> expected) throws Exception {
        Field f = type.getDeclaredField(name); need(f.getType() == expected, name + " type"); f.setAccessible(true); return f;
    }
    static String hash(Path p) throws Exception {
        MessageDigest d = MessageDigest.getInstance("SHA-256");
        try (InputStream in = Files.newInputStream(p)) { byte[] b = new byte[65536]; for (int n; (n = in.read(b)) != -1;) d.update(b, 0, n); }
        StringBuilder s = new StringBuilder(); for (byte b : d.digest()) s.append(String.format("%02x", b & 255)); return s.toString();
    }
    static Set<Object> identities(Collection<?> values) {
        Set<Object> out = Collections.newSetFromMap(new IdentityHashMap<>()); out.addAll(values); return out;
    }
    static int count(Collection<?> values, Object target) { int n = 0; for (Object v : values) if (v == target) n++; return n; }
    static void rebuildAndCheck(Object manager, Class<?> managerType, Class<?> base, Object plugin, PrintWriter out) throws Exception {
        ClassLoader system = ClassLoader.getSystemClassLoader();
        Class<?> panelType = Class.forName("c.d.c.m.h.j", false, system);
        Object panel = null;
        for (java.awt.Window w : java.awt.Window.getWindows()) {
            if (panelType.isInstance(w)) { panel = w; break; }
            if (w instanceof java.awt.Container) {
                ArrayDeque<java.awt.Component> q = new ArrayDeque<>(); q.add(w);
                while (!q.isEmpty()) { java.awt.Component c = q.removeFirst(); if (panelType.isInstance(c)) { panel = c; break; } if (c instanceof java.awt.Container) for (java.awt.Component child : ((java.awt.Container)c).getComponents()) q.add(child); }
            }
            if (panel != null) break;
        }
        need(panel != null, "plugin panel not found");
        Method refresh = panelType.getMethod("VM");
        final Object panelFinal = panel;
        if (!javax.swing.SwingUtilities.isEventDispatchThread()) javax.swing.SwingUtilities.invokeAndWait(() -> { try { refresh.invoke(panelFinal); } catch (Throwable e) { throw new RuntimeException(e); } }); else refresh.invoke(panelFinal);
        Class<?> rowType = Class.forName("c.d.c.m.h.f", false, system), configType = Class.forName("c.d.c.m.h.a", false, system);
        Field rowsField = field(panelType, "pluginList", List.class), configField = field(rowType, "pluginConfig", configType), refField = field(configType, "f", base);
        int found = 0; Object rows = rowsField.get(panel); need(rows instanceof List<?>, "plugin rows");
        for (Object row : (List<?>) rows) if (row != null && row.getClass() == rowType && refField.get(configField.get(row)) == plugin) found++;
        out.println("ROW_VISIBLE=detuks-delve;count=" + found); need(found == 1, "Delve row not visible after rebuild");
    }

    public static int inspect() throws Exception {
        Files.createDirectories(REPORT_ROOT);
        Path report = REPORT_ROOT.resolve("delve-test-v55-" + ProcessHandle.current().pid() + ".txt");
        try (PrintWriter out = new PrintWriter(Files.newBufferedWriter(report, StandardOpenOption.CREATE_NEW))) {
            String phase = "preflight";
            try {
                phase="profile";need(System.getProperty("user.home").equals(PROFILE.toString()), "isolated profile");
                phase="archive";need(Files.isRegularFile(JAR) && hash(JAR).equals(HASH), "Delve candidate hash");
                phase="manager-types";ClassLoader system = ClassLoader.getSystemClassLoader();
                Class<?> hub = Class.forName("c.d.c.h.c", false, system);Class<?> managerType = Class.forName("c.d.c.m.z", false, system);Class<?> base = Class.forName("c.d.c.m.v", false, system);
                phase="manager-instance";Object manager = field(hub, "n", managerType).get(null); need(manager != null, "plugin manager");
                phase="manager-lists";
                @SuppressWarnings("unchecked") List<Object> registered = (List<Object>) field(managerType, "r", List.class).get(manager);
                @SuppressWarnings("unchecked") List<Object> running = (List<Object>) field(managerType, "s", List.class).get(manager);
                Set<Object> runningBefore = identities(running);phase="manager-duplicate";
                for (Object existing : new ArrayList<>(registered)) need(existing == null || !existing.getClass().getName().equals(ENTRY), "Delve already registered");
                phase = "descriptor";
                Class<?> descriptor = Class.forName("c.d.c.h.g$a", false, system);
                Class<?> loaderType = Class.forName("c.d.c.h.j", false, system);
                Class<?> gson = Class.forName("com.google.gson.Gson", false, system);
                Object meta = descriptor.getDeclaredConstructor().newInstance();
                field(descriptor, "internalName", String.class).set(meta, "detuks-delve");
                field(descriptor, "displayName", String.class).set(meta, "Detuks Delve (local test)");
                field(descriptor, "jarHash", String.class).set(meta, HASH);
                field(descriptor, "jarSize", int.class).setInt(meta, (int) Files.size(JAR));
                field(descriptor, "version", String.class).set(meta, "pexora-delve-v42");
                phase = "loader";
                ClassLoader loader = (ClassLoader) loaderType.getConstructor(descriptor, URL[].class, gson)
                    .newInstance(meta, new URL[] { JAR.toUri().toURL() }, gson.getConstructor().newInstance());
                need(loader.getClass() == loaderType, "exact loader");
                phase = "definitions";
                int classes = 0, errors = 0; Class<?> entry = null;
                try (JarFile z = new JarFile(JAR.toFile(), false)) {
                    Enumeration<JarEntry> en = z.entries();
                    while (en.hasMoreElements()) {
                        JarEntry e = en.nextElement(); if (e.isDirectory() || !e.getName().endsWith(".class") || e.getName().startsWith("META-INF/")) continue;
                        classes++; String name = e.getName().substring(0, e.getName().length() - 6).replace('/', '.');
                        try { Class<?> c = Class.forName(name, false, loader); if (name.equals(ENTRY)) entry = c; }
                        catch (LinkageError | ClassNotFoundException failure) { errors++; if (errors <= 12) out.println("CLASS_FAILURE\t" + name + "\t" + failure.getClass().getName()); }
                    }
                }
                need(entry != null, "Delve entry class missing");
                need(errors == 0, "Delve definition/link failures=" + errors);
                need(base.isAssignableFrom(entry), "entry is not a plugin");
                need(identities(running).equals(runningBefore), "running state changed before registration");
                out.println("DEFINITIONS\tdetuks-delve\tclasses=" + classes + "\terrors=" + errors + "\tentry=true");
                phase = "registration";
                @SuppressWarnings("unchecked") List<Object> made = (List<Object>) managerType.getMethod("VG", List.class, BiConsumer.class)
                    .invoke(manager, Collections.singletonList(entry), null);
                need(made.size() == 1 && made.get(0).getClass() == entry, "registration result");
                Object plugin = made.get(0);
                need(count(registered, plugin) == 1 && count(running, plugin) == 0, "stopped registration state");
                need(identities(running).equals(runningBefore), "running state changed by registration");
                out.println("REGISTERED\tdetuks-delve\tinstances=1\tstarted=false");
                entry.getDeclaredMethod("VQ"); entry.getDeclaredMethod("VN");
                managerType.getMethod("V5",base,boolean.class).invoke(manager,plugin,false);
                need(identities(running).equals(runningBefore),"default-disable changed running state");
                rebuildAndCheck(manager, managerType, base, plugin, out);
                out.println("LIFECYCLE_CONTRACT=DT1_START_VQ_STOP_VN");out.flush();
                need(DelveConfigV3.inspect()==0,"Delve configuration initialization failed; see config-v3 report");
                out.println("SETTINGS_INITIALIZED=true");
                out.println("PLUGIN_START_REQUESTED=false");
                out.println("SUMMARY\trequested=1\tregistered=1\tstarted=0\tdefinitionFailures=0");
                out.println("RESULT=0"); out.flush(); return 0;
            } catch (Throwable failure) {
                // The sidebar refresh is invoked on the EDT and can be wrapped
                // twice.  Preserve the concrete cause for a non-mutating
                // diagnosis instead of reporting only InvocationTargetException.
                while ((failure instanceof InvocationTargetException || failure instanceof RuntimeException) && failure.getCause() != null) failure = failure.getCause();
                out.println("FAILED_PHASE=" + phase); out.println("ERROR_TYPE=" + failure.getClass().getName());
                out.println("ERROR_MESSAGE=" + String.valueOf(failure.getMessage()).replace('\n', ' '));
                int code="profile".equals(phase)?81:"archive".equals(phase)?82:"manager-types".equals(phase)?83:"manager-instance".equals(phase)?84:"manager-lists".equals(phase)?85:"manager-duplicate".equals(phase)?86:"descriptor".equals(phase)?87:"loader".equals(phase)?88:"definitions".equals(phase)?89:"registration".equals(phase)?90:91;
                out.println("PLUGIN_START_REQUESTED=false"); out.println("RESULT="+code); out.flush(); return code;
            }
        }
    }
    public static void main(String[] args) throws Exception { System.out.println("DELVE_NO_START_FIXTURE=PASS"); }
}

