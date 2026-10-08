import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import type { AuditJournalEntry } from '../src/api/contracts.ts';
import { auditCsvCell, buildAuditJournalCsv } from '../src/lib/auditCsv.ts';

for (const value of ['=1+2','+SUM(1)','-SUM(1)','@SUM(1)','\t=1','\nplain',' \u200b=1','\uff1d1','\uff0b1','\uff0d1','\uff201']) {
  test(`audit CSV prefixes formula/control text ${JSON.stringify(value)}`, () => {
    assert.equal(auditCsvCell(value), `"'${value}"`);
  });
}
test('audit CSV preserves invariant numbers, quoting and empty cells', () => {
  for (const value of [-3,'-3.5','0','123']) assert.equal(auditCsvCell(value), String(value));
  assert.equal(auditCsvCell('A;"B"'), '"A;""B"""');
  assert.equal(auditCsvCell(null), ''); assert.equal(auditCsvCell(undefined), '');
});
test('the actual audit export builder protects all untrusted fields without changing JSON', () => {
  const entry: AuditJournalEntry = { id:'synthetic', createdAt:'=date', action:'@action', severity:0,
    actor:'=actor', playerName:'+player', roundNumber:1, boardNumber:2,
    summary:'-summary', details:'\tdetails', reason:'\u200b=reason' };
  const before = JSON.stringify(entry);
  const result = buildAuditJournalCsv([entry], { date: value => value, severity: () => 'Info', action: value => String(value) });
  assert.equal(result, 'Zeitpunkt;Schweregrad;Aktion;Akteur;Runde;Brett;Spieler;Zusammenfassung;Details;Grund\r\n'+
    '"\'=date";Info;"\'@action";"\'=actor";1;2;"\'+player";"\'-summary";"\'\tdetails";"\'\u200b=reason"');
  assert.equal(JSON.stringify(entry), before);
  const app = readFileSync(new URL('../src/app/App.tsx', import.meta.url), 'utf8');
  assert.match(app, /buildAuditJournalCsv\(auditJournal,/);
  assert.match(app, /JSON\.stringify\(auditJournal, null, 2\)/);
});
