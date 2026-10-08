import test from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { mkdtempSync, mkdirSync, writeFileSync, copyFileSync, existsSync, rmSync, rmdirSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { discoverSuites, buildInvocation, requireNode, main } from '../../scripts/Run-NodeTestSuites.mjs';

const runner = fileURLToPath(new URL('../../scripts/Run-NodeTestSuites.mjs', import.meta.url));
function fixture(t, files = {}) {
  const root = mkdtempSync(join(tmpdir(), 'stm-node-suites-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  mkdirSync(join(root, 'tests', 'scripts'), { recursive: true });
  mkdirSync(join(root, 'scripts'));
  copyFileSync(runner, join(root, 'scripts', 'Run-NodeTestSuites.mjs'));
  for (const [name, source] of Object.entries(files)) writeFileSync(join(root, 'tests', 'scripts', name), source);
  return root;
}
function output() {
  let out = '', err = '';
  return { stdout: { write(value) { out += value; } }, stderr: { write(value) { err += value; } },
    out: () => out, err: () => err };
}
function cli(root, args = []) {
  const env = { ...process.env }; delete env.NODE_TEST_CONTEXT;
  return spawnSync(process.execPath, [join(root, 'scripts', 'Run-NodeTestSuites.mjs'), ...args], {
    cwd: tmpdir(), encoding: 'utf8', windowsHide: true, shell: false, env, timeout: 20000,
  });
}
const pass = "import test from 'node:test'; import assert from 'node:assert/strict'; test('synthetic',()=>assert.equal(1,1));\n";

for (const version of ['22.6.0', '22.16.0', '23.0.0', '24.0.0']) test(`accept supported Node ${version}`, () => assert.doesNotThrow(() => requireNode(version)));
for (const version of ['20.19.0', '22.5.1', '18.0.0', 'garbage', '', undefined]) test(`reject unsupported Node ${version}`, () => assert.throws(() => requireNode(version), /NODE_22_6_REQUIRED/));

test('suites are deterministically sorted and fixtures are not executed', t => {
  const root = fixture(t, { 'z.test.mjs': pass, 'A.test.mjs': pass, 'fixture.mjs': 'throw Error();', 'notes.txt': '' });
  mkdirSync(join(root, 'tests/scripts/fixtures')); writeFileSync(join(root, 'tests/scripts/fixtures/evil.test.mjs'), 'throw Error();');
  assert.deepEqual(discoverSuites(root).files, ['tests/scripts/A.test.mjs', 'tests/scripts/z.test.mjs']);
});
for (const extension of ['mjs','cjs','js','ts','mts','cts']) test(`discovers ${extension} suite`, t => {
  const root = fixture(t, { [`synthetic.test.${extension}`]: '' });
  assert.equal(discoverSuites(root).files[0], `tests/scripts/synthetic.test.${extension}`);
});
test('empty directory is an error rather than a green test run', t => assert.throws(() => discoverSuites(fixture(t)), /NO_TEST_SUITES/));
test('matching directory is rejected', t => {
  const root = fixture(t); mkdirSync(join(root, 'tests/scripts/not-a-file.test.mjs'));
  assert.throws(() => discoverSuites(root), /UNSAFE_TEST_FILE/);
});
test('too many test suites stop before execution', t => {
  const root = fixture(t, Object.fromEntries(Array.from({length:257},(_,i)=>[`${i}.test.mjs`,''])));
  assert.throws(() => discoverSuites(root), /TOO_MANY_TEST_SUITES/);
});
test('case-colliding suites cannot silently differ by platform', { skip: process.platform === 'win32' }, t => {
  const root = fixture(t, { 'a.test.mjs': '', 'A.test.mjs': '' });
  assert.throws(() => discoverSuites(root), /CASE_COLLIDING_TEST_FILES/);
});
test('symbolic test file is rejected', { skip: process.platform === 'win32' }, t => {
  const root = fixture(t); writeFileSync(join(root,'outside.mjs'),pass);
  symlinkSync(join(root,'outside.mjs'),join(root,'tests/scripts/link.test.mjs'));
  assert.throws(() => discoverSuites(root), /UNSAFE_TEST_FILE/);
});
test('linked test directory is rejected, including Windows junctions', t => {
  const root = fixture(t); rmdirSync(join(root,'tests/scripts')); mkdirSync(join(root,'elsewhere'));
  symlinkSync(join(root,'elsewhere'),join(root,'tests/scripts'),process.platform === 'win32' ? 'junction' : 'dir');
  assert.throws(() => discoverSuites(root), /UNSAFE_TEST_DIRECTORY/);
});
test('oversized command line fails rather than dropping suites', () => {
  assert.throws(() => buildInvocation({root:'.',files:['x'.repeat(13000)]}), /TEST_COMMAND_TOO_LONG/);
});
test('test invocation has no shell or separate visible console', () => {
  const call = buildInvocation({root:'/synthetic path',files:['tests/scripts/a & b.test.mjs']});
  assert.equal(call.executable, process.execPath); assert.equal(call.options.shell,false);
  assert.equal(call.options.windowsHide,true); assert.equal(call.options.detached,false);
  assert.deepEqual(call.options.stdio,['ignore','inherit','inherit']);
  assert.equal(call.args.at(-1),'tests/scripts/a & b.test.mjs'); assert.equal(call.args.at(-2),'--');
  assert.ok(call.args.includes('--experimental-strip-types')); assert.ok(call.args.includes('--test-concurrency=1'));
  assert.ok(call.args.includes('--test-timeout=300000')); assert.ok(!call.args.includes('--test-force-exit'));
});
test('list mode produces a machine-readable manifest without running tests', t => {
  const root=fixture(t,{'side-effect.test.mjs':"import fs from 'node:fs';fs.writeFileSync('unexpected','x');\n"});
  const result=cli(root,['--list']); assert.equal(result.status,0,result.stderr);
  assert.deepEqual(JSON.parse(result.stdout).files,['tests/scripts/side-effect.test.mjs']);
  assert.equal(existsSync(join(root,'unexpected')),false);
});
test('real child executes all suites from an unrelated working directory', t => {
  const root=fixture(t,{'a.test.mjs':pass,'b.test.mjs':pass}); const result=cli(root);
  assert.equal(result.status,0,result.stderr); assert.match(result.stdout,/# tests 2\b/);
  assert.match(result.stdout,/NODE_TEST_FILES=2/); assert.match(result.stdout,/NODE_TEST_RUNNER_EXIT=0/);
});
test('one failed assertion makes the real command fail', t => {
  const root=fixture(t,{'a.test.mjs':pass,'b.test.mjs':pass.replace('equal(1,1)','equal(1,2)')}); const result=cli(root);
  assert.equal(result.status,1,result.stderr); assert.match(result.stdout,/# fail 1\b/);
});
test('syntax failure cannot be reported as test success', t => {
  const root=fixture(t,{'bad.test.mjs':'export const = broken;'}); assert.notEqual(cli(root).status,0);
});
test('erased TypeScript is supported in a real suite', t => {
  const root=fixture(t,{'typed.test.mts':"import test from 'node:test'; import assert from 'node:assert/strict'; const v: number = 2; test('typed',()=>assert.equal(v,2));\n"});
  const result=cli(root); assert.equal(result.status,0,result.stderr); assert.match(result.stdout,/# pass 1\b/);
});
test('spaces and shell metacharacters in filenames remain literal', t => {
  const root=fixture(t,{'a & b.test.mjs':pass}); const result=cli(root);
  assert.equal(result.status,0,result.stderr); assert.match(result.stdout,/# tests 1\b/);
});
test('empty CLI run fails without spawning a test runner', t => {
  const result=cli(fixture(t)); assert.equal(result.status,2); assert.match(result.stderr,/NO_TEST_SUITES/);
});
for (const args of [['--bad'],['--list','--list'],['other-root'],['--help','--list']]) test(`unknown arguments ${args.join(' ')} fail`, async () => {
  const io=output(); assert.equal(await main(args,{...io}),2); assert.match(io.err(),/INVALID_ARGUMENTS/);
});
test('help does not require a test directory or start processes', async () => {
  const io=output(); assert.equal(await main(['--help'],{...io,repositoryRoot:'/not-there'}),0); assert.match(io.out(),/Usage:/);
});
for (const exit of [0,1,7]) test(`child exit ${exit} is preserved`, async t => {
  const root=fixture(t,{'a.test.mjs':pass}); const io=output();
  const result=await main([],{...io,repositoryRoot:root,spawnProcess(exe,args,options){
    assert.equal(Object.hasOwn(options.env,'NODE_TEST_CONTEXT'),false);
    assert.equal(options.env.NODE_OPTIONS,process.env.NODE_OPTIONS);
    const child=new EventEmitter(); queueMicrotask(()=>child.emit('close',exit,null)); return child;
  }}); assert.equal(result,exit);
});
for (const [signal,expected] of [['SIGINT',130],['SIGTERM',143],['SIGKILL',2]]) test(`signal ${signal} is not success`, async t => {
  const io=output(); const result=await main([],{...io,repositoryRoot:fixture(t,{'a.test.mjs':pass}),spawnProcess(){
    const child=new EventEmitter(); queueMicrotask(()=>child.emit('close',null,signal)); return child;
  }}); assert.equal(result,expected); assert.match(io.err(),/RUNNER_INTERRUPTED/);
});
test('spawn rejection does not disclose the raw exception',async t=>{
  const io=output();const code=await main([],{...io,repositoryRoot:fixture(t,{'a.test.mjs':pass}),spawnProcess(){throw Error('PRIVATE synthetic path');}});
  assert.equal(code,2);assert.ok(!io.err().includes('PRIVATE'));
});
test('spawn error followed by close cannot print a success marker',async t=>{
  const io=output();const code=await main([],{...io,repositoryRoot:fixture(t,{'a.test.mjs':pass}),spawnProcess(){
    const child=new EventEmitter();queueMicrotask(()=>{child.emit('error',Error('PRIVATE'));child.emit('close',0,null);});return child;
  }});assert.equal(code,2);assert.ok(!io.out().includes('NODE_TEST_RUNNER_EXIT=0'));assert.ok(!io.err().includes('PRIVATE'));
});
test('unknown child exit is an explicit error',async t=>{
  const io=output();const code=await main([],{...io,repositoryRoot:fixture(t,{'a.test.mjs':pass}),spawnProcess(){
    const child=new EventEmitter();queueMicrotask(()=>child.emit('close',null,null));return child;
  }});assert.equal(code,2);assert.match(io.err(),/RUNNER_EXIT_UNKNOWN/);
});
