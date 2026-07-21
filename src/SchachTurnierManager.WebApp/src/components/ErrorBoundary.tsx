import React from 'react';

// Top-level error boundary (STM-FE-013). A thrown render error previously blanked
// the whole SPA — fatal during a live demo. This catches it and offers a reload,
// with bilingual copy so it works even if the i18n context is what failed.

type ErrorBoundaryProps = { children: React.ReactNode };
type ErrorBoundaryState = { hasError: boolean; message: string };

export class ErrorBoundary extends React.Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false, message: '' };
  }

  static getDerivedStateFromError(error: unknown): ErrorBoundaryState {
    const message = error instanceof Error ? error.message : String(error);
    return { hasError: true, message };
  }

  componentDidCatch(error: unknown): void {
    // Surface for local debugging; no external logging (privacy / offline-first).
    console.error('[SchachTurnierManager] Unerwarteter Fehler / unexpected error:', error);
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
        <p>
          Die Anwendung ist auf einen unerwarteten Fehler gestoßen. Ihre gespeicherten
          Turnierdaten sind davon nicht betroffen.
        </p>
        <p>
          The app hit an unexpected error. Your saved tournament data is not affected.
        </p>
        {this.state.message ? (
          <pre className="app-error-boundary__detail">{this.state.message}</pre>
        ) : null}
        <button type="button" onClick={this.handleReload} className="app-error-boundary__reload">
          Neu laden · Reload
        </button>
      </div>
    );
  }
}
