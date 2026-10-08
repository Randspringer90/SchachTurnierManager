import test from 'node:test';
import assert from 'node:assert/strict';
import {createReadApi,tournamentChoices,requireId,errorText,ReadError} from '../../src/SchachTurnierManager.WebApp/public/workflow-common/read-api.mjs';
import {id} from './workflow-test-support.mjs';
const response=value=>new Response(JSON.stringify(value),{headers:{'Content-Type':'application/json'}});
test('read client uses only fixed GET routes without credentials or redirects',async()=>{
  let call;const api=createReadApi(async(path,options)=>{call={path,options};return response({ok:true});});
  assert.deepEqual(await api.json(`/api/tournaments/${id(1)}/standings`),{ok:true});
  assert.equal(call.options.method,'GET');assert.equal(call.options.credentials,'omit');assert.equal(call.options.redirect,'error');assert.equal(call.options.mode,'same-origin');assert.equal(call.options.cache,'no-store');assert.equal(call.options.body,undefined);
});
for(const path of ['https://example.org/api/tournaments','//example.org/api/tournaments','/api/tournaments/../health','/api/health','/api/tournaments?id=1','/api/tournaments/1/standings','/api/external-players/search?source=Fide&query=x&evil=y'])test('reject route '+path,async()=>{
  let called=false;await assert.rejects(createReadApi(()=>{called=true;}).json(path),/PATH_NOT_ALLOWED/);assert.equal(called,false);
});
test('source text including BOM and precise number tokens is preserved',async()=>{
  const text='\uFEFF{ "id": 9007199254740993 }\r\n';const out=await createReadApi(async()=>new Response(text,{headers:{'content-type':'application/json;charset=utf-8'}})).document('/api/tournaments');assert.equal(out.text,text);
});
for(const status of [400,401,404,500])test('HTTP '+status+' is not parsed as a successful response',async()=>{
  await assert.rejects(createReadApi(async()=>new Response('PRIVATE',{status})).json('/api/tournaments'),e=>e.code==='HTTP_ERROR'&&e.status===status&&!e.message.includes('PRIVATE'));
});
test('HTML instead of JSON is rejected',async()=>{await assert.rejects(createReadApi(async()=>new Response('<html>PRIVATE</html>')).json('/api/tournaments'),/CONTENT_TYPE/);});
test('actual streamed size is bounded even without content length',async()=>{await assert.rejects(createReadApi(async()=>response({text:'x'.repeat(100)})).json('/api/tournaments',{maxBytes:16}),/RESPONSE_TOO_LARGE/);});
test('announced oversized response fails before body read',async()=>{const r=response({});r.headers.set('content-length','100');await assert.rejects(createReadApi(async()=>r).json('/api/tournaments',{maxBytes:20}),/RESPONSE_TOO_LARGE/);});
test('invalid UTF8 rejected, not replaced',async()=>{await assert.rejects(createReadApi(async()=>new Response(Uint8Array.of(255),{headers:{'content-type':'application/json'}})).json('/api/tournaments'),/INVALID_UTF8/);});
test('invalid JSON rejected',async()=>{await assert.rejects(createReadApi(async()=>new Response('{bad}',{headers:{'content-type':'application/json'}})).json('/api/tournaments'),/INVALID_JSON/);});
test('aborted before call never contacts transport',async()=>{const c=new AbortController();c.abort();let calls=0;await assert.rejects(createReadApi(()=>{calls++;}).json('/api/tournaments',{signal:c.signal}),/CANCELLED/);assert.equal(calls,0);});
test('stalled fetch is bounded even when transport ignores AbortSignal',async()=>{await assert.rejects(createReadApi(()=>new Promise(()=>{}),{timeoutMs:10}).json('/api/tournaments'),/TIMEOUT/);});
test('deadline includes a stalled response body and releases reader',async()=>{
  let cancelled=false;const stream=new ReadableStream({cancel(){cancelled=true;}});
  await assert.rejects(createReadApi(async()=>new Response(stream,{headers:{'content-type':'application/json'}}),{timeoutMs:10}).json('/api/tournaments'),/TIMEOUT/);await new Promise(r=>setImmediate(r));assert.equal(cancelled,true);
});
test('external cancellation during a request is distinguished from timeout',async()=>{
  const c=new AbortController();const result=createReadApi(()=>new Promise(()=>{})).json('/api/tournaments',{signal:c.signal});c.abort();await assert.rejects(result,/CANCELLED/);
});
test('transport errors do not expose original exception data',async()=>{const api=createReadApi(async()=>{throw Error('PRIVATE path secret');});await assert.rejects(api.json('/api/tournaments'),e=>e.code==='NETWORK_ERROR'&&!e.message.includes('PRIVATE'));});
test('tournament list projects only ID and name',()=>{const value=tournamentChoices([{id:id(1),name:'Synthetic',players:[{notes:'PRIVATE'}]}]);assert.deepEqual(Object.keys(value[0]),['id','name']);assert.equal(JSON.stringify(value).includes('PRIVATE'),false);});
test('duplicate IDs cannot alias selection choices',()=>assert.throws(()=>tournamentChoices([{id:id(1),name:'a'},{id:id(1),name:'b'}]),/INVALID_TOURNAMENT_LIST/));
test('invalid transport and invalid IDs are rejected',()=>{assert.throws(()=>createReadApi(null),/INVALID_TRANSPORT/);assert.throws(()=>requireId(id(0)),/INVALID_ID/);assert.throws(()=>requireId('../'),/INVALID_ID/);});
test('error label does not copy raw code or message',()=>assert.equal(errorText(new ReadError('PRIVATE')),'Daten konnten nicht sicher verarbeitet werden.'));
