package io.github.randspringer90.schachturniermanager;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.Configuration;
import android.net.Uri;
import android.net.http.SslError;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.View;
import android.webkit.ClientCertRequest;
import android.webkit.CookieManager;
import android.webkit.GeolocationPermissions;
import android.webkit.HttpAuthHandler;
import android.webkit.PermissionRequest;
import android.webkit.SslErrorHandler;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;
import java.util.Locale;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.Future;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

/** Native launcher; the remote tournament page has no native JavaScript bridge. */
public final class MainActivity extends Activity {
    private final Handler ui = new Handler(Looper.getMainLooper());
    // A stuck platform DNS lookup cannot create an unbounded thread/task backlog.
    private final ThreadPoolExecutor worker = new ThreadPoolExecutor(1, 1, 0,
        TimeUnit.SECONDS, new ArrayBlockingQueue<Runnable>(1));
    private SharedPreferences preferences;
    private Context labels;
    private EditText server;
    private TextView status;
    private TextView serverVersion;
    private Button test;
    private Button connect;
    private NativeHealthClient.Result verified;
    private volatile CompanionPolicy.Origin selectedOrigin;
    private NativeHealthClient activeProbe;
    private Future<?> activeTask;
    private Runnable deadline;
    private WebView web;
    private int generation;
    private boolean destroyed;

    @Override public void onCreate(Bundle savedState) {
        super.onCreate(savedState);
        preferences = getSharedPreferences("companion", MODE_PRIVATE);
        String restored = savedState == null ? preferences.getString("server", "") : savedState.getString("server", "");
        showLauncher(restored);
    }

    private String text(int id) { return labels.getString(id); }
    private String text(int id, String value) { return labels.getString(id, value); }
    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }

    private void setLabels() {
        String fallback = Locale.getDefault().getLanguage().equals("de") ? "de" : "en";
        String language = preferences.getString("language", fallback);
        Configuration configuration = new Configuration(getResources().getConfiguration());
        configuration.setLocale(new Locale(language.equals("de") ? "de" : "en"));
        labels = createConfigurationContext(configuration);
    }

    private TextView label(String value, int size) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(size);
        view.setPadding(0, dp(8), 0, dp(8));
        return view;
    }

    private Button button(String title) {
        Button button = new Button(this);
        button.setText(title);
        button.setMinHeight(dp(52));
        return button;
    }

    private void showLauncher(String address) {
        cancelProbe();
        selectedOrigin = null;
        verified = null;
        if (web != null) {
            web.stopLoading();
            web.destroy();
            web = null;
        }
        setLabels();
        ScrollView scroll = new ScrollView(this);
        scroll.setFitsSystemWindows(true);
        scroll.setFillViewport(true);
        LinearLayout column = new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        column.setPadding(dp(20), dp(24), dp(20), dp(24));
        column.setBackgroundColor((getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK)
            == Configuration.UI_MODE_NIGHT_YES ? 0xff202124 : 0xfffafafa);
        scroll.addView(column);
        LinearLayout languages = new LinearLayout(this);
        languages.setGravity(Gravity.END);
        for (String language : new String[]{"de", "en"}) {
            Button choose = button(language.toUpperCase(Locale.ROOT));
            choose.setContentDescription(language.equals("de") ? "Deutsch" : "English");
            choose.setOnClickListener(view -> {
                String current = server.getText().toString();
                preferences.edit().putString("language", language).apply();
                showLauncher(current);
            });
            languages.addView(choose);
        }
        column.addView(languages);
        column.addView(label(text(R.string.title), 24));
        column.addView(label(text(R.string.subtitle), 16));
        TextView serverLabel = label(text(R.string.server_label), 18);
        column.addView(serverLabel);
        server = new EditText(this);
        server.setId(View.generateViewId());
        serverLabel.setLabelFor(server.getId());
        server.setSingleLine(true);
        server.setInputType(android.text.InputType.TYPE_CLASS_TEXT
            | android.text.InputType.TYPE_TEXT_VARIATION_URI);
        server.setMinHeight(dp(52));
        server.setHint("http://192.168.0.10:5088");
        server.setText(address);
        column.addView(server);
        column.addView(label(text(R.string.server_hint), 14));
        test = button(text(R.string.test));
        connect = button(text(R.string.connect));
        connect.setEnabled(false);
        column.addView(test);
        column.addView(connect);
        status = label("", 16);
        status.setAccessibilityLiveRegion(View.ACCESSIBILITY_LIVE_REGION_POLITE);
        column.addView(status);
        column.addView(label(text(R.string.app_version, BuildConfig.VERSION_NAME), 14));
        serverVersion = label(text(R.string.server_version, text(R.string.not_connected)), 14);
        column.addView(serverVersion);
        test.setOnClickListener(view -> beginProbe(false));
        connect.setOnClickListener(view -> beginProbe(true));
        server.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence value, int start, int count, int after) {}
            @Override public void onTextChanged(CharSequence value, int start, int before, int count) {
                cancelProbe();
                verified = null;
                connect.setEnabled(false);
                test.setEnabled(true);
                status.setText("");
                serverVersion.setText(text(R.string.server_version, text(R.string.not_connected)));
            }
            @Override public void afterTextChanged(Editable value) {}
        });
        setContentView(scroll);
    }

    private void cancelProbe() {
        generation++;
        if (deadline != null) ui.removeCallbacks(deadline);
        deadline = null;
        if (activeProbe != null) activeProbe.cancel();
        activeProbe = null;
        if (activeTask != null) activeTask.cancel(true);
        activeTask = null;
        worker.purge();
    }

    private void beginProbe(boolean opening) {
        CompanionPolicy.Origin input;
        try { input = CompanionPolicy.parseOrigin(server.getText().toString()); }
        catch (IllegalArgumentException invalid) {
            cancelProbe();
            verified = null;
            status.setText(text(R.string.invalid));
            connect.setEnabled(false);
            test.setEnabled(true);
            return;
        }
        final NativeHealthClient.Result previouslyVerified = verified;
        if (opening && (previouslyVerified == null || !input.equals(previouslyVerified.inputOrigin))) {
            status.setText(text(R.string.test_first));
            connect.setEnabled(false);
            return;
        }
        cancelProbe();
        verified = null;
        final int requestGeneration = generation;
        final NativeHealthClient probe = new NativeHealthClient();
        activeProbe = probe;
        test.setEnabled(false);
        connect.setEnabled(false);
        status.setText(text(opening ? R.string.rechecking : R.string.testing));
        deadline = () -> {
            if (destroyed || requestGeneration != generation) return;
            cancelProbe();
            verified = null;
            test.setEnabled(true);
            connect.setEnabled(false);
            status.setText(text(R.string.timeout));
        };
        ui.postDelayed(deadline, NativeHealthClient.DEADLINE_MS);
        try {
            activeTask = worker.submit(() -> {
                try {
                    NativeHealthClient.Result result = probe.probe(input);
                    ui.post(() -> finishProbe(requestGeneration, result, previouslyVerified, opening));
                } catch (Exception failure) {
                    String reason = failure.getMessage();
                    int message = "TIMEOUT".equals(reason) ? R.string.timeout
                        : "WRONG_SERVER".equals(reason) ? R.string.wrong_server
                        : "NETWORK_BLOCKED".equals(reason) ? R.string.blocked : R.string.failed;
                    ui.post(() -> failProbe(requestGeneration, message));
                }
            });
        } catch (RuntimeException busy) {
            failProbe(requestGeneration, R.string.failed);
        }
    }

    private void failProbe(int requestGeneration, int message) {
        if (destroyed || requestGeneration != generation || web != null) return;
        cancelProbe();
        verified = null;
        test.setEnabled(true);
        connect.setEnabled(false);
        status.setText(text(message));
    }

    private void finishProbe(int requestGeneration, NativeHealthClient.Result result,
            NativeHealthClient.Result previous, boolean opening) {
        if (destroyed || requestGeneration != generation || web != null) return;
        CompanionPolicy.Origin current;
        try { current = CompanionPolicy.parseOrigin(server.getText().toString()); }
        catch (IllegalArgumentException invalid) { failProbe(requestGeneration, R.string.invalid); return; }
        if (!current.equals(result.inputOrigin) || (opening
                && (previous == null || !previous.pinnedOrigin.equals(result.pinnedOrigin)))) {
            failProbe(requestGeneration, R.string.test_first);
            return;
        }
        cancelProbe();
        verified = result;
        test.setEnabled(true);
        connect.setEnabled(true);
        // Persist only a validated server origin and explicit language, never credentials.
        preferences.edit().putString("server", result.inputOrigin.value).apply();
        serverVersion.setText(text(R.string.server_version, result.version)
            + " · " + text(R.string.dashboard_ready) + "\n" + result.pinnedOrigin.value);
        status.setText(text(R.string.connected));
        if (opening) openDashboard(result.pinnedOrigin);
    }

    private void showBlocked() {
        ui.post(() -> { if (!destroyed) Toast.makeText(this, text(R.string.blocked), Toast.LENGTH_SHORT).show(); });
    }

    private void openDashboard(CompanionPolicy.Origin origin) {
        selectedOrigin = origin;
        LinearLayout column = new LinearLayout(this);
        column.setFitsSystemWindows(true);
        column.setOrientation(LinearLayout.VERTICAL);
        Button back = button(text(R.string.return_launcher));
        back.setOnClickListener(view -> showLauncher(preferences.getString("server", "")));
        column.addView(back);
        web = new WebView(this);
        WebSettings settings = web.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setAllowFileAccessFromFileURLs(false);
        settings.setAllowUniversalAccessFromFileURLs(false);
        settings.setGeolocationEnabled(false);
        settings.setJavaScriptCanOpenWindowsAutomatically(false);
        settings.setSupportMultipleWindows(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        CookieManager.getInstance().setAcceptCookie(false);
        CookieManager.getInstance().setAcceptThirdPartyCookies(web, false);
        web.setDownloadListener((url, userAgent, disposition, mimeType, length) -> showBlocked());
        web.setWebChromeClient(new WebChromeClient() {
            @Override public void onPermissionRequest(PermissionRequest request) { request.deny(); }
            @Override public void onGeolocationPermissionsShowPrompt(String origin,
                    GeolocationPermissions.Callback callback) { callback.invoke(origin, false, false); }
            @Override public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback,
                    FileChooserParams parameters) { callback.onReceiveValue(null); showBlocked(); return true; }
            @Override public boolean onCreateWindow(WebView view, boolean dialog, boolean gesture,
                    android.os.Message result) { showBlocked(); return false; }
        });
        web.setWebViewClient(new WebViewClient() {
            private boolean permits(String target) {
                return selectedOrigin != null && selectedOrigin.permits(target);
            }
            @Override public boolean shouldOverrideUrlLoading(WebView view, String target) {
                if (permits(target)) return false;
                showBlocked(); return true;
            }
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return shouldOverrideUrlLoading(view, request.getUrl().toString());
            }
            @Override public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                String target = request.getUrl().toString();
                String scheme = request.getUrl().getScheme();
                // QR/image data remains local; the page CSP limits which resource
                // kinds may use data/blob. Neither may become a top-level page.
                if (!request.isForMainFrame() && ("data".equals(scheme) || "blob".equals(scheme))) return null;
                if (!permits(target)) return OriginWebResources.denied();
                // GET redirects are blocked in the proxy. Non-GET WebApp actions
                // remain in the browser under the response's self-only CSP.
                return "GET".equals(request.getMethod())
                    ? OriginWebResources.get(selectedOrigin, target) : null;
            }
            @Override public void onPageStarted(WebView view, String target, android.graphics.Bitmap icon) {
                if (!permits(target)) { view.stopLoading(); showBlocked(); }
            }
            @Override public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {
                handler.cancel(); showBlocked();
            }
            @Override public void onReceivedHttpAuthRequest(WebView view, HttpAuthHandler handler,
                    String host, String realm) { handler.cancel(); showBlocked(); }
            @Override public void onReceivedClientCertRequest(WebView view, ClientCertRequest request) {
                request.cancel(); showBlocked();
            }
        });
        column.addView(web, new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 0, 1));
        setContentView(column);
        web.loadUrl(origin.value + "/");
    }

    @Override public void onSaveInstanceState(Bundle state) {
        if (server != null) state.putString("server", server.getText().toString());
        super.onSaveInstanceState(state);
    }

    @Override public void onBackPressed() {
        if (web != null) showLauncher(preferences.getString("server", ""));
        else super.onBackPressed();
    }

    @Override public void onStop() {
        cancelProbe();
        verified = null;
        if (connect != null) connect.setEnabled(false);
        if (test != null) test.setEnabled(true);
        super.onStop();
    }

    @Override public void onDestroy() {
        destroyed = true;
        cancelProbe();
        worker.shutdownNow();
        if (web != null) { web.stopLoading(); web.destroy(); web = null; }
        super.onDestroy();
    }
}
