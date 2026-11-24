import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { runInNewContext } from 'node:vm';
import * as options from '../../src/SchachTurnierManager.WebApp/src/lib/tournamentOptions.ts';
const projectRequire = createRequire(new URL('../../src/SchachTurnierManager.WebApp/package.json', import.meta.url));
const ts = projectRequire('typescript');
const source = readFileSync(new URL('../../src/SchachTurnierManager.WebApp/src/lib/labels.ts', import.meta.url), 'utf8');
const compiled = ts.transpileModule(source, {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}});
const module = {exports:{}};
runInNewContext(compiled.outputText,{module,exports:module.exports,Date,require(name){
  if(name==='./tournamentOptions')return options;
  if(name==='./auditCsv')return {};
  throw Error('Unexpected runtime dependency');
}},{timeout:1000});
const {optionLabel,formatOptions,scoringOptions,forfeitPolicyOptions,unplayedRoundBuchholzOptions}=options;
const {auditActionLabel,auditSeverityLabel,auditDateLabel,importPreviewStatusLabel,duplicateKindLabel,pwaStatusLabel,tiebreakLabel}=module.exports;
test('English settings retain numeric values and translate their meaning', () => {
  assert.equal(optionLabel(formatOptions.find(x => x.value === 0), true), 'Round robin');
  assert.equal(optionLabel(formatOptions.find(x => x.value === 1), true), 'Swiss system');
  assert.equal(optionLabel(scoringOptions.find(x => x.value === 0), true), 'Classic: win 1 · draw ½ · loss 0');
  assert.match(optionLabel(forfeitPolicyOptions.find(x => x.value === 0), true), /Exclude forfeits/);
  assert.match(optionLabel(unplayedRoundBuchholzOptions.find(x => x.value === 1), true), /FIDE mode/);
  assert.equal(optionLabel(formatOptions.find(x => x.value === 0)), 'Jeder gegen Jeden');
});
test('audit action labels preserve action codes and distinguish review reversals', () => {
  assert.equal(auditActionLabel('ResultRecorded', true), 'Result recorded');
  assert.equal(auditActionLabel(21, true), 'Result recorded');
  assert.equal(auditActionLabel('RoundVerified', true), 'Round reviewed');
  assert.equal(auditActionLabel('RoundUnverified', true), 'Review revoked');
  assert.equal(auditActionLabel('FutureAction', true), 'FutureAction');
  assert.equal(auditSeverityLabel('Critical', true), 'critical');
  assert.equal(auditActionLabel('RoundVerified'), 'Runde geprüft');
});
test('English import and readiness labels are not German fallbacks', () => {
  assert.equal(importPreviewStatusLabel(2, true), 'blocked');
  assert.equal(duplicateKindLabel(2, true), 'Name + birth year');
  assert.equal(pwaStatusLabel('update-available', true), 'PWA update available');
  assert.equal(tiebreakLabel(0, true), 'Direct encounter');
});
test('audit date honours the selected locale and retains invalid-date fallback', () => {
  const input='2026-10-28T10:30:00Z';
  assert.equal(auditDateLabel(input, 'en'), new Date(input).toLocaleString('en', {dateStyle:'short',timeStyle:'short'}));
  assert.equal(auditDateLabel(input, 'de'), new Date(input).toLocaleString('de', {dateStyle:'short',timeStyle:'short'}));
  assert.equal(auditDateLabel('invalid', 'en'), 'invalid');
});

// Exercise the actual recommendation module; language must not change rules/payloads.
import * as assistantHelpers from '../../src/SchachTurnierManager.WebApp/src/lib/assistant.ts';
const assistantSource = readFileSync(new URL('../../src/SchachTurnierManager.WebApp/src/lib/tournamentAssistant.ts', import.meta.url), 'utf8');
const assistantCompiled = ts.transpileModule(assistantSource, {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}});
const assistantModule={exports:{}};
runInNewContext(assistantCompiled.outputText,{module:assistantModule,exports:assistantModule.exports,require(name){
  if(name==='./assistant')return assistantHelpers;
  if(name==='./tournamentOptions')return options;
  throw Error('Unexpected assistant runtime dependency');
}},{timeout:1000});
const {buildTournamentAssistantRecommendation:recommend,defaultTournamentAssistantForm:defaults}=assistantModule.exports;
for(const scenario of ['club-night','youth','open','blitz','chess960','team']) {
  test(`${scenario}: translation preserves planning values, limits and warnings`,()=>{
    for(const playerCount of ['2','8','12','512']) {
      const form={...defaults,scenario,playerCount,boardCount:'1',availableMinutes:'30',rated:true};
      const german=recommend(form),english=recommend(form,true);
      for(const key of ['format','plannedRounds','scoringSystem','estimatedRoundMinutes','estimatedTotalMinutes','estimatedBoards','timeFit'])assert.equal(english[key],german[key],key);
      assert.equal(english.warnings.length,german.warnings.length);
      assert.match(english.title,/round\(s\)/);
      assert.match(english.handoffPrompt,/^Plan a /);
      assert.equal(english.setupSteps.some(x=>x.includes('Teilnehmer')),false);
      assert.equal(english.operatorChecklist.includes('Save audit evidence and a backup after each round'),true);
    }
  });
}
