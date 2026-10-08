import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stampServiceWorker} from '../../src/SchachTurnierManager.WebApp/service-worker-build.mjs';
const worker='self.addEventListener("install", event => {});\n';
const files=[['index.html','<script src="/assets/v1.js"></script>'],['assets/v1.js','export const value=1;'],['startup-guard.js','/* public shell */']];
test('the generated worker changes when only HTML, a bundle or a public shell changes',()=>{
 const original=stampServiceWorker(worker,files);
 for(let i=0;i<files.length;i++){
  const changed=files.map(([name,value],index)=>[name,value+(index===i?' changed':'')]);
  assert.notEqual(stampServiceWorker(worker,changed),original);
 }
 assert.notEqual(stampServiceWorker(worker+'// changed worker',files),original);
 assert.match(original,/^\/\/ STM shell build fingerprint: [a-f0-9]{64}\n/);
});
test('fingerprint is reproducible, order-independent and does not hash its previous stamp',()=>{
 const stamped=stampServiceWorker(worker,files);
 assert.equal(stampServiceWorker(worker,[...files].reverse()),stamped);
 assert.equal(stampServiceWorker(stamped,files),stamped);
});
test('old and new outputs keep one complete worker body and stable cache slots',()=>{
 const source=readFileSync(new URL('../../src/SchachTurnierManager.WebApp/public/service-worker.js',import.meta.url),'utf8');
 const first=stampServiceWorker(source,files),second=stampServiceWorker(source,[...files,['privacy-curtain/main.js','new shell']]);
 assert.notEqual(first,second);
 assert.equal(first.substring(first.indexOf('\n')+1),source);
 assert.equal(second.substring(second.indexOf('\n')+1),source);
});
test('fingerprint rejects duplicate, colliding and escaping resource names',()=>{
 for(const extra of [['index.html','duplicate'],['INDEX.HTML','collision'],['../outside.js','escape'],['/absolute.js','escape'],['a\\b.js','alias']]){
  assert.throws(()=>stampServiceWorker(worker,[...files,extra]));
 }
 assert.throws(()=>stampServiceWorker(worker,[['assets/v1.js','missing html']]));
});
test('Vite build wires the post-write fingerprint and keeps PWA contracts mandatory',()=>{
 const config=readFileSync(new URL('../../src/SchachTurnierManager.WebApp/vite.config.ts',import.meta.url),'utf8');
 const pkg=JSON.parse(readFileSync(new URL('../../src/SchachTurnierManager.WebApp/package.json',import.meta.url),'utf8'));
 assert.match(config,/serviceWorkerBuildFingerprint\(\)/);
 assert.match(pkg.scripts['test:pwa'],/service-worker\.test\.mjs/);
 assert.match(pkg.scripts['test:pwa'],/service-worker-build\.test\.mjs/);
 assert.equal(pkg.scripts.prebuild,'npm run test:pwa');
});
