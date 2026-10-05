import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { readAuditJsonl, filterAudit, MAX_BYTES } from '../../src/SchachTurnierManager.WebApp/public/audit-reader/core.js';
import { installAuditReader } from '../../src/SchachTurnierManager.WebApp/public/audit-reader/ui.js';
const bytes=text=>new TextEncoder().encode(text);
const event=(n=1,extra={})=>({id:'00000000-0000-0000-0000-'+n.toString(16).padStart(12,'0'),createdAt:'2026-01-01T12:00:00.1234567+02:00',action:'ResultRecorded',severity:'Info',roundNumber:1,boardNumber:1,summary:'Synthetic result',...extra});
const record=entry=>({type:'audit-event',entry});
const manifest=count=>({type:'manifest',schemaVersion:'stm-audit-bundle-1',format:'jsonl',auditEntryCount:count,tournamentName:'PRIVATE',settings:{privateValue:'PRIVATE'}});
const source=(events,extras=[])=>[manifest(events.length),{type:'tournament-snapshot',tournament:{name:'PRIVATE'}},...extras,...events.map(record)].map(r=>JSON.stringify(r)).join('\n')+'\n';
const parse=(events,extras)=>readAuditJsonl(bytes(source(events,extras)));
test('current export shape is accepted and raw snapshots are not kept',()=>{const r=parse([event()],[{type:'pairing-forensics',forensics:{privateData:'PRIVATE'}}]);assert.equal(r.events.length,1);assert.equal(r.skippedRecords,2);assert.equal(JSON.stringify(r).includes('PRIVATE'),false);});
test('actor, player, reason and details fields never become output fields',()=>{const r=parse([event(1,{actor:'PRIVATE',playerName:'PRIVATE',reason:'PRIVATE',details:'PRIVATE'})]);assert.equal(JSON.stringify(r).includes('PRIVATE'),false);});
for(const nl of ['\n','\r\n'])test('line ending '+JSON.stringify(nl)+' and BOM work',()=>{const text='\uFEFF'+source([event()]).replaceAll('\n',nl);assert.equal(readAuditJsonl(bytes(text)).events.length,1);});
test('empty event journal works when declared count is zero',()=>assert.deepEqual(parse([]).events,[]));
test('unknown records are counted separately',()=>assert.equal(parse([],[{type:'future-record',payload:'PRIVATE'}]).unknownRecords,1));
test('export ordering is retained, even if time strings are out of order',()=>{const events=[event(2),event(1)];assert.deepEqual(parse(events).events.map(e=>e.id),events.map(e=>e.id));});
for(const severity of ['Info','Warning','Critical'])test('severity '+severity,()=>assert.equal(parse([event(1,{severity})]).events[0].severity,severity));
for(const time of ['2026-01-01T12:00:00Z','2026-01-01T12:00:00+00:00','2026-01-01T12:00:00.123Z'])test('timestamp '+time,()=>assert.equal(parse([event(1,{createdAt:time})]).events[0].createdAt,time));
test('case-insensitive duplicate event IDs are rejected',()=>{const a=event(10),b={...a,id:a.id.toUpperCase()};assert.throws(()=>parse([a,b]),/DUPLICATE_ID/);});
test('manifest count mismatch blocks an apparently complete view',()=>{const text=source([event()]).replace('"auditEntryCount":1','"auditEntryCount":2');assert.throws(()=>readAuditJsonl(bytes(text)),/COUNT_MISMATCH/);});
test('second manifest is rejected',()=>assert.throws(()=>parse([],[manifest(0)]),/DUPLICATE_MANIFEST/));
for(const edit of [s=>s.replace('stm-audit-bundle-1','future-version'),s=>s.replace('"format":"jsonl"','"format":"json"'),s=>s.slice(s.indexOf('\n')+1)])test('unsupported manifest is not silently accepted',()=>assert.throws(()=>readAuditJsonl(bytes(edit(source([event()])))),/UNSUPPORTED_BUNDLE/));
for(const [name,value] of [['severity','Future'],['action','<img>'],['createdAt','PRIVATE'],['createdAt','2026-99-99T00:00:00Z'],['roundNumber',0],['boardNumber',1.5],['id','bad'],['summary','x'.repeat(4001)]])test('invalid event '+name+' is rejected',()=>assert.throws(()=>parse([event(1,{[name]:value})]),/INVALID_EVENT/));
test('optional round and board remain absent rather than invented',()=>{const r=parse([event(1,{roundNumber:null,boardNumber:null})]);assert.equal(r.events[0].round,null);assert.equal(r.events[0].board,null);});
test('malformed JSONL, UTF-8 and oversized input fail',()=>{
  assert.throws(()=>readAuditJsonl(bytes('{bad}\n')),/INVALID_JSONL/);
  assert.throws(()=>readAuditJsonl(Uint8Array.of(255)),/INVALID_UTF8/);
  assert.throws(()=>readAuditJsonl(new Uint8Array(MAX_BYTES+1)),/INVALID_SIZE/);
});
test('line and manifest budgets apply before collecting unbounded results',()=>{
  assert.throws(()=>readAuditJsonl(bytes('\n'.repeat(10001))),/TOO_MANY_LINES/);
  assert.throws(()=>readAuditJsonl(bytes(JSON.stringify(manifest(5001)))),/INVALID_COUNT/);
});
test('JSON duplicate member convention is explicit, not an integrity guarantee',()=>{
  const text=source([event()]).replace('"severity":"Info"','"severity":"Warning","severity":"Info"');assert.equal(readAuditJsonl(bytes(text)).events[0].severity,'Info');
});
test('prototype keys are passive data, not instructions',()=>{const text=source([event()]).replace('"type":"tournament-snapshot"','"__proto__":{"polluted":true},"type":"tournament-snapshot"');assert.equal(readAuditJsonl(bytes(text)).events.length,1);assert.equal({}.polluted,undefined);});
test('filters combine without modifying input',()=>{
  const events=parse([event(1),event(2,{severity:'Warning'}),event(3,{severity:'Warning',roundNumber:2,action:'RoundLocked'})]).events;
  const saved=JSON.stringify(events);const f=filterAudit(events,{severity:'Warning',action:'RoundLocked',round:'2'});assert.equal(f.total,1);assert.equal(f.entries[0].round,2);assert.equal(JSON.stringify(events),saved);
});
test('pagination preserves totals and exposes remaining pages',()=>{const events=parse(Array.from({length:401},(_,i)=>event(i+1))).events;assert.equal(filterAudit(events).entries.length,200);assert.equal(filterAudit(events).hasMore,true);const last=filterAudit(events,{offset:400});assert.equal(last.total,401);assert.equal(last.entries.length,1);assert.equal(last.hasMore,false);});
for(const options of [{round:'0'},{round:'1.5'},{severity:'Unknown'},{limit:201},{offset:-1},{action:null}])test('bad filter '+JSON.stringify(options),()=>assert.throws(()=>filterAudit([],{...options,action:options.action===null?7:options.action}),/INVALID_FILTER/));
function node(){return {value:'',checked:false,disabled:false,textContent:'',files:[],children:[],listeners:new Map(),append(child){this.children.push(child);},replaceChildren(...children){this.children=children;},addEventListener(k,f){this.listeners.set(k,f);},removeEventListener(k){this.listeners.delete(k);},fire(k){return this.listeners.get(k)?.();}};}
function dom(){const ids=['file','load','clear','show-summary','severity','action','round','previous','next','entries','status'];const elements=Object.fromEntries(ids.map(id=>[id,node()]));return {elements,getElementById:id=>elements[id],createElement:()=>node()};}
const deferred=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};};
test('UI loads actual File on click and hides summaries by default',async()=>{
  const d=dom();installAuditReader(d);const e=d.elements;e.file.files=[new File([source([event(1,{summary:'PRIVATE SUMMARY'})])],'synthetic.jsonl')];assert.equal(e.entries.children.length,0);await e.load.fire('click');assert.equal(e.entries.children.length,1);assert.equal(e.entries.children[0].children[5].textContent,'(ausgeblendet)');e['show-summary'].checked=true;e['show-summary'].fire('change');assert.equal(e.entries.children[0].children[5].textContent,'PRIVATE SUMMARY');
});
test('render uses text not HTML and summary opt-out removes revealed text',async()=>{
  const d=dom();installAuditReader(d);const e=d.elements;e.file.files=[new File([source([event(1,{summary:'<script>synthetic</script>'})])],'x')];await e.load.fire('click');e['show-summary'].checked=true;e['show-summary'].fire('change');assert.equal(e.entries.children[0].children[5].textContent,'<script>synthetic</script>');e['show-summary'].checked=false;e['show-summary'].fire('change');assert.equal(e.entries.children[0].children[5].textContent,'(ausgeblendet)');
});
test('UI pages and resetting filters returns to the first page',async()=>{
  const d=dom();installAuditReader(d);const e=d.elements;e.file.files=[new File([source(Array.from({length:201},(_,i)=>event(i+1)))],'x')];await e.load.fire('click');assert.equal(e.entries.children.length,200);e.next.fire('click');assert.equal(e.entries.children.length,1);assert.equal(e.previous.disabled,false);e.severity.value='Info';e.severity.fire('change');assert.equal(e.entries.children.length,200);assert.equal(e.previous.disabled,true);
});
test('changing file during pending read suppresses old output without concurrent read',async()=>{
  const d=dom(),w=deferred();installAuditReader(d);const e=d.elements;const data=bytes(source([event()]));e.file.files=[{size:data.length,arrayBuffer:()=>w.promise}];const run=e.load.fire('click');e.file.fire('change');assert.equal(e.load.disabled,true);w.resolve(data.buffer);await run;assert.equal(e.entries.children.length,0);assert.equal(e.load.disabled,false);
});
test('reset drops parsed private data from the visible controls',async()=>{
  const d=dom();installAuditReader(d);const e=d.elements;e.file.files=[new File([source([event()])],'x')];await e.load.fire('click');e.clear.fire('click');assert.equal(e.entries.children.length,0);assert.equal(e.action.children.length,1);assert.equal(e['show-summary'].checked,false);
});
test('private file errors are not displayed',async()=>{const d=dom();installAuditReader(d);const e=d.elements;e.file.files=[{size:1,arrayBuffer:async()=>{throw Error('PRIVATE');}}];await e.load.fire('click');assert.equal(e.status.textContent.includes('PRIVATE'),false);assert.equal(e.entries.children.length,0);});
test('teardown invalidates reads and removes every listener',async()=>{const d=dom(),w=deferred();const stop=installAuditReader(d);const e=d.elements;e.file.files=[{size:1,arrayBuffer:()=>w.promise}];const run=e.load.fire('click');stop();w.resolve(new ArrayBuffer(1));await run;assert.equal(e.load.disabled,true);assert.ok(Object.values(e).every(n=>n.listeners.size===0));});
test('standalone page disallows connections and form submission',()=>{const text=readFileSync(new URL('../../src/SchachTurnierManager.WebApp/public/audit-reader/index.html',import.meta.url),'utf8');assert.ok(text.includes("connect-src 'none'"));assert.ok(text.includes("form-action 'none'"));assert.match(text,/JSON.parse/);});
