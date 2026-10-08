import { readFileSync } from 'node:fs';
export function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}
export class TestElement {
  constructor(tagName = 'div') {
    this.tagName = tagName.toUpperCase(); this.children = []; this.listeners = new Map(); this.attributes = new Map();
    this._text = ''; this._value = ''; this.files = []; this.disabled = false; this.hidden = false; this.checked = false;
  }
  get textContent() { return this._text; }
  set textContent(value) { this._text = String(value); this.children = []; }
  get value() { return this._value; }
  set value(value) { this._value = value; if (this.type === 'file' && value === '') this.files = []; }
  append(...children) { this.children.push(...children); }
  replaceChildren(...children) { this.children = children; this._text = ''; }
  setAttribute(name, value) { this.attributes.set(name, String(value)); }
  removeAttribute(name) { this.attributes.delete(name); if (name === 'href') delete this.href; }
  getAttribute(name) { return this.attributes.get(name) ?? null; }
  addEventListener(type, handler) { if (!this.listeners.has(type)) this.listeners.set(type, new Set()); this.listeners.get(type).add(handler); }
  removeEventListener(type, handler) { this.listeners.get(type)?.delete(handler); }
  async fire(type) { for (const handler of [...(this.listeners.get(type) ?? [])]) await handler({ target: this, type }); }
}
export function dom(folder) {
  const html = readFileSync(new URL(`../../src/SchachTurnierManager.WebApp/public/${folder}/index.html`, import.meta.url), 'utf8');
  const nodes = {};
  for (const match of html.matchAll(/<([a-z][a-z0-9]*)\b([^>]*\bid="([^"]+)"[^>]*)>/gi)) {
    const node = new TestElement(match[1]); const attrs = match[2];
    if (nodes[match[3]]) throw Error('duplicate id');
    node.id = match[3]; node.hidden = /\bhidden\b/.test(attrs); node.disabled = /\bdisabled\b/.test(attrs);
    node.checked = /\bchecked\b/.test(attrs); node.type = attrs.match(/\btype="([^"]+)"/)?.[1] ?? '';
    nodes[node.id] = node;
  }
  return { html, nodes, document: { getElementById: id => nodes[id] ?? null, createElement: tag => new TestElement(tag) } };
}
export function blobUrls() {
  const active = new Map(); let serial = 0;
  return { active, createObjectURL(blob) { const key = `blob:synthetic-${++serial}`; active.set(key, blob); return key; }, revokeObjectURL(key) { active.delete(key); } };
}
export const guid = n => `00000000-0000-0000-0000-${n.toString(16).padStart(12, '0')}`;
