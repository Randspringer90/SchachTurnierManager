import { subscribeNetworkHint } from './state.js';

const messages = {
  de: {
    offline: 'Der Browser meldet offline. Pr\u00fcfe vor weiteren Eingaben den Backend-Status. Dieser Hinweis speichert oder synchronisiert keine Turnierdaten.',
    recovered: 'Der Browser meldet wieder ein Netzwerk. Ob das Backend erreichbar und alle Eingaben gespeichert sind, ist damit noch nicht best\u00e4tigt.',
    unknown: 'Der Netzwerkstatus ist nicht feststellbar. Pr\u00fcfe den Backend-Status; Speicherung und Synchronisierung sind durch diesen Hinweis nicht best\u00e4tigt.',
    dismiss: 'Hinweis ausblenden',
  },
  en: {
    offline: 'The browser reports being offline. Check the backend status before entering more data. This notice does not save or synchronize tournament data.',
    recovered: 'The browser reports a network again. This does not confirm that the backend is reachable or that all entries have been saved.',
    unknown: 'The network status cannot be determined. Check the backend status; this notice does not confirm saving or synchronization.',
    dismiss: 'Hide notice',
  },
  es: {
    offline: 'El navegador indica que no hay conexi\u00f3n. Comprueba el estado del servidor antes de introducir m\u00e1s datos. Este aviso no guarda ni sincroniza datos del torneo.',
    recovered: 'El navegador vuelve a detectar una red. Esto no confirma que el servidor sea accesible ni que se hayan guardado todos los datos.',
    unknown: 'No se puede determinar el estado de la red. Comprueba el servidor; este aviso no confirma que los datos est\u00e9n guardados o sincronizados.',
    dismiss: 'Ocultar aviso',
  },
};
const installations = new WeakMap();

export function installOfflineNotice(document, target) {
  const panel = document.getElementById('stm-offline-notice');
  const text = document.getElementById('stm-offline-message');
  const dismiss = document.getElementById('stm-offline-dismiss');
  if (!panel || !text || !dismiss || !target) return () => {};
  if (installations.has(panel)) return installations.get(panel);
  let disposed = false, hadOffline = false, mode = null, dismissed = false;
  let unsubscribe = () => {}, observer;
  function render() {
    if (disposed) return;
    const base = String(document.documentElement?.lang ?? 'de').toLowerCase().split('-')[0];
    const language = Object.hasOwn(messages, base) ? base : 'en';
    const current = messages[language];
    panel.lang = language; panel.dir = 'ltr';
    dismiss.textContent = current.dismiss;
    panel.hidden = mode === null || dismissed;
    text.textContent = panel.hidden ? '' : current[mode];
  }
  function changed(hint) {
    if (disposed) return;
    dismissed = false;
    if (hint === 'offline') { hadOffline = true; mode = 'offline'; }
    else mode = hadOffline ? hint === 'online-hint' ? 'recovered' : 'unknown' : null;
    render();
  }
  function hide() { dismissed = true; render(); }
  function dispose() {
    if (disposed) return;
    disposed = true; unsubscribe(); observer?.disconnect();
    dismiss.removeEventListener('click', hide);
    panel.hidden = true; text.textContent = '';
    installations.delete(panel);
  }
  installations.set(panel, dispose);
  try {
    dismiss.addEventListener('click', hide);
    unsubscribe = subscribeNetworkHint(target, changed);
    if (typeof target.MutationObserver === 'function' && document.documentElement) {
      observer = new target.MutationObserver(render);
      observer.observe(document.documentElement, { attributes: true, attributeFilter: ['lang'] });
    }
    render();
  } catch (error) { dispose(); throw error; }
  return dispose;
}
