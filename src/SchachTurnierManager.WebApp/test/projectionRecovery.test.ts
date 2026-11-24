import test from 'node:test';
import assert from 'node:assert/strict';
import {appEffect,appHandler,deferred} from './appSourceHarness.ts';

for(const phase of ['error','ready','loading'] as const)test(`healthy unchanged polling handles a ${phase} projection without resetting inputs`,async()=>{
 let finished!:()=>void;const scheduled=new Promise<void>(resolve=>{finished=resolve;});
 let derived=0,delay=0;const loader={selectedId:'A',phase:phase as string};
 const draft={name:'Synthetic unsaved participant'};const original=JSON.stringify(draft);
 const effect=appEffect('readinessAfterProbe',{
  loadTournaments:async()=>[],projectionLoader:loader,
  loadDerived:async(id:string)=>{assert.equal(id,'A');derived++;loader.phase='ready';},
  requestJson:async()=>({status:'ok'}),setHealth(){},setBackendReadiness(){},setError(){},
  healthProbeTimeoutMs:3000,readinessAfterProbe:()=> 'online',steadyProbeIntervalMs:10000,nextProbeDelayMs:()=>400,
  readinessProbeGeneration:0,lang:'de',
  setTimeout(_action:unknown,value:number){delay=value;finished();return 1;},clearTimeout(){},
 });
 const cleanup=effect.run() as ()=>void;await scheduled;cleanup();
 assert.equal(derived,phase==='error'?1:0);
 assert.equal(delay,10000,'reuse the existing health-poll cadence, no additional timer');
 assert.equal(JSON.stringify(draft),original);
});
test('manual projection retry is single-flight even before React rerenders',async()=>{
 const pending=deferred<void>();let calls=0;const loader={selectedId:'A',phase:'error'};
 const retry=appHandler('retryDerivedProjection',{
  selectedTournament:{id:'A'},projectionLoader:loader,setError(){},lang:'de',describeApiError:String,
  loadDerived:async(id:string)=>{assert.equal(id,'A');calls++;loader.phase='loading';await pending.promise;loader.phase='ready';},
 });
 const first=retry();const second=retry();assert.equal(calls,1);
 pending.resolve();await Promise.all([first,second]);assert.equal(loader.phase,'ready');
});
