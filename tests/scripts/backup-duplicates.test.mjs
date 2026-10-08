import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { findIdenticalBackups, MAX_FILES, MAX_FILE_BYTES, MAX_TOTAL_BYTES } from '../../src/SchachTurnierManager.WebApp/public/backup-duplicates/core.js';
import { installDuplicateCheck } from '../../src/SchachTurnierManager.WebApp/public/backup-duplicates/ui.js';
const file=(text,name='synthetic.json')=>new File([text],name);
const independent=text=>createHash('sha256').update(text).digest('hex');
test('real File and WebCrypto group identical content, not filenames',async()=>{
  const r=await findIdenticalBackups([file('abc','a.json'),file('different','a.json'),file('abc','b.json')]);
  assert.deepEqual(r.identicalGroups,[[1,3]]);assert.equal(r.entries[0].hash,independent('abc'));assert.equal(r.totalBytes,15);
});
test('two empty files match but are not claimed as valid backups',async()=>{const r=await findIdenticalBackups([file(''),file('')]);assert.deepEqual(r.identicalGroups,[[1,2]]);assert.equal(r.entries[0].hash,independent(''));});
test('byte changes including JSON whitespace and BOM remain distinct',async()=>{const r=await findIdenticalBackups([file('{}'),file('{ }'),file('\uFEFF{}')]);assert.deepEqual(r.identicalGroups,[]);});
test('output does not copy filenames or other file metadata',async()=>{const r=await findIdenticalBackups([file('a','PRIVATE-A'),file('b','PRIVATE-B')]);assert.equal(JSON.stringify(r).includes('PRIVATE'),false);});
for(const files of [[],[file('x')],null,{},Array.from({length:MAX_FILES+1},()=>file('x'))])test('invalid file count '+(files?.length??'none'),async()=>{await assert.rejects(findIdenticalBackups(files),/FILE_COUNT/);});
for(const size of [-1,NaN,Infinity,1.5])test('invalid size '+size,async()=>{await assert.rejects(findIdenticalBackups([{size,arrayBuffer:async()=>new ArrayBuffer(0)},file('')]),/INVALID_FILE/);});
test('oversize and total bounds are checked before reading',async()=>{
  let reads=0;const fake=size=>({size,arrayBuffer:async()=>{reads++;return new ArrayBuffer(0);}});
  await assert.rejects(findIdenticalBackups([fake(MAX_FILE_BYTES+1),fake(0)]),/FILE_TOO_LARGE/);
  await assert.rejects(findIdenticalBackups(Array.from({length:11},()=>fake(MAX_TOTAL_BYTES/10))),/TOTAL_TOO_LARGE/);assert.equal(reads,0);
});
test('crypto must be available before file access',async()=>{let reads=0;await assert.rejects(findIdenticalBackups([{size:1,arrayBuffer:async()=>{reads++;}},file('x')],{subtle:{}}),/CRYPTO_UNAVAILABLE/);assert.equal(reads,0);});
test('size drift and invalid digest are explicit failures',async()=>{
  await assert.rejects(findIdenticalBackups([{size:2,arrayBuffer:async()=>new ArrayBuffer(1)},file('a')]),/FILE_CHANGED/);
  await assert.rejects(findIdenticalBackups([file('a'),file('b')],{subtle:{digest:async()=>new ArrayBuffer(1)}}),/INVALID_DIGEST/);
});
test('read and crypto errors never return a partial successful report',async()=>{
  await assert.rejects(findIdenticalBackups([file('a'),{size:1,arrayBuffer:async()=>{throw Error('READ');}}]),/READ/);
  await assert.rejects(findIdenticalBackups([file('a'),file('b')],{subtle:{digest:async()=>{throw Error('DIGEST');}}}),/DIGEST/);
});
test('progress is monotonic and reads are sequential',async()=>{
  let active=0,max=0;const progress=[];const f=n=>({size:1,async arrayBuffer(){active++;max=Math.max(max,active);await Promise.resolve();active--;return Uint8Array.of(n).buffer;}});
  await findIdenticalBackups([f(1),f(2),f(3)],{onProgress:p=>progress.push(p)});assert.equal(max,1);assert.deepEqual(progress.map(p=>p.completed),[1,2,3]);assert.ok(progress.every(p=>p.total===3));
});
test('pre-cancel avoids reads; cancellation after first file stops the second',async()=>{
  const c=new AbortController();c.abort();await assert.rejects(findIdenticalBackups([file('a'),file('a')],{signal:c.signal}),/CANCELLED/);
  const d=new AbortController();let reads=0;const f={size:1,arrayBuffer:async()=>{reads++;return Uint8Array.of(1).buffer;}};
  await assert.rejects(findIdenticalBackups([f,f],{signal:d.signal,onProgress:()=>d.abort()}),/CANCELLED/);assert.equal(reads,1);
});
test('cancellation after a file read prevents digest',async()=>{
  const c=new AbortController();let hashes=0;const f={size:1,arrayBuffer:async()=>{c.abort();return new ArrayBuffer(1);}};
  await assert.rejects(findIdenticalBackups([f,file('a')],{signal:c.signal,subtle:{digest:()=>{hashes++;}}}),/CANCELLED/);assert.equal(hashes,0);
});
function dom(){const elements=Object.fromEntries(['files','start','cancel','clear','status','result','selection'].map(id=>[id,{value:'',textContent:'',files:[],hidden:false,disabled:false,listeners:new Map(),addEventListener(k,f){this.listeners.set(k,f);},removeEventListener(k){this.listeners.delete(k);},fire(k){return this.listeners.get(k)?.();}}]));return {elements,getElementById:id=>elements[id]};}
const deferred=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};};
const sample={entries:[{index:1,bytes:1,hash:'a'.repeat(64)},{index:2,bytes:1,hash:'a'.repeat(64)}],identicalGroups:[[1,2]]};
test('UI waits for an explicit click and shows groups as text',async()=>{let calls=0;const d=dom();installDuplicateCheck(d,async()=>{calls++;return sample;});assert.equal(calls,0);await d.elements.start.fire('click');assert.equal(calls,1);assert.match(d.elements.result.textContent,/Dateien 1, 2/);});
test('double click never starts a concurrent batch',async()=>{const d=dom(),w=deferred();let calls=0;installDuplicateCheck(d,()=>{calls++;return w.promise;});const run=d.elements.start.fire('click');await d.elements.start.fire('click');assert.equal(calls,1);w.resolve(sample);await run;});
test('cancel invalidates stale success and waits for pending read before allowing restart',async()=>{const d=dom(),w=deferred();let signal;installDuplicateCheck(d,(_,o)=>{signal=o.signal;return w.promise;});const run=d.elements.start.fire('click');d.elements.cancel.fire('click');assert.equal(signal.aborted,true);assert.equal(d.elements.start.disabled,true);w.resolve(sample);await run;assert.equal(d.elements.result.hidden,true);assert.equal(d.elements.start.disabled,false);});
test('selection change and clear suppress stale progress and errors',async()=>{const d=dom(),w=deferred();let progress;installDuplicateCheck(d,(_,o)=>{progress=o.onProgress;return w.promise;});const run=d.elements.start.fire('click');d.elements.files.fire('change');const state=d.elements.status.textContent;progress({completed:20,total:20});assert.equal(d.elements.status.textContent,state);d.elements.clear.fire('click');w.reject(Error('PRIVATE'));await run;assert.equal(d.elements.result.hidden,true);assert.equal(d.elements.status.textContent.includes('PRIVATE'),false);});
test('unknown error discards old output and does not display private message',async()=>{const d=dom();installDuplicateCheck(d,async()=>{throw Error('PRIVATE');});await d.elements.start.fire('click');assert.equal(d.elements.result.hidden,true);assert.equal(d.elements.status.textContent.includes('PRIVATE'),false);});
test('dispose stops updates, closes controls and removes listeners',async()=>{const d=dom(),w=deferred();const stop=installDuplicateCheck(d,()=>w.promise);const run=d.elements.start.fire('click');stop();stop();w.resolve(sample);await run;assert.equal(d.elements.result.hidden,true);assert.equal(d.elements.start.disabled,true);assert.equal(d.elements.start.listeners.size,0);});
test('size metadata changed during the batch cannot bypass the initial budget',async()=>{
  const later={size:1,arrayBuffer:async()=>new ArrayBuffer(2)};
  await assert.rejects(findIdenticalBackups([file('a'),later],{onProgress:()=>{later.size=2;}}),/FILE_CHANGED/);
});
