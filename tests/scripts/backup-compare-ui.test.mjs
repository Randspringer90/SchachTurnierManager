import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { installComparisonUi } from '../../src/SchachTurnierManager.WebApp/public/backup-compare/ui.mjs';
function dom(ids) {
 const elements=Object.fromEntries(ids.map(id=>[id,{value:'',textContent:'',hidden:true,disabled:false,files:[],listeners:new Map(),addEventListener(name,fn){this.listeners.set(name,fn);},removeEventListener(name){this.listeners.delete(name);},fire(name){return this.listeners.get(name)?.();}}]));
 return {elements,getElementById:id=>elements[id]};
}
const deferred=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};};
const ids=['before','after','start','clear','status','result','details'];
const sample={sameComparedContent:true,metadataChanged:false,...Object.fromEntries(['players','rounds','audit'].map(key=>[key,{before:1,after:1,added:0,removed:0,changed:0,details:[],omitted:0}]))};
const install=installComparisonUi;
function setup(compute=async()=>sample){const d=dom(ids); const dispose=install(d,compute); return {d,e:d.elements,dispose};}
test('initial state is idle and empty',()=>{const {e}=setup();assert.equal(e.start.disabled,false);assert.equal(e.result.hidden,true);assert.notEqual(e.status.textContent,'');});
test('successful operation displays result',async()=>{const {e}=setup();await e.start.fire('click');assert.equal(e.result.hidden,false);assert.equal(e.start.disabled,false);});
test('double click while pending computes once',async()=>{let calls=0;const wait=deferred();const {e}=setup(()=>{calls++;return wait.promise;});const first=e.start.fire('click');await e.start.fire('click');assert.equal(calls,1);wait.resolve(sample);await first;});
test('reset during pending read suppresses stale result',async()=>{const wait=deferred();const {e}=setup(()=>wait.promise);const first=e.start.fire('click');e.clear.fire('click');wait.resolve(sample);await first;assert.equal(e.result.hidden,true);});
test('file change invalidates old read',async()=>{const wait=deferred();const {e}=setup(()=>wait.promise);const first=e.start.fire('click');e['before'].fire('change');wait.resolve(sample);await first;assert.equal(e.result.hidden,true);});
test('old failure does not overwrite newer success',async()=>{const wait=deferred();let calls=0;const {e}=setup(()=>++calls===1?wait.promise:Promise.resolve(sample));const first=e.start.fire('click');e['before'].fire('change');await e.start.fire('click');const status=e.status.textContent;wait.reject(Error('PRIVATE-SYNTHETIC'));await first;assert.equal(e.status.textContent,status);assert.equal(e.result.hidden,false);});
test('new operation hides old output until it finishes',async()=>{const wait=deferred();let calls=0;const {e}=setup(()=>++calls===1?Promise.resolve(sample):wait.promise);await e.start.fire('click');const second=e.start.fire('click');assert.equal(e.result.hidden,true);wait.resolve(sample);await second;assert.equal(e.result.hidden,false);});
test('unknown errors never disclose input payload',async()=>{const {e}=setup(async()=>{throw Error('PRIVATE-SYNTHETIC<img>');});await e.start.fire('click');assert.equal(e.status.textContent.includes('PRIVATE'),false);assert.equal(e.result.hidden,true);assert.equal(e.start.disabled,false);});
test('prototype-like error codes do not render prototype values',async()=>{const {e}=setup(async()=>{throw Error('__proto__');});await e.start.fire('click');assert.equal(e.status.textContent.includes('[object'),false);});
test('dispose invalidates pending results and removes listeners',async()=>{const wait=deferred();const {e,dispose}=setup(()=>wait.promise);const pending=e.start.fire('click');dispose();wait.resolve(sample);await pending;assert.equal(e.result.hidden,true);assert.equal(e.start.listeners.size,0);});
const folder=new URL('../../src/SchachTurnierManager.WebApp/public/backup-compare/',import.meta.url);
const html=readFileSync(new URL('index.html',folder),'utf8');
const source=readFileSync(new URL('ui.mjs',folder),'utf8');
test('UI is available from main entry',()=>{const entry=readFileSync(new URL('../../src/SchachTurnierManager.WebApp/index.html',import.meta.url),'utf8');assert.ok(entry.includes('/backup-compare/index.html'));});
test('all production DOM ids exist once',()=>{for(const id of ids)assert.equal(html.split('id="'+id+'"').length-1,1,id);});
test('CSP blocks connection and form submission',()=>{assert.ok(html.includes("connect-src 'none'"));assert.ok(html.includes("form-action 'none'"));});
test('status region accessible and only same-origin local scripts',()=>{assert.match(html,/role="status"/);assert.match(html,/aria-live="polite"/);assert.match(html,/src="\.\/app.mjs"/);});
test('no raw HTML writer in controller',()=>assert.doesNotMatch(source,/innerHTML|outerHTML|document\.write|eval\(/));

test('changing right backup also invalidates pending comparison',async()=>{const wait=deferred();const {e}=setup(()=>wait.promise);const run=e.start.fire('click');e.after.fire('change');wait.resolve(sample);await run;assert.equal(e.result.hidden,true);});
test('details display IDs and truncation without raw values',async()=>{const output=structuredClone(sample);output.players={before:0,after:300,added:300,removed:0,changed:0,details:[{id:'00000000-0000-0000-0000-000000000123',kind:'added'}],omitted:299};output.sameComparedContent=false;const {e}=setup(async()=>output);await e.start.fire('click');assert.match(e.details.textContent,/Weitere 299/);assert.match(e.details.textContent,/000000000123/);assert.match(e.status.textContent,/Unterschiede/);});
for(const code of ['DIFFERENT_TOURNAMENT','INVALID_SIZE','DUPLICATE_KEY','DUPLICATE_ID','TOO_COMPLEX'])test('known error '+code,async()=>{const {e}=setup(async()=>{throw Error(code);});await e.start.fire('click');assert.equal(e.result.hidden,true);assert.notEqual(e.status.textContent,'');});
