import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createTournamentProjectionLoader} from '../src/lib/tournamentProjection.ts';
import {selectNextTournamentId} from '../src/lib/destructiveActions.ts';
const deferred = <T>() => { let resolve!: (value:T)=>void, reject!: (error:Error)=>void;
  const promise = new Promise<T>((yes,no)=>{resolve=yes;reject=no;}); return {promise,resolve,reject}; };
test('late A replies cannot replace B, even when the producer ignores abort',async()=>{
 const states:unknown[]=[]; const loader=createTournamentProjectionLoader<string>(state=>states.push(state));
 loader.select('A'); const a=deferred<string>(); let aSignal:AbortSignal|undefined;
 const pendingA=loader.load('A',signal=>{aSignal=signal;return a.promise;});
 loader.select('B'); assert.equal(aSignal?.aborted,true);
 await loader.load('B',async()=>'B data'); a.resolve('A stale');
 assert.equal(await pendingA,false); assert.deepEqual(states.at(-1),{id:'B',phase:'ready',data:'B data'});
});
test('selection clears immediately and one complete current projection is published',async()=>{
 const states:unknown[]=[]; const loader=createTournamentProjectionLoader<string>(state=>states.push(state));
 loader.select('A'); await loader.load('A',async()=>'A data'); loader.select('B');
 assert.equal(loader.phase,'idle');
 assert.deepEqual(states.at(-1),{id:'B',phase:'idle',data:null});
 const b=deferred<string>(); const pending=loader.load('B',()=>b.promise);
 assert.equal(loader.phase,'loading');
 assert.deepEqual(states.at(-1),{id:'B',phase:'loading',data:null}); b.resolve('B data'); await pending;
 assert.deepEqual(states.at(-1),{id:'B',phase:'ready',data:'B data'});
 assert.equal(loader.phase,'ready');
});
test('mutation refresh for old A cannot clear or load selected B',async()=>{
 const states:unknown[]=[];const loader=createTournamentProjectionLoader<string>(state=>states.push(state));
 loader.select('B');await loader.load('B',async()=>'B data');const count=states.length;
 assert.equal(await loader.load('A',async()=>{throw Error('must not run');}),false);
 assert.equal(states.length,count);assert.equal(loader.selectedId,'B');
});
test('newer same-ID refresh and A/B/A selection invalidate old replies and auxiliary captures',async()=>{
 const states:unknown[]=[];const loader=createTournamentProjectionLoader<string>(state=>states.push(state));
 loader.select('A');const first=deferred<string>();const pending=loader.load('A',()=>first.promise);
 const old=loader.capture('A')!;await loader.load('A',async()=>'new A');first.resolve('old A');
 assert.equal(await pending,false);assert.equal(loader.isCurrent(old),false);
 const beforeSwitch=loader.capture('A')!;loader.select('B');loader.select('A');
 assert.equal(loader.isCurrent(beforeSwitch),false);assert.deepEqual(states.at(-1),{id:'A',phase:'idle',data:null});
});
test('stale errors are ignored and current errors clear the projection and remain actionable',async()=>{
 const states:unknown[]=[];const loader=createTournamentProjectionLoader<string>(state=>states.push(state));
 loader.select('A');const a=deferred<string>();const pending=loader.load('A',()=>a.promise);loader.select('B');
 a.reject(Error('stale failure'));assert.equal(await pending,false);
 await assert.rejects(loader.load('B',async()=>{throw Error('current failure');}),/current failure/);
 assert.deepEqual(states.at(-1),{id:'B',phase:'error',data:null});
});
test('empty selection and disposed loader never publish late data; strict lifecycle resume remains usable',async()=>{
 const states:unknown[]=[];const loader=createTournamentProjectionLoader<string>(state=>states.push(state));
 loader.select('A');const a=deferred<string>();const pending=loader.load('A',()=>a.promise);loader.dispose();a.resolve('late');
 assert.equal(await pending,false);assert.equal(loader.capture('A'),null);
 assert.equal(await loader.load('A',async()=>{throw Error('disposed');}),false);
 loader.resume();await loader.load('A',async()=>'fresh');loader.select('');
 assert.equal(await loader.load('',async()=>{throw Error('empty');}),false);
 assert.deepEqual(states.at(-1),{id:'',phase:'idle',data:null});
});
test('deleting A preserves a different current selection B',()=>{
 assert.equal(selectNextTournamentId([{id:'C'},{id:'B'}],'A','B'),'B');
 assert.equal(selectNextTournamentId([{id:'A'},{id:'C'}],'A','A'),'C');
});
test('a late list reply cannot resurrect a deleted tournament or change the current selection',async()=>{
 const lists:{id:string}[][]=[];
 const loader=createTournamentProjectionLoader<{id:string}[]>(state=>{
  if(state.phase==='ready' && state.data) lists.push(state.data);
 });
 loader.select('tournaments');const old=deferred<{id:string}[]>();
 const pending=loader.load('tournaments',()=>old.promise);
 await loader.load('tournaments',async()=>[{id:'B'}]);
 old.resolve([{id:'A'},{id:'B'}]);assert.equal(await pending,false);
 assert.deepEqual(lists,[[{id:'B'}]]);
 const app=readFileSync(new URL('../src/app/App.tsx',import.meta.url),'utf8');
 assert.match(app,/tournamentListLoader\.load\('tournaments', async signal/);
 assert.match(app,/return accepted \? data : null/);
});
test('the application routes all six derived results through one selection-bound projection',()=>{
 const app=readFileSync(new URL('../src/app/App.tsx',import.meta.url),'utf8');
 assert.match(app,/projectionLoader\.load\(id,/);assert.match(app,/signal \}\)/);
 assert.doesNotMatch(app,/setStandings\(|setCategories\(|setCrossTable\(|setHeroCup\(|setRoundDiagnostics\(|setAuditJournal\(/);
 assert.match(app,/projection\.id === selectedTournament\?\.id/);
});
