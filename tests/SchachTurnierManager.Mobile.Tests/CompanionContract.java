package io.github.randspringer90.schachturniermanager;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetAddress;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;

/** Independent vectors; no Android SDK, network, credentials or model calls. */
public final class CompanionContract {
    private static int assertions;
    private interface Action { void run() throws Exception; }

    private static void check(boolean condition) {
        assertions++;
        if (!condition) throw new AssertionError("COMPANION_CONTRACT_FAILURE_" + assertions);
    }
    private static void rejects(Action action) throws Exception {
        boolean rejected = false;
        try { action.run(); }
        catch (IllegalArgumentException | IOException failure) { rejected = true; }
        check(rejected);
    }
    private static InputStream bytes(String text) {
        return new ByteArrayInputStream(text.getBytes(StandardCharsets.UTF_8));
    }

    public static void main(String[] arguments) throws Exception {
        String[] allowed = {"http://192.168.0.10:5088", "10.0.0.1:5088", "127.0.0.2",
            "localhost", "https://PC.local/", "http://169.254.1.2", "http://[::1]:5088",
            "http://172.16.0.1", "http://172.31.255.254"};
        for (String value : allowed) check(CompanionPolicy.parseOrigin(value) != null);
        String[] denied = {"", "http://8.8.8.8", "https://public.example", "http://user:pass@10.0.0.1",
            "http://10.0.0.1@8.8.8.8", "file:///etc/passwd", "content://local/item",
            "javascript:alert(1)", "intent://localhost", "http://172.15.0.1", "http://172.32.0.1",
            "http://192.169.0.1", "http://169.253.1.1", "http://10.0.0.256", "http://010.0.0.1",
            "http://0x7f000001", "http://2130706433", "http://multi.label.local",
            "http://pc.local.example", "http://pc.local.", "http://-pc.local", "http://pc-.local",
            "http://10.0.0.1:0", "http://10.0.0.1:65536", "http://10.0.0.1/path",
            "http://10.0.0.1/?secret=1", "http://10.0.0.1/#token", "http://[2001:db8::1]",
            "http://[::ffff:127.0.0.1]", "http://10.0.0.1\\public.example"};
        for (String value : denied) rejects(() -> CompanionPolicy.parseOrigin(value));
        for (int subnet = 16; subnet <= 31; subnet++) check(CompanionPolicy.isLocalHost("172." + subnet + ".1.1"));

        CompanionPolicy.Origin selected = CompanionPolicy.parseOrigin("HTTP://192.168.0.10:5088/");
        check(selected.value.equals("http://192.168.0.10:5088"));
        check(selected.healthUri().toString().equals("http://192.168.0.10:5088/api/health"));
        check(selected.permits("http://192.168.0.10:5088/api/tournaments"));
        check(selected.permits("http://192.168.0.10:5088/assets/index.js"));
        String preview = selected.value + "/api/tournaments/12345678-1234-1234-1234-123456789abc/pairings/preview-next-round";
        check(CompanionPolicy.resourceTimeoutMillis(preview) == 130000);
        check(CompanionPolicy.resourceTimeoutMillis(preview + "/export.csv") == 130000);
        check(CompanionPolicy.resourceTimeoutMillis(preview + "/print/html") == 130000);
        check(CompanionPolicy.resourceTimeoutMillis(selected.value + "/api/health") == 5000);
        check(CompanionPolicy.resourceTimeoutMillis(selected.value + "/api/tournaments") == 15000);
        check(CompanionPolicy.resourceTimeoutMillis(selected.value + "/assets/index.js") == 5000);
        check(CompanionPolicy.resourceTimeoutMillis(preview + "/unexpected") == 15000);
        for (String target : new String[]{"https://192.168.0.10:5088/", "http://192.168.0.11:5088/",
                "http://192.168.0.10:5089/", "http://user@192.168.0.10:5088/",
                "file:///data", "content://data", "intent://data", "javascript:alert(1)", "//192.168.0.10:5088/"}) {
            check(!selected.permits(target));
        }
        check(CompanionPolicy.parseOrigin("http://127.0.0.1:80").equals(CompanionPolicy.parseOrigin("127.0.0.1")));
        check(CompanionPolicy.parseOrigin("https://localhost:443").equals(CompanionPolicy.parseOrigin("https://localhost")));
        check(CompanionPolicy.isPrivateAddress(InetAddress.getByAddress(new byte[]{10, 0, 0, 1})));
        check(!CompanionPolicy.isPrivateAddress(InetAddress.getByAddress(new byte[]{8, 8, 8, 8})));
        check(!CompanionPolicy.isPrivateAddress(InetAddress.getByAddress(new byte[]{(byte)172, 32, 0, 1})));

        check(CompanionPolicy.healthVersion("SchachTurnierManager", "ok", true, "1.2.3").equals("1.2.3"));
        check(CompanionPolicy.healthVersion("SchachTurnierManager", "ok", true, "1.2.3-test").equals("1.2.3-test"));
        rejects(() -> CompanionPolicy.healthVersion("Other", "ok", true, "1.2.3"));
        rejects(() -> CompanionPolicy.healthVersion("SchachTurnierManager", "starting", true, "1.2.3"));
        rejects(() -> CompanionPolicy.healthVersion("SchachTurnierManager", "ok", false, "1.2.3"));
        rejects(() -> CompanionPolicy.healthVersion("SchachTurnierManager", "ok", null, "1.2.3"));
        rejects(() -> CompanionPolicy.healthVersion("SchachTurnierManager", "ok", "true", "1.2.3"));
        rejects(() -> CompanionPolicy.healthVersion("SchachTurnierManager", "ok", true, null));
        rejects(() -> CompanionPolicy.healthVersion("SchachTurnierManager", "ok", true, "<script>"));
        rejects(() -> CompanionPolicy.healthVersion("SchachTurnierManager", "ok", true, "1.2.3\n"));
        CompanionPolicy.requireJsonMediaType("application/json; charset=utf-8");
        CompanionPolicy.requireJsonMediaType("APPLICATION/JSON");
        for (String mime : new String[]{"text/html", "application/jsonp", "", "application/octet-stream"}) {
            rejects(() -> CompanionPolicy.requireJsonMediaType(mime));
        }
        rejects(() -> CompanionPolicy.requireJsonMediaType(null));

        HealthReplyReader.Guard okay = () -> {};
        String unicode = "{\"version\":\"1.2.3\",\"text\":\"Größe ♞\"}";
        byte[] encoded = unicode.getBytes(StandardCharsets.UTF_8);
        check(HealthReplyReader.read(new ByteArrayInputStream(encoded), encoded.length, okay).equals(unicode));
        check(HealthReplyReader.read(new ByteArrayInputStream(encoded), -1, okay).equals(unicode));
        byte[] max = new byte[HealthReplyReader.MAX_BODY_BYTES];
        Arrays.fill(max, (byte)' ');
        check(HealthReplyReader.read(new ByteArrayInputStream(max), max.length, okay).length() == max.length);
        rejects(() -> HealthReplyReader.read(new ByteArrayInputStream(new byte[16385]), -1, okay));
        rejects(() -> HealthReplyReader.read(bytes("{}"), 16385, okay));
        rejects(() -> HealthReplyReader.read(bytes("{}"), -2, okay));
        rejects(() -> HealthReplyReader.read(bytes("{}"), 3, okay));
        rejects(() -> HealthReplyReader.read(new ByteArrayInputStream(new byte[]{(byte)255}), -1, okay));
        rejects(() -> HealthReplyReader.read(bytes("{}"), -1, () -> { throw new IOException("CANCELLED"); }));
        int[] checkpoints = {0};
        rejects(() -> HealthReplyReader.read(bytes("{}"), -1, () -> {
            if (++checkpoints[0] == 2) throw new IOException("TIMEOUT");
        }));
        check(checkpoints[0] == 2);

        HealthReplyReader.requireObjectEnvelope("{}");
        HealthReplyReader.requireObjectEnvelope("{\"nested\":{\"values\":[1,2]},\"text\":\"{}[]\"}");
        for (String invalid : new String[]{"", "[]", "{} {}", "{", "{]", "{\"x\":\"unterminated}"}) {
            rejects(() -> HealthReplyReader.requireObjectEnvelope(invalid));
        }
        String deep = "{}";
        for (int i = 0; i < 16; i++) deep = "{\"n\":" + deep + "}";
        final String tooDeep = deep;
        rejects(() -> HealthReplyReader.requireObjectEnvelope(tooDeep));
        System.out.println("COMPANION_CONTRACT_PASS assertions=" + assertions);
    }
}
