import { installBackupReader } from './ui.js';
const view = installBackupReader(document);
window.addEventListener('pagehide', () => view.clear());
