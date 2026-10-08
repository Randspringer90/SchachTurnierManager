/* Startup diagnostics only: no API probe, storage access, or automatic reload. */
(() => {
  'use strict';
  const root = document.getElementById('root');
  const panel = document.getElementById('stm-startup-status');
  const heading = document.getElementById('stm-startup-heading');
  const message = document.getElementById('stm-startup-message');
  if (!root || !panel || !heading || !message || panel.dataset.guardInstalled) return;
  panel.dataset.guardInstalled = 'true';

  let complete = false;
  let timeout;
  let observer;
  const hasAppContent = () => root.childElementCount > 0;

  function finish() {
    if (complete) return;
    complete = true;
    panel.hidden = true;
    panel.dataset.state = 'mounted';
    window.clearTimeout(timeout);
    if (observer) observer.disconnect();
    window.removeEventListener('error', onError, true);
    window.removeEventListener('unhandledrejection', showRecovery);
    window.removeEventListener('load', checkMount);
  }

  function checkMount() {
    if (hasAppContent()) finish();
  }

  function showRecovery() {
    if (complete) return;
    if (hasAppContent()) { finish(); return; }
    // Never display error messages, URLs, stack traces or rejection values.
    heading.textContent = 'Die Anwendung ist noch nicht gestartet.';
    message.textContent = 'Pr\u00fcfe die Verbindung zum Turnierrechner und lade die Startseite bei Bedarf erneut. Es wurden durch diese Starthilfe keine Turnierdaten ge\u00e4ndert.';
    panel.dataset.state = 'recovery';
  }

  function onError(event) {
    // A failed image or stylesheet alone does not establish a failed app start.
    const target = event.target;
    if (target && target !== window && target !== document && target.tagName !== 'SCRIPT') return;
    showRecovery();
  }

  if (hasAppContent()) { finish(); return; }
  panel.hidden = false;
  panel.dataset.state = 'loading';
  window.addEventListener('error', onError, true);
  window.addEventListener('unhandledrejection', showRecovery);
  window.addEventListener('load', checkMount);
  if (typeof MutationObserver === 'function') {
    observer = new MutationObserver(checkMount);
    observer.observe(root, { childList: true });
  }
  timeout = window.setTimeout(showRecovery, 15000);
  // Covers a mount between the initial observation and listener installation.
  checkMount();
})();
