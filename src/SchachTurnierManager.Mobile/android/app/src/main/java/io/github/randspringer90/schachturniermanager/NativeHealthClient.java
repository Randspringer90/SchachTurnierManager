package io.github.randspringer90.schachturniermanager;

import android.os.SystemClock;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.util.concurrent.atomic.AtomicBoolean;
import org.json.JSONObject;

/** One GET, no redirects/credentials, bounded reply, absolute UI/request deadline.
 * Local names are resolved to a private literal IP before connecting. The same
 * pinned origin is used by the WebView, so DNS rebinding cannot change its peer.
 * HTTPS always verifies the pinned IP against the system trust store.
 */
final class NativeHealthClient implements HealthReplyReader.Guard {
    static final long DEADLINE_MS = 5000;
    private final long deadline = SystemClock.elapsedRealtime() + DEADLINE_MS;
    private final AtomicBoolean cancelled = new AtomicBoolean(false);
    private volatile HttpURLConnection connection;

    static final class Result {
        final CompanionPolicy.Origin inputOrigin;
        final CompanionPolicy.Origin pinnedOrigin;
        final String version;
        Result(CompanionPolicy.Origin input, CompanionPolicy.Origin pinned, String version) {
            this.inputOrigin = input; this.pinnedOrigin = pinned; this.version = version;
        }
    }

    void cancel() {
        cancelled.set(true);
        HttpURLConnection active = connection;
        if (active != null) active.disconnect();
    }

    @Override public void check() throws IOException {
        if (cancelled.get() || Thread.currentThread().isInterrupted()) throw new IOException("CANCELLED");
        if (SystemClock.elapsedRealtime() >= deadline) throw new IOException("TIMEOUT");
        HttpURLConnection active = connection;
        if (active != null) active.setReadTimeout(remainingMillis());
    }

    private int remainingMillis() throws IOException {
        long remaining = deadline - SystemClock.elapsedRealtime();
        if (remaining <= 0) throw new IOException("TIMEOUT");
        return (int) Math.min(remaining, DEADLINE_MS);
    }

    private CompanionPolicy.Origin pin(CompanionPolicy.Origin input) throws IOException {
        check();
        InetAddress[] addresses = InetAddress.getAllByName(input.host);
        check();
        if (addresses.length == 0) throw new IOException("NETWORK_BLOCKED");
        InetAddress chosen = addresses[0];
        for (InetAddress address : addresses) {
            if (!CompanionPolicy.isPrivateAddress(address)) throw new IOException("NETWORK_BLOCKED");
            if (address.getAddress().length == 4) chosen = address;
        }
        String host = chosen.getHostAddress();
        if (chosen.getAddress().length == 16 && chosen.isLoopbackAddress()) host = "::1";
        // Scoped IPv6 would create a platform-dependent origin; use IPv4 or loopback.
        if (host == null || host.contains("%")) throw new IOException("NETWORK_BLOCKED");
        if (host.contains(":")) host = "[" + host + "]";
        try {
            return CompanionPolicy.parseOrigin(input.scheme + "://" + host + ":" + input.port);
        } catch (IllegalArgumentException invalid) { throw new IOException("NETWORK_BLOCKED"); }
    }

    Result probe(CompanionPolicy.Origin input) throws IOException {
        CompanionPolicy.Origin pinned = pin(input);
        HttpURLConnection http = (HttpURLConnection) pinned.healthUri().toURL().openConnection();
        connection = http;
        try {
            check();
            http.setRequestMethod("GET");
            http.setInstanceFollowRedirects(false);
            http.setUseCaches(false);
            http.setAllowUserInteraction(false);
            http.setConnectTimeout(remainingMillis());
            http.setReadTimeout(remainingMillis());
            http.setRequestProperty("Accept", "application/json");
            http.setRequestProperty("Cache-Control", "no-store");
            int status = http.getResponseCode();
            check();
            if (status < 200 || status >= 300) throw new IOException("UNEXPECTED_REPLY");
            CompanionPolicy.requireJsonMediaType(http.getHeaderField("Content-Type"));
            String declared = http.getHeaderField("Content-Length");
            long length = -1;
            if (declared != null) {
                if (!declared.matches("[0-9]+") || declared.length() > 10) throw new IOException("UNEXPECTED_REPLY");
                length = Long.parseLong(declared);
            }
            String text;
            try (InputStream body = http.getInputStream()) {
                text = HealthReplyReader.read(body, length, this);
            }
            check();
            HealthReplyReader.requireObjectEnvelope(text);
            JSONObject reply = new JSONObject(text);
            String version = CompanionPolicy.healthVersion(reply.opt("app"), reply.opt("status"),
                reply.opt("embeddedDashboard"), reply.opt("version"));
            check();
            return new Result(input, pinned, version);
        } catch (IOException failure) {
            throw failure;
        } catch (Exception malformed) {
            // Never disclose remote bodies, socket messages, URLs or parser diagnostics.
            throw new IOException("WRONG_SERVER");
        } finally {
            http.disconnect();
            connection = null;
        }
    }
}
