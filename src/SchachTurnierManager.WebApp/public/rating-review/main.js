import { installRatingReview } from './ui.js';
const view = installRatingReview(document);
window.addEventListener('pagehide', () => view.clear());
