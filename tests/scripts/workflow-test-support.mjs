import { readFileSync } from 'node:fs';
export const id = n => `00000000-0000-0000-0000-${n.toString(16).padStart(12, '0')}`;
export function deferred() { let resolve, reject; const promise = new Promise((a,b) => { resolve=a; reject=b; }); return {promise,resolve,reject}; }
export function timers() {
  const pending = new Map(); let next=0;
  return {pending,setTimeout(fn,ms){const id=++next;pending.set(id,{fn,ms});return id;},clearTimeout(id){pending.delete(id);},
    async tick(){const list=[...pending];pending.clear();for(const [,entry] of list) await entry.fn();await new Promise(r=>setImmediate(r));} };
}
function node(tag='DIV') {
  const listeners=new Map(), attrs=new Map(), classes=new Set();
  return {tagName:tag.toUpperCase(),children:[],textContent:'',value:'',hidden:false,disabled:false,checked:false,files:[],dataset:{},name:'',type:'',listeners,
    classList:{toggle(name,force){if(force)classes.add(name);else classes.delete(name);},contains:name=>classes.has(name)},
    append(...nodes){this.children.push(...nodes);},replaceChildren(...nodes){this.children=[...nodes];},
    setAttribute(k,v){attrs.set(k,v);},removeAttribute(k){attrs.delete(k);if(k==='href')delete this.href;},getAttribute(k){return attrs.get(k);},
    addEventListener(k,fn){if(!listeners.has(k))listeners.set(k,new Set());listeners.get(k).add(fn);},removeEventListener(k,fn){listeners.get(k)?.delete(fn);},
    async fire(k){for(const fn of [...(listeners.get(k)??[])])await fn({target:this});},
    querySelectorAll(selector){const all=[];function walk(n){for(const c of n.children){if(c.tagName==='INPUT'&&c.checked)all.push(c);walk(c);}}walk(this);return all;}
  };
}
export function dom(folder) {
  const html=readFileSync(new URL(`../../src/SchachTurnierManager.WebApp/public/${folder}/index.html`,import.meta.url),'utf8');
  const nodes={};for(const match of html.matchAll(/<([a-z][a-z0-9]*)\b([^>]*\bid="([^"]+)"[^>]*)>/g)){
    const n=node(match[1]);n.hidden=/\bhidden\b/.test(match[2]);n.disabled=/\bdisabled\b/.test(match[2]);nodes[match[3]]=n;
  }
  if(nodes.size)nodes.size.value='20';if(nodes.interval)nodes.interval.value='0';
  const document=node('document');document.visibilityState='visible';document.getElementById=id=>nodes[id];document.createElement=tag=>node(tag);
  return {document,nodes,html};
}
export function urlMock(){let index=0;const blobs=new Map();return {blobs,createObjectURL(blob){const key=`blob:synthetic-${++index}`;blobs.set(key,blob);return key;},revokeObjectURL(key){blobs.delete(key);}};}
export const snapshot = (n=1) => ({id:id(n),name:`Synthetic ${n}`,settings:{plannedRounds:5},players:[],rounds:[]});
export const standing = (n=1) => ({rank:n,playerId:id(n),name:`Player ${n}`,points:3,buchholz:7.5,sonnebornBerger:5,wins:2});
