import React from 'react';

// Independent bilingual fallback: the translation provider may itself have failed.
// Exception payloads can contain names, paths or server data; never inspect them here.
const ERROR_REFERENCE = 'UI_RENDER_FAILURE';
type ErrorBoundaryProps = { children: React.ReactNode };
type ErrorBoundaryState = { hasError: boolean };

export class ErrorBoundary extends React.Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(_error: unknown): ErrorBoundaryState {
    return { hasError: true };
  }

  componentDidCatch(_error: unknown): void {
    // Deliberately log only a stable diagnostic, not the original exception/stack.
    // React/browser development diagnostics are outside this boundary's control.
    console.error(`[SchachTurnierManager] ${ERROR_REFERENCE}`);
  }

  private handleReload = (): void => {
    window.location.reload();
  };

  render(): React.ReactNode {
    if (!this.state.hasError) {
      return this.props.children;
    }

    return (
      <div role="alert" className="app-error-boundary">
        <h1>Etwas ist schiefgelaufen · Something went wrong</h1>
        <p lang="de">
          Die Anzeige konnte nicht fortgesetzt werden. Hier lässt sich nicht feststellen,
          ob die letzte Eingabe gespeichert wurde. Bitte nach dem Neuladen den Turnierstand prüfen.
        </p>
        <p lang="en">
          The display could not continue. This screen cannot determine whether your last
          change was saved. Check the tournament state after reloading.
        </p>
        <p>Fehlerreferenz · Error reference: <code>{ERROR_REFERENCE}</code></p>
        <p lang="de">Ungespeicherte Eingaben können beim Neuladen oder Verlassen dieser Seite verloren gehen.</p>
        <p lang="en">Unsaved input may be lost when you reload or leave this page.</p>
        <button type="button" onClick={this.handleReload} className="app-error-boundary__reload">
          Neu laden · Reload
        </button>
        <p><a href="/backup-reader/index.html">Lokale Sicherung ansehen · Inspect local backup</a></p>
      </div>
    );
  }
}
