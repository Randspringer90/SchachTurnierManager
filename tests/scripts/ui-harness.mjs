export function dom(ids) {
  function element(tagName = 'DIV') {
    const listeners = new Map();
    return { tagName, value: '', textContent: '', hidden: true, disabled: false, files: [], children: [], listeners,
      append(...nodes) { this.children.push(...nodes); },
      replaceChildren(...nodes) { this.children = [...nodes]; },
      addEventListener(event, fn) { listeners.set(event, fn); },
      removeEventListener(event, fn) { if (listeners.get(event) === fn) listeners.delete(event); },
      fire(event) { return listeners.get(event)?.(); },
      set innerHTML(_) { throw Error('HTML writer forbidden'); },
    };
  }
  const elements = Object.fromEntries(ids.map(id => [id, element()]));
  return { elements, getElementById: id => elements[id], createElement: tag => element(tag.toUpperCase()) };
}
export function deferred() { let resolve, reject; const promise = new Promise((a,b) => { resolve=a; reject=b; }); return { promise, resolve, reject }; }
export function browser() {
  const listeners = new Map();
  return { navigator: { onLine: true }, listeners, addEventListener(e,f) { listeners.set(e,f); }, removeEventListener(e,f) { if(listeners.get(e) === f) listeners.delete(e); }, fire(e) { listeners.get(e)?.(); } };
}
