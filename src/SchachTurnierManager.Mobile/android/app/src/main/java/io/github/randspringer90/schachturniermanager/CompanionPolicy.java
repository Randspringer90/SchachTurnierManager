package io.github.randspringer90.schachturniermanager;

import java.net.InetAddress;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.Locale;

/** Pure, dependency-free policy used by native health checks and WebView navigation. */
public final class CompanionPolicy {
    private CompanionPolicy() {}

    public static final class Origin {
        public final String scheme;
        public final String host;
        public final int port;
        public final String value;

        private Origin(String scheme, String host, int port) throws URISyntaxException {
            this.scheme = scheme;
            this.host = host;
            this.port = port;
            int shownPort = (scheme.equals("http") && port == 80)
                || (scheme.equals("https") && port == 443) ? -1 : port;
            this.value = new URI(scheme, null, host, shownPort, null, null, null).toASCIIString();
        }

        public URI healthUri() { return URI.create(value + "/api/health"); }

        public boolean permits(String target) {
            try {
                URI uri = new URI(target);
                if (uri.getRawUserInfo() != null || uri.getHost() == null) return false;
                String targetHost = unwrap(uri.getHost()).toLowerCase(Locale.ROOT);
                String targetScheme = uri.getScheme() == null ? "" : uri.getScheme().toLowerCase(Locale.ROOT);
                int targetPort = effectivePort(targetScheme, uri.getPort());
                return scheme.equals(targetScheme) && host.equals(targetHost) && port == targetPort;
            } catch (RuntimeException | URISyntaxException failure) { return false; }
        }

        @Override public boolean equals(Object other) {
            return other instanceof Origin && value.equals(((Origin) other).value);
        }
        @Override public int hashCode() { return value.hashCode(); }
    }

    public static Origin parseOrigin(String raw) {
        if (raw == null || raw.length() > 2048) throw new IllegalArgumentException("INVALID_ORIGIN");
        String value = raw.trim();
        if (!value.matches("(?i)^https?://.*")) value = "http://" + value;
        try {
            URI uri = new URI(value);
            String scheme = uri.getScheme().toLowerCase(Locale.ROOT);
            if (!scheme.equals("http") && !scheme.equals("https")) throw new IllegalArgumentException("INVALID_ORIGIN");
            if (uri.getRawUserInfo() != null || uri.getHost() == null
                    || uri.getRawQuery() != null || uri.getRawFragment() != null) {
                throw new IllegalArgumentException("INVALID_ORIGIN");
            }
            String path = uri.getRawPath();
            if (path != null && !path.isEmpty() && !path.equals("/")) throw new IllegalArgumentException("INVALID_ORIGIN");
            String host = unwrap(uri.getHost()).toLowerCase(Locale.ROOT);
            if (!isLocalHost(host)) throw new IllegalArgumentException("INVALID_ORIGIN");
            int port = effectivePort(scheme, uri.getPort());
            if (port < 1 || port > 65535) throw new IllegalArgumentException("INVALID_ORIGIN");
            return new Origin(scheme, host, port);
        } catch (RuntimeException | URISyntaxException failure) {
            throw new IllegalArgumentException("INVALID_ORIGIN");
        }
    }

    private static int effectivePort(String scheme, int port) {
        if (port != -1) return port;
        if (scheme.equals("http")) return 80;
        if (scheme.equals("https")) return 443;
        return -2;
    }

    private static String unwrap(String host) {
        return host.startsWith("[") && host.endsWith("]") ? host.substring(1, host.length() - 1) : host;
    }

    public static boolean isLocalHost(String host) {
        if (host == null) return false;
        host = unwrap(host).toLowerCase(Locale.ROOT);
        if (host.equals("localhost") || host.equals("::1")) return true;
        if (host.matches("[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.local")) return true;
        String[] parts = host.split("\\.", -1);
        if (parts.length != 4) return false;
        int[] numbers = new int[4];
        for (int i = 0; i < 4; i++) {
            if (!parts[i].matches("(?:0|[1-9][0-9]{0,2})")) return false;
            numbers[i] = Integer.parseInt(parts[i]);
            if (numbers[i] > 255) return false;
        }
        return numbers[0] == 10 || numbers[0] == 127
            || (numbers[0] == 169 && numbers[1] == 254)
            || (numbers[0] == 172 && numbers[1] >= 16 && numbers[1] <= 31)
            || (numbers[0] == 192 && numbers[1] == 168);
    }

    /** DNS answers for local names must all remain private; never accept a public fallback. */
    public static boolean isPrivateAddress(InetAddress address) {
        byte[] bytes = address.getAddress();
        if (bytes.length == 4) {
            String host = (bytes[0] & 255) + "." + (bytes[1] & 255) + "."
                + (bytes[2] & 255) + "." + (bytes[3] & 255);
            return isLocalHost(host);
        }
        return address.isLoopbackAddress() || address.isLinkLocalAddress()
            || address.isSiteLocalAddress() || (bytes.length == 16 && (bytes[0] & 254) == 252);
    }

    public static String healthVersion(Object app, Object status, Object embeddedDashboard, Object version) {
        if (!"SchachTurnierManager".equals(app) || !"ok".equals(status)
                || !Boolean.TRUE.equals(embeddedDashboard) || !(version instanceof String)) {
            throw new IllegalArgumentException("WRONG_SERVER");
        }
        String value = (String) version;
        if (value.length() > 80 || !value.matches("[0-9]+\\.[0-9]+\\.[0-9]+(?:[-+][A-Za-z0-9.-]+)?")) {
            throw new IllegalArgumentException("WRONG_SERVER");
        }
        return value;
    }

    public static int resourceTimeoutMillis(String target) {
        String path = URI.create(target).getPath();
        if (path.matches("(?i)^/api/tournaments/[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}/pairings/preview-next-round(?:/export\\.csv|/print/html)?$")) {
            return 130000;
        }
        return path.startsWith("/api/") && !path.equals("/api/health") ? 15000 : 5000;
    }

    public static void requireJsonMediaType(String mediaType) {
        if (mediaType == null || !mediaType.matches("(?i)^application/json(?:\\s*;[^\\r\\n]*)?$")) {
            throw new IllegalArgumentException("UNEXPECTED_REPLY");
        }
    }
}
