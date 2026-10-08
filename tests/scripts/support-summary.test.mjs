import test from 'node:test';
import assert from 'node:assert/strict';
import { MAX_BYTES, summarizeBackup, summarizeFile } from '../../src/SchachTurnierManager.WebApp/public/support-summary/core.js';
const fixture = () => ({id:'PRIVATE-ID',name:'PRIVATE-NAME',settings:{title:'PRIVATE-SETTINGS',rating:2222},players:[{name:'PRIVATE-PLAYER',id:'PRIVATE-PLAYER-ID'}],rounds:[{roundNumber:1,pairings:[{notes:'PRIVATE-NOTES'}],isLocked:true,isVerified:false}],auditJournal:[{summary:'PRIVATE-AUDIT',path:'PRIVATE-PATH'}],date:'PRIVATE-DATE',other:'PRIVATE-UNKNOWN'});
const bytes = value => new TextEncoder().encode(typeof value === 'string' ? value : JSON.stringify(value));
const summary = value => summarizeBackup(bytes(value));
const code = expected => failure => failure.code === expected;
test('counts are projected from the native structure',()=>assert.deepEqual(summary(fixture()).counts,{players:1,rounds:1,pairings:1,auditEntries:1,lockedRounds:1,verifiedRounds:0}));
test('no free text IDs names dates hashes paths or settings values leave projection',()=>{const value=JSON.stringify(summary(fixture()));assert.equal(value.includes('PRIVATE-'),false);assert.equal(value.includes('2222'),false);assert.equal(value.includes('sha256'),false);});
test('fresh empty tournament is supported',()=>{const f=fixture();f.players=[];f.rounds=[];f.auditJournal=[];assert.deepEqual(summary(f).counts,{players:0,rounds:0,pairings:0,auditEntries:0,lockedRounds:0,verifiedRounds:0});});
test('known PascalCase root and round fields supported',()=>{const f={Id:'X',Name:'Y',Settings:{},Players:[],Rounds:[{Pairings:[],IsLocked:false,IsVerified:true}],AuditJournal:[]};assert.equal(summary(f).counts.verifiedRounds,1);});
test('absent optional audit and flags counted as empty/false',()=>{const f=fixture();delete f.auditJournal;delete f.rounds[0].isLocked;delete f.rounds[0].isVerified;assert.equal(summary(f).counts.auditEntries,0);assert.equal(summary(f).counts.lockedRounds,0);});
test('multiple rounds aggregate correctly',()=>{const f=fixture();f.rounds.push({pairings:[{},{}],isLocked:true,isVerified:true});assert.equal(summary(f).counts.pairings,3);assert.equal(summary(f).counts.lockedRounds,2);assert.equal(summary(f).counts.verifiedRounds,1);});
test('BOM and CRLF accepted',()=>assert.equal(summary('\ufeff'+JSON.stringify(fixture(),null,2).replaceAll('\n','\r\n')).counts.players,1));
test('unknown fields are omitted even with hostile property names',()=>{const s=JSON.stringify(fixture()).slice(0,-1)+',"__proto__":{"leaked":true},"constructor":"PRIVATE"}';assert.equal(JSON.stringify(summary(s)).includes('PRIVATE'),false);assert.equal({}.leaked,undefined);});
for (const malformed of ['{"x":1,"x":2}','{"x":1,"\\u0078":2}','{"a":{"x":1,"x":2}}'])test('reject duplicate '+malformed,()=>assert.throws(()=>summary(malformed),code('DUPLICATE_KEY')));
for (const malformed of ['', '{', '[]','null','{"x":1,}','{} trailing','{"x":01}','{"x":"bad\nstring"}','{"x":"\\q"}','{"x":NaN}'])test('reject invalid structure '+JSON.stringify(malformed),()=>assert.throws(()=>summary(malformed)));
for(const [name,mutate] of [
 ['missing settings',f=>delete f.settings],['nonobject settings',f=>f.settings=[]],['missing players',f=>delete f.players],
 ['null player',f=>f.players=[null]],['nonobject round',f=>f.rounds=[7]],['missing pairings',f=>delete f.rounds[0].pairings],
 ['invalid pairings',f=>f.rounds[0].pairings=[null]],['invalid flags',f=>f.rounds[0].isLocked='yes'],
 ['ambiguous root',f=>f.Players=[]],['ambiguous flags',f=>f.rounds[0].IsLocked=true],['null audit',f=>f.auditJournal=null]
])test(name,()=>{const f=fixture();mutate(f);assert.throws(()=>summary(f));});
test('too many collection members rejected',()=>{const f=fixture();f.players=Array.from({length:5001},()=>({}));assert.throws(()=>summary(f),code('INVALID_BACKUP'));});
test('depth budget enforced',()=>assert.throws(()=>summary('['.repeat(34)+'0'+']'.repeat(34)),code('TOO_COMPLEX')));
test('node budget enforced',()=>assert.throws(()=>summary('['+Array(100001).fill('0').join(',')+']'),code('TOO_COMPLEX')));
test('invalid UTF-8 rejected',()=>assert.throws(()=>summarizeBackup(new Uint8Array([255])),code('INVALID_UTF8')));
test('oversized bytes rejected',()=>assert.throws(()=>summarizeBackup(new Uint8Array(MAX_BYTES+1)),code('INVALID_SIZE')));
test('source bytes are unchanged',()=>{const b=bytes(fixture()),copy=b.slice();summarizeBackup(b);assert.deepEqual(b,copy);});
test('same input yields same report without timestamps',()=>assert.deepEqual(summary(fixture()),summary(fixture())));
test('real file pipeline',async()=>assert.deepEqual(await summarizeFile(new Blob([bytes(fixture())])),summary(fixture())));
test('invalid size stops before reading',async()=>{let reads=0;await assert.rejects(summarizeFile({size:MAX_BYTES+1,arrayBuffer(){reads++;}}),code('INVALID_SIZE'));assert.equal(reads,0);});
test('file length mismatch rejected',async()=>await assert.rejects(summarizeFile({size:2,arrayBuffer:async()=>new ArrayBuffer(1)}),code('FILE_CHANGED')));
test('failed read is not a report',async()=>await assert.rejects(summarizeFile({size:1,arrayBuffer:async()=>{throw Error('PRIVATE');}}),/PRIVATE/));
