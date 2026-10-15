// Application bootstrap.
//
// Everything else lives in dedicated modules:
//   api/       backend contracts and the fetch client
//   app/       application shell and navigation model
//   components/ reusable UI (dialogs, QR, Chess960 dice)
//   features/  self-contained screens (mobile companion)
//   lib/       pure helpers (labels, forms, chess960, assistant, knowledge)
import ReactDOM from 'react-dom/client';
import { I18nProvider } from './i18n';
import { ErrorBoundary, createPrivateRootErrorOptions } from './components/ErrorBoundary';
import { App } from './app/App';
import { MobileDicePage } from './features/mobile-companion/MobileDicePage';
import { parseBoardDiceParams } from './lib/chess960';
import './styles.css';

const boardDiceParams = parseBoardDiceParams(window.location.search);

// Root handlers keep raw exception text out of production consoles (STM-SEC-003).
ReactDOM.createRoot(document.getElementById('root')!, createPrivateRootErrorOptions(import.meta.env.DEV)).render(
  <ErrorBoundary>
    <I18nProvider>
      {boardDiceParams ? <MobileDicePage params={boardDiceParams} /> : <App />}
    </I18nProvider>
  </ErrorBoundary>
);
