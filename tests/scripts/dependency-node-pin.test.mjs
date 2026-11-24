import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync,lstatSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {resolve,relative,sep} from 'node:path';
const root=fileURLToPath(new URL('../../',import.meta.url));
const pkg=JSON.parse(readFileSync(resolve(root,'src/SchachTurnierManager.WebApp/package.json'),'utf8'));
const lock=JSON.parse(readFileSync(resolve(root,'src/SchachTurnierManager.WebApp/package-lock.json'),'utf8'));
test('CI resolves the reviewed Node version file from the actual repository root',()=>{
 const workflow=readFileSync(resolve(root,'.github/workflows/ci.yml'),'utf8');
 const values=[...workflow.matchAll(/^\s*node-version-file:\s*['"]?([^'"\s#]+)['"]?\s*$/gm)].map(m=>m[1]);
 assert.ok(values.length>0,'frontend CI must use the repository version pin');
 for(const value of values){
  const path=resolve(root,value),inside=relative(root,path);
  assert.ok(!inside.startsWith('..'+sep)&&inside!=='..');
  assert.ok(existsSync(path),`Missing CI Node version file: ${value}`);
  assert.ok(lstatSync(path).isFile()&&!lstatSync(path).isSymbolicLink());
  assert.match(readFileSync(path,'utf8').trim(),/^\d+\.\d+\.\d+$/);
 }
});
test('manifest and lock require the same reviewed Node patch as the repo pin',()=>{
 const pin=readFileSync(resolve(root,'.node-version'),'utf8').trim(),major=Number(pin.split('.')[0]);
 assert.equal(pkg.engines.node,`>=${pin} <${major+1}`);
 assert.equal(lock.packages[''].engines.node,pkg.engines.node);
});
