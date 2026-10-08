package io.github.randspringer90.schachturniermanager;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;

/** Pure bounded reader; raw remote data never becomes an error message or a log. */
public final class HealthReplyReader {
    public static final int MAX_BODY_BYTES = 16384;
    public interface Guard { void check() throws IOException; }
    private HealthReplyReader() {}

    public static String read(InputStream input, long contentLength, Guard guard) throws IOException {
        if (contentLength < -1 || contentLength > MAX_BODY_BYTES) throw new IOException("UNEXPECTED_REPLY");
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] chunk = new byte[1024];
        for (;;) {
            guard.check();
            int count = input.read(chunk);
            guard.check();
            if (count == -1) break;
            if (count == 0) continue;
            if (output.size() + count > MAX_BODY_BYTES) throw new IOException("UNEXPECTED_REPLY");
            output.write(chunk, 0, count);
        }
        if (contentLength >= 0 && output.size() != contentLength) throw new IOException("UNEXPECTED_REPLY");
        try {
            return StandardCharsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(output.toByteArray())).toString();
        } catch (CharacterCodingException failure) { throw new IOException("UNEXPECTED_REPLY"); }
    }
    /** Bound parser depth and require exactly one object before Android JSON decoding. */
    public static void requireObjectEnvelope(String text) throws IOException {
        char[] stack = new char[16];
        int depth = 0;
        boolean quoted = false, escaped = false, started = false, finished = false;
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            if (quoted) {
                if (escaped) { escaped = false; continue; }
                if (c == '\\') { escaped = true; continue; }
                if (c == '"') quoted = false;
                else if (c < 0x20) throw new IOException("UNEXPECTED_REPLY");
                continue;
            }
            if (Character.isWhitespace(c)) continue;
            if (finished) throw new IOException("UNEXPECTED_REPLY");
            if (!started) {
                if (c != '{') throw new IOException("UNEXPECTED_REPLY");
                started = true;
            }
            if (c == '"') quoted = true;
            else if (c == '{' || c == '[') {
                if (depth >= stack.length) throw new IOException("UNEXPECTED_REPLY");
                stack[depth++] = c;
            } else if (c == '}' || c == ']') {
                if (depth == 0 || stack[depth - 1] != (c == '}' ? '{' : '[')) throw new IOException("UNEXPECTED_REPLY");
                depth--;
                if (depth == 0) finished = true;
            }
        }
        if (!started || !finished || quoted || depth != 0) throw new IOException("UNEXPECTED_REPLY");
    }

}
