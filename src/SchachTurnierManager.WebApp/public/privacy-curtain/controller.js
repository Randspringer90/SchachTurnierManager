/** A visual curtain in this tab, never authentication, encryption or an OS lock. */
const installations = new WeakMap();
export function installPrivacyCurtain(document) {
  if (installations.has(document)) return installations.get(document);
  const root = document.getElementById('root');
  const controls = document.getElementById('stm-privacy-controls');
  const button = document.getElementById('stm-privacy-toggle');
  const status = document.getElementById('stm-privacy-status');
  if (!root || !controls || !button || !status) return () => {};
  let concealed = false, disposed = false, previousFocus = null;
  const originalDisabled = button.disabled;
  function show() {
    if (!concealed) return;
    concealed = false;
    root.removeAttribute('data-stm-concealed');
    root.removeAttribute('hidden');
    button.textContent = 'Turnieransicht ausblenden';
    button.setAttribute('aria-expanded', 'true');
    status.textContent = 'Die Turnieransicht wird wieder angezeigt.';
    if (previousFocus?.isConnected && root.contains(previousFocus)) {
      try { previousFocus.focus({ preventScroll: true }); } catch { /* Optional focus restoration. */ }
    }
    previousFocus = null;
  }
  function toggle() {
    if (disposed) return;
    if (concealed) { show(); return; }
    // Do not take ownership of a root hidden by a different feature.
    if (root.hasAttribute('hidden')) {
      status.textContent = 'Die Turnieransicht ist bereits anderweitig ausgeblendet.';
      return;
    }
    previousFocus = root.contains(document.activeElement) ? document.activeElement : null;
    root.setAttribute('data-stm-concealed', 'true');
    root.setAttribute('hidden', '');
    concealed = true;
    button.textContent = 'Turnieransicht anzeigen';
    button.setAttribute('aria-expanded', 'false');
    status.textContent = 'Nur die Ansicht in diesem Tab ist verborgen. Dies ist keine Zugangssperre; laufende Vorg\u00e4nge werden nicht angehalten.';
    try { button.focus({ preventScroll: true }); } catch { /* Hiding must still work. */ }
  }
  function dispose() {
    if (disposed) return;
    disposed = true;
    button.removeEventListener('click', toggle);
    show();
    button.disabled = originalDisabled;
    installations.delete(document);
  }
  button.addEventListener('click', toggle);
  button.disabled = false;
  button.setAttribute('aria-controls', 'root');
  button.setAttribute('aria-expanded', root.hasAttribute('hidden') ? 'false' : 'true');
  installations.set(document, dispose);
  return dispose;
}
