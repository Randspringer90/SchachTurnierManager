import test from 'node:test';
import assert from 'node:assert/strict';
import { MAX_BYTES, readSnapshot, compareBackupBytes, compareBackupFiles } from '../../src/SchachTurnierManager.WebApp/public/backup-compare/core.mjs';
const id = n => '00000000-0000-0000-0000-'+n.toString(16).padStart(12,'0');
const fixture = () => ({id:id(1),name:'Synthetic',settings:{plannedRounds:5},players:[{id:id(2),name:'Alpha',rating:{elo:1500}},{id:id(3),name:'Beta',rating:{elo:1600}}],rounds:[{roundNumber:1,pairings:[{whitePlayerId:id(2),blackPlayerId:id(3),result:{kind:'Open'}}]}],auditJournal:[{id:id(4),summary:'Synthetic change'}]});
const bytes = value => new TextEncoder().encode(typeof value==='string'?value:JSON.stringify(value));
const compare = (a,b) => compareBackupBytes(bytes(a),bytes(b));
test('identical backup has no differences',()=>{const a=fixture(); assert.equal(compare(a,a).sameComparedContent,true);});
test('JSON whitespace and object key order ignored',()=>{const a=fixture(),text=JSON.stringify(a,null,2); const b=Object.fromEntries(Object.entries(a).reverse());assert.equal(compare(text,b).sameComparedContent,true);});
test('top-level player round audit ordering ignored',()=>{const a=fixture();a.rounds.push({roundNumber:2,pairings:[]});a.auditJournal.push({id:id(5)});const b=structuredClone(a);b.players.reverse();b.rounds.reverse();b.auditJournal.reverse();assert.equal(compare(a,b).sameComparedContent,true);});
for(const [key,newRecord] of [['players',{id:id(9),name:'Added'}],['rounds',{roundNumber:2,pairings:[]}],['auditJournal',{id:id(9),summary:'Added'}]]) test(`add/remove ${key}`,()=>{const a=fixture(),b=structuredClone(a);b[key].push(newRecord);const group=key==='auditJournal'?'audit':key; assert.equal(compare(a,b)[group].added,1);assert.equal(compare(b,a)[group].removed,1);});
for(const [label,mutate,group] of [
 ['player rating',s=>s.players[0].rating.elo=1400,'players'],
 ['player name',s=>s.players[0].name='Changed','players'],
 ['round result',s=>s.rounds[0].pairings[0].result.kind='WhiteWin','rounds'],
 ['round lock',s=>s.rounds[0].isLocked=true,'rounds'],
 ['audit entry',s=>s.auditJournal[0].summary='Changed','audit']
]) test(label,()=>{const a=fixture(),b=structuredClone(a);mutate(b);assert.equal(compare(a,b)[group].changed,1);assert.equal(compare(a,b).sameComparedContent,false);});
for(const [label,mutate] of [['name',s=>s.name='Other'],['settings',s=>s.settings.plannedRounds=7],['unknown root field',s=>s.extension={new:true}]]) test(`metadata ${label}`,()=>{const a=fixture(),b=structuredClone(a);mutate(b);assert.equal(compare(a,b).metadataChanged,true);});
test('array order inside records is preserved',()=>{const a=fixture();a.players[0].tags=['a','b'];const b=structuredClone(a);b.players[0].tags.reverse();assert.equal(compare(a,b).players.changed,1);});
test('different tournament rejected not auto matched by name',()=>{const a=fixture(),b=fixture();b.id=id(10);assert.throws(()=>compare(a,b),/DIFFERENT_TOURNAMENT/);});
test('GUID case recognized for identity',()=>{const a=fixture(),b=fixture();a.id=id(0xabc);b.id=a.id.toUpperCase();assert.doesNotThrow(()=>compare(a,b));});
test('PascalCase native root accepted',()=>{const a=fixture();const b={Id:a.id,Name:a.name,Settings:{PlannedRounds:5},Players:a.players.map(p=>({Id:p.id,Name:p.name})),Rounds:[{RoundNumber:1,Pairings:[]}],AuditJournal:[]};assert.equal(compare(b,b).sameComparedContent,true);});
test('optional missing audit list means empty list',()=>{const a=fixture();delete a.auditJournal;const b=structuredClone(a);b.auditJournal=[];assert.equal(compare(a,b).sameComparedContent,true);});
test('initial UTF-8 BOM accepted',()=>{const a=fixture();assert.equal(compare('\ufeff'+JSON.stringify(a),a).sameComparedContent,true);});
for(const [name,edit,code] of [
 ['duplicate player',s=>s.players.push(s.players[0]),'DUPLICATE_ID'],
 ['duplicate round',s=>s.rounds.push(s.rounds[0]),'DUPLICATE_ID'],
 ['duplicate audit',s=>s.auditJournal.push(s.auditJournal[0]),'DUPLICATE_ID'],
 ['missing id',s=>delete s.id,'INVALID_BACKUP'],
 ['zero id',s=>s.id=id(0),'INVALID_ID'],
 ['invalid id',s=>s.id='no','INVALID_ID'],
 ['missing players',s=>delete s.players,'INVALID_BACKUP'],
 ['missing rounds',s=>delete s.rounds,'INVALID_BACKUP'],
 ['null settings',s=>s.settings=null,'INVALID_BACKUP'],
 ['wrong name',s=>s.name=3,'INVALID_BACKUP'],
 ['bad collection',s=>s.players={},'INVALID_COLLECTION'],
 ['null player',s=>s.players=[null],'INVALID_BACKUP'],
 ['null audit',s=>s.auditJournal=null,'INVALID_COLLECTION'],
 ['zero round',s=>s.rounds[0].roundNumber=0,'INVALID_ROUND'],
 ['fractional round',s=>s.rounds[0].roundNumber=1.5,'INVALID_ROUND'],
 ['string round',s=>s.rounds[0].roundNumber='1','INVALID_ROUND'],
 ['ambiguous id case',s=>s.Id=s.id,'AMBIGUOUS_FIELD'],
 ['ambiguous players case',s=>s.Players=s.players,'AMBIGUOUS_FIELD'],
 ['huge collection',s=>s.players=Array.from({length:5001},(_,n)=>({id:id(n+2)})),'INVALID_COLLECTION']
])test(name,()=>{const a=fixture();edit(a);assert.throws(()=>readSnapshot(bytes(a)),new RegExp(code));});
for(const text of ['','{} trailing','{','{"a":1,}','[1,]','NaN','undefined','{"a":"bad\nstring"}','{"a":"\\x00"}','{"a":01}','{"a":.5}','{"a":true false}'])test(`invalid input ${JSON.stringify(text)}`,()=>assert.throws(()=>readSnapshot(bytes(text))));
for(const text of ['{"id":1,"id":2}','{"id":1,"\\u0069d":2}','{"x":{"a":1,"a":2}}'])test('duplicate keys rejected '+text,()=>assert.throws(()=>readSnapshot(bytes(text)),/DUPLICATE_KEY/));
test('invalid UTF-8 rejected',()=>assert.throws(()=>readSnapshot(new Uint8Array([0xff])),/INVALID_UTF8/));
test('oversized bytes rejected',()=>assert.throws(()=>readSnapshot(new Uint8Array(MAX_BYTES+1)),/INVALID_SIZE/));
test('non-byte input rejected',()=>assert.throws(()=>readSnapshot('{}'),/INVALID_BYTES/));
test('deep JSON rejected',()=>assert.throws(()=>readSnapshot(bytes('['.repeat(34)+'0'+']'.repeat(34))),/TOO_COMPLEX/));
test('node budget enforced',()=>assert.throws(()=>readSnapshot(bytes('['+Array(100001).fill('0').join(',')+']')),/TOO_COMPLEX/));
test('large integers are not silently rounded to equality',()=>{const s=JSON.stringify(fixture()).slice(0,-1);assert.equal(compare(s+',"x":9007199254740992}',s+',"x":9007199254740993}').metadataChanged,true);});
test('precise decimals are not silently rounded to equality',()=>{const s=JSON.stringify(fixture()).slice(0,-1);assert.equal(compare(s+',"x":0.10000000000000000001}',s+',"x":0.1}').metadataChanged,true);});
test('numeric spelling deliberately compared conservatively',()=>{const s=JSON.stringify(fixture());assert.equal(compare(s,s.replace('"plannedRounds":5','"plannedRounds":5.0')).metadataChanged,true);});
test('prototype-like keys stay data',()=>{const s=JSON.stringify(fixture()).slice(0,-1)+',"__proto__":{"polluted":true},"constructor":"data"}';assert.equal(compare(s,s).sameComparedContent,true);assert.equal({}.polluted,undefined);});
test('record comparison considers unknown nested fields',()=>{const a=fixture(),b=fixture();b.players[0].future={x:[1,true,null,'v']};assert.equal(compare(a,b).players.changed,1);});
test('detail output capped without losing totals',()=>{const a=fixture();a.players=[];const b=fixture();b.players=Array.from({length:300},(_,n)=>({id:id(n+10),name:'Synthetic'}));const r=compare(a,b);assert.equal(r.players.added,300);assert.equal(r.players.details.length,200);assert.equal(r.players.omitted,100);});
test('output does not include names or raw audit text',()=>{const a=fixture(),b=fixture();b.players[0].name='PRIVATE-SYNTHETIC';b.auditJournal[0].summary='<img src=x onerror=alert(1)>';const r=JSON.stringify(compare(a,b));assert.equal(r.includes('PRIVATE'),false);assert.equal(r.includes('<img'),false);});
test('input bytes unchanged',()=>{const a=bytes(fixture()),copy=a.slice();compareBackupBytes(a,a);assert.deepEqual(a,copy);});
const file = b => ({size:b.length,arrayBuffer:async()=>b.buffer});
test('file pipeline returns comparison',async()=>{const a=bytes(fixture());assert.equal((await compareBackupFiles(file(a),file(a))).sameComparedContent,true);});
test('invalid sizes rejected before any reads',async()=>{let reads=0;await assert.rejects(compareBackupFiles({size:1,arrayBuffer:async()=>{reads++;}},{size:MAX_BYTES+1,arrayBuffer:async()=>{reads++;}}),/INVALID_SIZE/);assert.equal(reads,0);});
test('size drift fails',async()=>{await assert.rejects(compareBackupFiles({size:2,arrayBuffer:async()=>new ArrayBuffer(1)},{size:1,arrayBuffer:async()=>new ArrayBuffer(1)}),/FILE_CHANGED/);});
test('file error is not swallowed',async()=>{await assert.rejects(compareBackupFiles({size:1,arrayBuffer:async()=>{throw Error('READ_ERROR');}},{size:1,arrayBuffer:async()=>new ArrayBuffer(1)}),/READ_ERROR/);});
