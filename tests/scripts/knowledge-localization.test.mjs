import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {runInNewContext} from 'node:vm';
const projectRequire=createRequire(new URL('../../src/SchachTurnierManager.WebApp/package.json',import.meta.url));
const ts=projectRequire('typescript');
const sourceUrl=new URL('../../src/SchachTurnierManager.WebApp/src/lib/knowledge.ts',import.meta.url);
const source=readFileSync(sourceUrl,'utf8');
const compiled=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,esModuleInterop:true}});
let forbidden=0;const deny=()=>{forbidden++;throw Error('Knowledge help must stay local and read-only');};
const module={exports:{}};
runInNewContext(compiled.outputText,{module,exports:module.exports,fetch:deny,localStorage:{setItem:deny},require(name){
 if(!/^\.\.\/knowledge\/localKnowledgeBase(?:\.en)?\.json$/.test(name))throw Error('Unexpected knowledge dependency');
 return JSON.parse(readFileSync(new URL(name,sourceUrl),'utf8'));
}},{timeout:1000});
const api=module.exports;
const recommendation={formatLabel:'Swiss system',plannedRounds:5,estimatedTotalMinutes:120,warnings:[]};
const cases=[
 ['How do I start a tournament?','Tournament start'],
 ['Why this pairing?','Pairing and pairing audit'],
 ['What should I do after round 3?','Backup and recovery'],
 ['What does Buchholz Cut mean?','Scoring and tie-breaks'],
 ['How do I back up my tournament?','Backup and recovery'],
 ['How do I use QR/mobile?','QR/mobile and Chess960'],
 ['When should I use the assistant?','Using the tournament assistant'],
 ['What data is sent to AI?','AI help and privacy'],
];
for(const [question,title] of cases)test(`English local help selects ${title}`,()=>{
 const answer=api.buildLocalKnowledgeAnswer(question,undefined,recommendation,'en');
 assert.ok(answer.text.startsWith('**'+title+'**'),answer.text.split('\n')[0]);
 assert.match(answer.text,/Next steps:/);
 assert.match(answer.text,/No tournament data was sent to external AI services/);
 assert.doesNotMatch(answer.text,/Nächste Schritte|Diese Antwort kommt/);
 assert.ok(answer.sources.length>0);
});
test('a German question retained after language switch receives an English privacy answer',()=>{
 const answer=api.buildLocalKnowledgeAnswer('Welche Daten gehen an KI?',undefined,recommendation,'en');
 assert.match(answer.text,/^\*\*AI help and privacy\*\*/);
});
test('catalogue languages keep the same topic IDs, references and local-only provider',()=>{
 const german=api.getLocalKnowledgeBase('de'),english=api.getLocalKnowledgeBase('en');
 assert.deepEqual(Array.from(english.topics,x=>x.id),Array.from(german.topics,x=>x.id));
 assert.equal(english.providerMode,'local-only');assert.equal(german.providerMode,'local-only');
 assert.equal(english.quickQuestions.length,8);
 for(let i=0;i<english.topics.length;i++){assert.ok(english.topics[i].answer.length>0);assert.equal(english.topics[i].steps.length,german.topics[i].steps.length);assert.deepEqual(Array.from(english.topics[i].sources),Array.from(german.topics[i].sources));}
 assert.equal(api.getLocalKnowledgeBase('fr'),english,'preview language uses the established English fallback');
});
test('mobile help describes the actual queue limits and secure LAN prerequisite in both languages',()=>{
 for(const lang of ['de','en']){
  const topic=api.getLocalKnowledgeBase(lang).topics.find(x=>x.id==='mobile');
  assert.match(topic.answer,/200/);assert.match(topic.answer,/TLS/);
  assert.doesNotMatch(topic.answer,/noch nicht aktiv|not active yet/);
 }
});
test('English tournament context includes synthetic state without mutation or external calls',()=>{
 const tournament={name:'Synthetic local context',players:[{status:0},{status:1}],rounds:[{roundNumber:2}]};
 const before=JSON.stringify(tournament);
 const answer=api.buildLocalKnowledgeAnswer('How do I back up my tournament?',tournament,recommendation,'en');
 assert.match(answer.text,/1\/2 active participants/);assert.match(answer.text,/Latest known round: 2/);
 assert.equal(JSON.stringify(tournament),before);assert.equal(forbidden,0);
});
