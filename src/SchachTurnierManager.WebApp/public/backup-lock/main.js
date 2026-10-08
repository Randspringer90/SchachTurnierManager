import { installBackupLock } from './ui.js';
const view = installBackupLock(document);
window.addEventListener('pagehide', () => view.clear());
