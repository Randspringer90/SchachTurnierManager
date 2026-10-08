package io.github.randspringer90.schachturniermanager;

import android.os.SystemClock;
import android.webkit.WebResourceResponse;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

/** GET-only resource proxy: no redirect is delegated to the WebView network stack.
 * CSP also confines browser-managed same-origin POST/fetch/WebSocket operations.
 */
final class OriginWebResources {
    private static final int MAX_RESOURCE_BYTES = 8 * 1024 * 1024;
    private static final String CSP = "default-src 'self'; script-src 'self'; "
        + "style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; "
        + "connect-src 'self'; child-src 'none'; worker-src 'none'; frame-src 'none'; object-src 'none'; "
        + "base-uri 'none'; form-action 'self'";

    private OriginWebResources() {}

    static WebResourceResponse denied() {
        return new WebResourceResponse("text/plain", "UTF-8", 403, "Forbidden",
            java.util.Collections.<String, String>emptyMap(),
            new ByteArrayInputStream("Blocked".getBytes(StandardCharsets.UTF_8)));
    }

    static WebResourceResponse get(CompanionPolicy.Origin selected, String target) {
        if (selected == null || !selected.permits(target)) return denied();
        HttpURLConnection connection = null;
        long deadline = SystemClock.elapsedRealtime() + CompanionPolicy.resourceTimeoutMillis(target);
        try {
            connection = (HttpURLConnection) URI.create(target).toURL().openConnection();
            connection.setRequestMethod("GET");
            connection.setInstanceFollowRedirects(false);
            connection.setUseCaches(false);
            connection.setAllowUserInteraction(false);
            connection.setConnectTimeout(Math.min(5000, remaining(deadline)));
            connection.setReadTimeout(remaining(deadline));
            connection.setRequestProperty("Accept", "*/*");
            connection.setRequestProperty("Accept-Encoding", "identity");
            int status = connection.getResponseCode();
            // No Location or Refresh can escape the selected origin.
            if (status >= 300 && status < 400) return denied();
            String type = connection.getHeaderField("Content-Type");
            if (type == null || type.contains("\r") || type.contains("\n")) type = "application/octet-stream";
            String mime = type.split(";", 2)[0].trim();
            String encoding = connection.getHeaderField("Content-Encoding");
            if (encoding != null && !encoding.equalsIgnoreCase("identity")) return denied();
            String declared = connection.getHeaderField("Content-Length");
            if (declared != null && (!declared.matches("[0-9]+") || declared.length() > 10
                    || Long.parseLong(declared) > MAX_RESOURCE_BYTES)) return denied();
            ByteArrayOutputStream body = new ByteArrayOutputStream();
            InputStream input = status >= 400 ? connection.getErrorStream() : connection.getInputStream();
            if (input != null) {
                try (InputStream stream = input) {
                    byte[] chunk = new byte[8192];
                    for (;;) {
                        connection.setReadTimeout(remaining(deadline));
                        int read = stream.read(chunk);
                        remaining(deadline);
                        if (read == -1) break;
                        if (body.size() + read > MAX_RESOURCE_BYTES) return denied();
                        body.write(chunk, 0, read);
                    }
                }
            }
            Map<String, String> headers = new HashMap<>();
            headers.put("Cache-Control", "no-store");
            headers.put("X-Content-Type-Options", "nosniff");
            String originalCsp = connection.getHeaderField("Content-Security-Policy");
            // Multiple CSP policies intersect; preserve a stricter backend policy.
            headers.put("Content-Security-Policy", originalCsp == null ? CSP : originalCsp + ", " + CSP);
            String disposition = connection.getHeaderField("Content-Disposition");
            if (disposition != null && !disposition.contains("\r") && !disposition.contains("\n")) {
                headers.put("Content-Disposition", disposition);
            }
            return new WebResourceResponse(mime, "UTF-8", status,
                status >= 200 && status < 300 ? "OK" : "Request failed", headers,
                new ByteArrayInputStream(body.toByteArray()));
        } catch (Exception failure) {
            // Fixed response only; no URL, socket error or remote body is logged.
            return denied();
        } finally {
            if (connection != null) connection.disconnect();
        }
    }

    private static int remaining(long deadline) throws IOException {
        long millis = deadline - SystemClock.elapsedRealtime();
        if (millis <= 0 || Thread.currentThread().isInterrupted()) throw new IOException("TIMEOUT");
        return (int) millis;
    }
}
