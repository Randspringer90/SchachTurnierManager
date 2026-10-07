import test from 'node:test';
import assert from 'node:assert/strict';
import { fideCapabilities, queryPlan, lookupResult, compareCandidates, createFideWorkbench } from '../../src/SchachTurnierManager.WebApp/public/fide-workbench/core.mjs';
import { installFideWorkbench } from '../../src/SchachTurnierManager.WebApp/public/fide-workbench/ui.mjs';
import { dom, deferred } from './workflow-test-support.mjs';
const providers=[{source:0,supportsIdLookup:true,supportsNameSearch:true,name:'Synthetic FIDE'}];
const profile=(id='99900001')=>({source:0,fideId:id,externalId:id,name:'Synthetic '+id,title:'',federation:'GER',elo:1800,rapidElo:null,blitzElo:1700,retrievedAt:'2026-01-01T00:00:00Z',notes:'PRIVATE',birthYear:1900,profileUrl:'https://example.invalid/private'});
const result=(ids=['99900001'])=>({source:0,status:0,players:ids.map(profile),message:'PRIVATE raw source message'});
function source(response=()=>result()){let calls=[];return {calls,api:{async json(path){calls.push(path);return path.endsWith('/providers')?providers:response(path);}}};}

test('capability detector accepts documented numeric and string source variants',()=>{
  assert.deepEqual(fideCapabilities(providers),{byId:true,byName:true});assert.deepEqual(fideCapabilities([{...providers[0],source:'Fide',supportsNameSearch:false}]),{byId:true,byName:false});
});
for(const value of [[],null,[{source:1,supportsIdLookup:true,supportsNameSearch:true}],[providers[0],providers[0]],[{...providers[0],supportsNameSearch:'yes'}]])test('unknown or ambiguous capabilities rejected '+JSON.stringify(value),()=>assert.throws(()=>fideCapabilities(value),/INVALID_PROVIDER/));
test('search constructs only encoded fixed-source request',()=>{
  const plan=queryPlan('  Synthetic & Name  ',{byName:true,byId:true});assert.equal(plan.query,'Synthetic & Name');assert.equal(plan.path,'/api/external-players/search?source=Fide&query=Synthetic%20%26%20Name');
});
for(const query of ['', 'x','x'.repeat(81),'1234567890123','test\0value','\uD800\uD800',null])test('invalid query '+JSON.stringify(query),()=>assert.throws(()=>queryPlan(query,{byName:true,byId:true}),/INVALID_QUERY/));
test('provider flags prevent unsupported searches, not merely hide a warning',()=>{
  assert.throws(()=>queryPlan('Synthetic',{byId:true,byName:false}),/UNSUPPORTED_SEARCH/);
  assert.throws(()=>queryPlan('99900001',{byId:false,byName:true}),/UNSUPPORTED_SEARCH/);
});
for(const [status,name] of [[0,'Found'],[1,'NotFound'],[2,'Unsupported'],[3,'Unavailable'],[4,'InvalidRequest']])test('status '+name+' mapped without backend message disclosure',()=>{
  const r=lookupResult({source:0,status,players:status===0?[profile()]:[],message:'PRIVATE'});assert.equal(r.status,name);assert.equal(JSON.stringify(r).includes('PRIVATE'),false);
});
test('profile projection excludes birth year, URL, notes and other identities',()=>{
  const row=lookupResult(result()).players[0];assert.deepEqual(Object.keys(row).sort(),['blitzElo','elo','federation','fideId','name','rapidElo','retrievedAt','title']);assert.equal(Object.isFrozen(row),true);
});
for(const [label,edit] of [['source',r=>r.source=1],['status',r=>r.status=99],['duplicates',r=>r.players.push(r.players[0])],['bad rating',r=>r.players[0].elo=Infinity],['negative rating',r=>r.players[0].elo=-1],['foreign profile',r=>r.players[0].source=2],['ID disagreement',r=>r.players[0].externalId='123'],['bad name',r=>r.players[0].name=''],['failure plus players',r=>r.status=3]])test('bad response '+label+' is rejected',()=>{const r=result();edit(r);assert.throws(()=>lookupResult(r));});
test('comparison preserves distinct identities and highlights numeric differences',()=>{
  const a=lookupResult(result(['99900001','99900002'])).players;const items=[a[0],{...a[1],elo:1900}];const rows=compareCandidates(items);
  assert.equal(rows.find(r=>r.key==='elo').different,true);assert.equal(rows.find(r=>r.key==='federation').different,false);assert.equal(rows.length,8);
});
test('workbench never queries before initialize or explicit search',async()=>{
  const s=source(),work=createFideWorkbench(s.api);assert.equal(s.calls.length,0);await assert.rejects(work.search('Synthetic'),/UNSUPPORTED_SEARCH/);assert.equal(s.calls.length,0);await work.initialize();assert.equal(s.calls.length,1);work.dispose();
});
test('cache is session-only, force refresh bypasses it and expiration fetches again',async()=>{
  let clock=100;const s=source(),work=createFideWorkbench(s.api,{now:()=>clock});await work.initialize();
  assert.equal((await work.search('Synthetic')).cached,false);assert.equal((await work.search('Synthetic')).cached,true);assert.equal(s.calls.length,2);
  assert.equal((await work.search('Synthetic',true)).cached,false);clock+=300001;assert.equal((await work.search('Synthetic')).cached,false);assert.equal(s.calls.length,4);work.dispose();
});
test('cache is bounded to ten keys and clear forces a new lookup',async()=>{
  const s=source(),work=createFideWorkbench(s.api);await work.initialize();for(let i=0;i<11;i++)await work.search('Synthetic '+i);
  assert.equal((await work.search('Synthetic 0')).cached,false);work.clear();assert.equal((await work.search('Synthetic 0')).cached,false);work.dispose();
});
test('unavailable responses are not cached as no-hits',async()=>{
  const s=source(()=>({source:0,status:3,players:[]})),work=createFideWorkbench(s.api);await work.initialize();await work.search('Synthetic');await work.search('Synthetic');assert.equal(s.calls.length,3);work.dispose();
});
test('backwards clock movement cannot reuse a future-dated cache entry',async()=>{
  let clock=500;const s=source(),work=createFideWorkbench(s.api,{now:()=>clock});await work.initialize();await work.search('Synthetic');clock=100;assert.equal((await work.search('Synthetic')).cached,false);work.dispose();
});
test('exact numeric query does not accept another player identity',async()=>{
  const s=source(),work=createFideWorkbench(s.api);await work.initialize();await assert.rejects(work.search('99900002'),/ID_MISMATCH/);work.dispose();
});
test('pin up to four candidates across searches, never silently merge people',async()=>{
  const s=source(()=>result(['99900001','99900002','99900003','99900004','99900005'])),work=createFideWorkbench(s.api);await work.initialize();await work.search('Synthetic');
  for(let n=1;n<=4;n++)work.pin('9990000'+n);work.pin('99900001');assert.equal(work.candidates().length,4);assert.throws(()=>work.pin('99900005'),/COMPARE_LIMIT/);
  work.remove('99900002');work.pin('99900005');assert.equal(work.candidates().length,4);work.clear();assert.deepEqual(work.candidates(),[]);work.dispose();
});
test('pinning requires a current result instead of arbitrary profile injection',()=>{const work=createFideWorkbench({});assert.throws(()=>work.pin('99900001'),/NO_CANDIDATE/);work.dispose();});
test('cancellation rejects an old reply and does not poison the cache',async()=>{
  const wait=deferred();let calls=0;const work=createFideWorkbench({json:async path=>path.endsWith('/providers')?providers:++calls===1?wait.promise:result()});
  await work.initialize();const pending=work.search('Synthetic');work.cancel();wait.resolve(result());await assert.rejects(pending,/CANCELLED/);assert.equal((await work.search('Synthetic')).cached,false);work.dispose();
});
test('concurrent searches accept only the latest response',async()=>{
  const first=deferred();const work=createFideWorkbench({json:async path=>path.endsWith('/providers')?providers:path.includes('First')?first.promise:result(['99900002'])});
  await work.initialize();const a=work.search('First');const b=await work.search('Second');first.resolve(result());await assert.rejects(a,/CANCELLED/);assert.equal(b.players[0].fideId,'99900002');work.pin('99900002');work.dispose();
});
test('initialize failure leaves no stale capability authorization',async()=>{
  const s=source();let block=false;const work=createFideWorkbench({json:async path=>{if(block)throw Error('NETWORK');return s.api.json(path);}});await work.initialize();block=true;await assert.rejects(work.initialize());await assert.rejects(work.search('Synthetic'),/UNSUPPORTED_SEARCH/);work.dispose();
});
test('UI makes no eager calls and supports candidate comparison through text nodes',async()=>{
  const s=source(()=>result(['99900001','99900002'])),{document,nodes:e}=dom('fide-workbench');const stop=installFideWorkbench(document,s.api);
  assert.equal(s.calls.length,0);await e.providers.fire('click');assert.equal(e.search.disabled,false);e.query.value='Synthetic';await e.search.fire('click');assert.equal(e.results.children.length,2);
  await e.results.children[0].children.at(-1).children[0].fire('click');await e.results.children[1].children.at(-1).children[0].fire('click');assert.equal(e['compare-region'].hidden,false);assert.equal(e.candidates.children.length,2);assert.equal(e.comparison.children[0].children.length,6);
  await e.candidates.children[0].children[0].fire('click');assert.equal(e.candidates.children.length,1);stop();assert.equal(e.results.children.length,0);
});
test('UI explains inactive name support without contacting the search endpoint',async()=>{
  let calls=0;const {document,nodes:e}=dom('fide-workbench');installFideWorkbench(document,{json:async()=>{calls++;return [{...providers[0],supportsNameSearch:false}];}});
  await e.providers.fire('click');e.query.value='Synthetic';await e.search.fire('click');assert.equal(calls,1);assert.match(e['query-status'].textContent,/nicht aktiv/);
});
test('changed query invalidates an outstanding UI result',async()=>{
  const wait=deferred(),{document,nodes:e}=dom('fide-workbench');const stop=installFideWorkbench(document,{json:async path=>path.endsWith('/providers')?providers:wait.promise});await e.providers.fire('click');e.query.value='Synthetic';const request=e.search.fire('click');await e.query.fire('input');wait.resolve(result());await request;assert.equal(e.results.children.length,0);stop();
});
test('source-supplied HTML names are text and private errors remain hidden',async()=>{
  const {document,nodes:e}=dom('fide-workbench');let fail=false;installFideWorkbench(document,{json:async path=>{if(path.endsWith('/providers'))return providers;if(fail)throw Error('PRIVATE');return {...result(),players:[{...profile(),name:'<img src=x>'}]};}});
  await e.providers.fire('click');e.query.value='Synthetic';await e.search.fire('click');assert.equal(e.results.children[0].children[0].textContent,'<img src=x>');fail=true;e.fresh.checked=true;await e.search.fire('click');assert.equal(e.results.children.length,0);assert.equal(e['query-status'].textContent.includes('PRIVATE'),false);
});
test('queued candidate clicks after disposal do not repopulate the screen',async()=>{
  const {document,nodes:e}=dom('fide-workbench'),s=source();const stop=installFideWorkbench(document,s.api);
  await e.providers.fire('click');e.query.value='Synthetic';await e.search.fire('click');
  const button=e.results.children[0].children.at(-1).children[0];stop();await button.fire('click');
  assert.equal(e.candidates.children.length,0);assert.equal(e.comparison.children.length,0);
});
