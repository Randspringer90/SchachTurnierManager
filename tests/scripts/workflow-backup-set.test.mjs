import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { collectBackupSet, readBackupSet, MAX_ITEM_BYTES, MAX_ARCHIVE_BYTES } from '../../src/SchachTurnierManager.WebApp/public/backup-set/core.mjs';
import { installBackupSet } from '../../src/SchachTurnierManager.WebApp/public/backup-set/ui.mjs';
import { createReadApi } from '../../src/SchachTurnierManager.WebApp/public/workflow-common/read-api.mjs';
import { downloadLink } from '../../src/SchachTurnierManager.WebApp/public/workflow-common/dom.mjs';
import { id, snapshot, dom, urlMock, deferred } from './workflow-test-support.mjs';
const text = n => JSON.stringify(snapshot(n));
const api = (values = {}) => ({ async document(path) { const n = Number.parseInt(path.split('/')[3].slice(-12),16); return { text: values[n] ?? text(n) }; } });
const file = value => new File([typeof value === 'string' ? value : JSON.stringify(value)], 'synthetic.json');
const sha = value => createHash('sha256').update(value).digest('hex');
const now = () => 1767225600000;
async function archive() { return JSON.parse((await collectBackupSet([id(1),id(2)],api(),{now})).text); }

test('multiple native exports roundtrip with real File and WebCrypto', async () => {
  const result = await collectBackupSet([id(1),id(2)],api(),{now}); const restored = await readBackupSet(file(result.text));
  assert.equal(result.count,2); assert.equal(restored.length,2); assert.equal(restored[0].content,text(1));
  assert.equal(restored[1].content,text(2)); assert.equal(JSON.parse(result.text).atomicSnapshot,false);
  assert.equal(JSON.parse(result.text).items[0].sha256,sha(text(1)));
});
test('raw BOM, line endings and precise number tokens survive extraction byte-for-byte', async () => {
  const raw = '\uFEFF{\r\n"id":"'+id(1)+'","name":"Synthetic","settings":{},"players":[],"rounds":[],"x":9007199254740993,"y":0.10000000000000000001\r\n}';
  const made=await collectBackupSet([id(1)],api({1:raw}),{now}); const [restored]=await readBackupSet(file(made.text));
  assert.equal(restored.content,raw); assert.equal(sha(restored.content),sha(raw));
  const transport=createReadApi(async()=>new Response(raw,{headers:{'content-type':'application/json'}}));
  const fromHttp=await collectBackupSet([id(1)],transport,{now}); assert.equal(JSON.parse(fromHttp.text).items[0].content,raw);
});
test('selection is unique before any network call', async () => {
  let calls=0; const source={document(){calls++;}};
  await assert.rejects(collectBackupSet([id(1),id(1)],source),/DUPLICATE_ID/); assert.equal(calls,0);
});
for (const ids of [[],null,{},Array.from({length:11},(_,n)=>id(n+1))]) test('invalid selection count '+(ids?.length ?? 'none'), async()=>{
  await assert.rejects(collectBackupSet(ids,api()),/INVALID_SELECTION/);
});
test('invalid identifier is not used in an API path',async()=>{await assert.rejects(collectBackupSet(['../../other'],api()),/INVALID_ID/);});
test('requests are sequential and progress is monotonic',async()=>{
  let active=0,maximum=0;const seen=[];
  const source={async document(path){active++;maximum=Math.max(maximum,active);await Promise.resolve();active--;return api().document(path);}};
  await collectBackupSet([id(1),id(2),id(3)],source,{onProgress:p=>seen.push(p)});
  assert.equal(maximum,1);assert.deepEqual(seen.map(p=>p.completed),[1,2,3]);assert.ok(seen.every(p=>p.total===3));
});
test('failed member rejects the whole operation rather than returning partial archive',async()=>{
  let calls=0;await assert.rejects(collectBackupSet([id(1),id(2)],{document(path){if(++calls===2)throw Error('READ_FAILURE');return api().document(path);}}),/READ_FAILURE/);
});
for (const [label,changed] of [['wrong identity',{...snapshot(),id:id(2)}],['missing rounds',{...snapshot(),rounds:null}],['invalid settings',{...snapshot(),settings:[]}],['missing name',{...snapshot(),name:42}]]) test(label+' cannot be archived',async()=>{
  await assert.rejects(collectBackupSet([id(1)],api({1:JSON.stringify(changed)})),/INVALID_SNAPSHOT/);
});
test('oversized member is rejected even with a permissive transport double',async()=>{
  await assert.rejects(collectBackupSet([id(1)],api({1:JSON.stringify({...snapshot(),padding:'x'.repeat(MAX_ITEM_BYTES)})})),/INVALID_SNAPSHOT/);
});
test('total budget stops collecting before more files are read',async()=>{
  let calls=0;const source={async document(path){calls++;const n=Number.parseInt(path.split('/')[3].slice(-12),16);return {text:JSON.stringify({...snapshot(n),padding:'x'.repeat(1900000)})};}};
  await assert.rejects(collectBackupSet(Array.from({length:10},(_,n)=>id(n+1)),source),/TOTAL_TOO_LARGE/);assert.equal(calls,6);
});
test('missing cryptography is explicit and prevents requests',async()=>{
  let calls=0;await assert.rejects(collectBackupSet([id(1)],{document(){calls++;}},{subtle:null}),/CRYPTO_UNAVAILABLE/);assert.equal(calls,0);
});
test('malformed digest never creates a valid archive',async()=>{
  await assert.rejects(collectBackupSet([id(1)],api(),{subtle:{digest:async()=>new ArrayBuffer(2)}}),/INVALID_DIGEST/);
});
test('pre-cancel and cancellation after progress are honored',async()=>{
  const pre=new AbortController();pre.abort();await assert.rejects(collectBackupSet([id(1)],api(),{signal:pre.signal}),/CANCELLED/);
  const c=new AbortController();let progress=0;await assert.rejects(collectBackupSet([id(1),id(2)],api(),{signal:c.signal,onProgress:()=>{progress++;c.abort();}}),/CANCELLED/);assert.equal(progress,1);
});
for (const [label,change] of [
  ['content changed',a=>{a.items[0].content=a.items[0].content.replace('Synthetic','Tampered');}],
  ['checksum changed',a=>{a.items[0].sha256='0'.repeat(64);}],
  ['size changed',a=>{a.items[0].bytes++;}],
  ['metadata changed',a=>{a.items[0].name='Other';}],
  ['count changed',a=>{a.items[0].players=9;}],
]) test('extraction rejects '+label,async()=>{
  const a=await archive();change(a);await assert.rejects(readBackupSet(file(a)),/CHECKSUM_MISMATCH/);
});
for (const [label,change] of [
  ['unknown wrapper',a=>{a.format='unknown';}],['atomic claim',a=>{a.atomicSnapshot=true;}],
  ['missing field',a=>{delete a.startedAt;}],['extra field',a=>{a.execute='never';}],
  ['invalid time',a=>{a.completedAt='not-a-date';}],['invalid item time',a=>{a.items[0].capturedAt='unknown';}],
  ['extra item field',a=>{a.items[0].path='../../example';}],['empty items',a=>{a.items=[];}],
]) test('invalid archive '+label,async()=>{const a=await archive();change(a);await assert.rejects(readBackupSet(file(a)),/INVALID_ARCHIVE/);});
test('duplicate tournament identities are rejected',async()=>{const a=await archive();a.items[1]=a.items[0];await assert.rejects(readBackupSet(file(a)),/DUPLICATE_ID/);});
test('failed last member prevents returning the already checked first one',async()=>{const a=await archive();a.items[1].sha256='0'.repeat(64);let count=0;await assert.rejects(readBackupSet(file(a),{onProgress:()=>count++}),/CHECKSUM_MISMATCH/);assert.equal(count,1);});
test('UTF8 and file size drift are rejected',async()=>{
  await assert.rejects(readBackupSet(new File([Uint8Array.of(255)],'invalid.json')),/INVALID_ARCHIVE/);
  await assert.rejects(readBackupSet({size:2,arrayBuffer:async()=>new ArrayBuffer(1)}),/FILE_CHANGED/);
  await assert.rejects(readBackupSet({size:MAX_ARCHIVE_BYTES+1,arrayBuffer:async()=>new ArrayBuffer(0)}),/INVALID_FILE/);
});
test('native JSON alone is not a batch archive',async()=>{await assert.rejects(readBackupSet(file(snapshot())),/INVALID_ARCHIVE/);});
test('cancel during final extraction progress does not release files',async()=>{const a=await archive(),c=new AbortController();await assert.rejects(readBackupSet(file(a),{signal:c.signal,onProgress:p=>{if(p.completed===2)c.abort();}}),/CANCELLED/);});
test('user download link exposes exact Blob bytes and revokes on cleanup',async()=>{
  const {document,nodes}=dom('backup-set');const urls=urlMock();const raw='\uFEFF{"x":9007199254740993}';
  const cleanup=downloadLink(nodes['item-download'],raw,'example.json',urls);
  const blob=urls.blobs.get(nodes['item-download'].href);assert.equal(Buffer.from(await blob.arrayBuffer()).toString('utf8'),raw);
  assert.equal(nodes['item-download'].download,'example.json');assert.equal(nodes['item-download'].hidden,false);
  cleanup();cleanup();assert.equal(urls.blobs.size,0);assert.equal(nodes['item-download'].hidden,true);
});
test('UI has no eager request and consent is required for collection',async()=>{
  let calls=0;const {document,nodes:e}=dom('backup-set');installBackupSet(document,{json:async()=>{calls++;return [snapshot()];},document:api().document},urlMock());
  assert.equal(calls,0);await e.collect.fire('click');assert.equal(calls,0);assert.match(e.status.textContent,/bestaetigen/);
});
test('UI collection prepares a manual link and extraction reproduces the member',async()=>{
  const {document,nodes:e}=dom('backup-set'),urls=urlMock();const stop=installBackupSet(document,{json:async()=>[snapshot()],document:api().document},urls);
  await e.list.fire('click');e.choices.children[0].children[0].checked=true;e.consent.checked=true;await e.collect.fire('click');
  assert.equal(e['archive-download'].hidden,false);assert.equal(urls.blobs.size,1);
  const archiveFile=new File([urls.blobs.get(e['archive-download'].href)],'synthetic.json');e.file.files=[archiveFile];await e.read.fire('click');
  e.member.value=id(1);await e.member.fire('change');assert.equal(e['item-download'].hidden,false);
  assert.equal(await urls.blobs.get(e['item-download'].href).text(),text(1));stop();assert.equal(urls.blobs.size,0);
});
test('cancel prevents stale archive output and does not start a concurrent batch',async()=>{
  const {document,nodes:e}=dom('backup-set'),urls=urlMock(),wait=deferred();let calls=0;
  installBackupSet(document,{json:async()=>[snapshot()],document:async()=>{calls++;return wait.promise;}},urls);
  await e.list.fire('click');e.choices.children[0].children[0].checked=true;e.consent.checked=true;
  const pending=e.collect.fire('click');await e.collect.fire('click');assert.equal(calls,1);await e.cancel.fire('click');
  wait.resolve({text:text(1)});await pending;assert.equal(urls.blobs.size,0);assert.equal(e['archive-download'].hidden,true);assert.equal(e.collect.disabled,false);
});
test('bad local archive clears a previous download instead of leaving stale data',async()=>{
  const {document,nodes:e}=dom('backup-set'),urls=urlMock();installBackupSet(document,{json:async()=>[snapshot()],document:api().document},urls);
  await e.list.fire('click');e.choices.children[0].children[0].checked=true;e.consent.checked=true;await e.collect.fire('click');
  e.file.files=[file('bad')];await e.read.fire('click');assert.equal(urls.blobs.size,0);assert.equal(e['archive-download'].hidden,true);
});
