// Test-only same-origin module, copied solely to the fresh source build by the
// headless smoke. No inline script, eval or relaxation of the page's CSP.
const scripts = [...document.querySelectorAll('script[type="module"][src]')]
  .filter(script => script.dataset.stmSmokeProbe !== 'true');
document.documentElement.dataset.stmSmokeModules = 'pending';
if (!scripts.length || scripts.length > 32 || scripts.some(script => new URL(script.src).origin !== location.origin)) {
  document.documentElement.dataset.stmSmokeModules = 'error';
} else {
  // import() resolves only after successful evaluation, including a cached module.
  // Element "load" alone would also fire after a module's top-level throw.
  Promise.all(scripts.map(script => import(script.src))).then(
    () => { document.documentElement.dataset.stmSmokeModules = 'loaded'; },
    () => { document.documentElement.dataset.stmSmokeModules = 'error'; }
  );
}
