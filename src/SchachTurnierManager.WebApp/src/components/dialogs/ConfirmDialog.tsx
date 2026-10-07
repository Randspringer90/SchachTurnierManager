import * as React from 'react';
import { canConfirmDeletion } from '../../lib/destructiveActions';

/**
 * Accessible in-app confirmation dialog.
 *
 * Replaces `window.confirm` / `window.prompt` for destructive tournament actions.
 * Native browser dialogs were unreliable in Firefox: the second modal prompt of a
 * chain could be suppressed by the "prevent additional dialogs" checkbox, which
 * silently aborted the delete flow and left the app in an inconsistent state.
 */
export type ConfirmDialogProps = {
  open: boolean;
  title: string;
  /** Short lead paragraph. */
  description: string;
  /** Bullet points describing the exact consequences. */
  consequences?: string[];
  confirmLabel: string;
  cancelLabel: string;
  /** Marks the dialog and the confirm button as destructive. */
  destructive?: boolean;
  /**
   * When set, the user has to type this text verbatim before the confirm
   * button is enabled. Used for tournament deletion.
   */
  requireTypedConfirmation?: string;
  /** Label for the typed-confirmation input. */
  typedConfirmationLabel?: string;
  /** True while the confirmed action is running. Blocks double submits. */
  busy?: boolean;
  busyLabel?: string;
  /** Backend error, shown inside the dialog without closing it. */
  errorMessage?: string | null;
  onConfirm: () => void;
  onCancel: () => void;
};

const FOCUSABLE_SELECTOR = [
  'a[href]',
  'button:not([disabled])',
  'input:not([disabled])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  '[tabindex]:not([tabindex="-1"])'
].join(', ');

export function ConfirmDialog(props: ConfirmDialogProps): React.ReactElement | null {
  const {
    open,
    title,
    description,
    consequences,
    confirmLabel,
    cancelLabel,
    destructive = false,
    requireTypedConfirmation,
    typedConfirmationLabel,
    busy = false,
    busyLabel,
    errorMessage,
    onConfirm,
    onCancel
  } = props;

  const dialogRef = React.useRef<HTMLDivElement | null>(null);
  const initialFocusRef = React.useRef<HTMLElement | null>(null);
  const previouslyFocusedRef = React.useRef<HTMLElement | null>(null);
  const [typedValue, setTypedValue] = React.useState('');

  const titleId = React.useId();
  const descriptionId = React.useId();
  const typedInputId = React.useId();
  const errorId = React.useId();

  // Reset the typed confirmation whenever the dialog is (re-)opened so a previous
  // attempt can never pre-authorise the next one.
  React.useEffect(() => {
    if (open) {
      setTypedValue('');
    }
  }, [open, requireTypedConfirmation]);

  // Remember the trigger element and restore focus to it when the dialog closes.
  React.useEffect(() => {
    if (!open) {
      return undefined;
    }

    previouslyFocusedRef.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    initialFocusRef.current?.focus();

    return () => {
      previouslyFocusedRef.current?.focus();
    };
  }, [open]);

  const confirmDisabled =
    busy || (requireTypedConfirmation !== undefined && !canConfirmDeletion(typedValue, requireTypedConfirmation));

  function handleKeyDown(event: React.KeyboardEvent<HTMLDivElement>): void {
    if (event.key === 'Escape') {
      event.stopPropagation();
      // Escape must never confirm a destructive action, but it also must not
      // abandon a request that is already in flight.
      if (!busy) {
        onCancel();
      }
      return;
    }

    if (event.key !== 'Tab') {
      return;
    }

    const container = dialogRef.current;
    if (!container) {
      return;
    }

    const focusable = Array.from(container.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR)).filter(
      element => element.offsetParent !== null || element === document.activeElement
    );
    if (focusable.length === 0) {
      return;
    }

    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }

  if (!open) {
    return null;
  }

  return (
    <div
      className="modal-backdrop"
      onMouseDown={event => {
        // Clicking the backdrop cancels, but only when it is not a stray click
        // that started inside the dialog.
        if (event.target === event.currentTarget && !busy) {
          onCancel();
        }
      }}
    >
      <div
        ref={dialogRef}
        role="alertdialog"
        aria-modal="true"
        aria-labelledby={titleId}
        aria-describedby={descriptionId}
        className={`card confirm-dialog${destructive ? ' confirm-dialog-destructive' : ''}`}
        onKeyDown={handleKeyDown}
      >
        <h3 id={titleId}>{title}</h3>
        <p id={descriptionId}>{description}</p>
        {consequences && consequences.length > 0 && (
          <ul className="confirm-dialog-consequences">
            {consequences.map((entry, index) => (
              <li key={`confirm-consequence-${index}`}>{entry}</li>
            ))}
          </ul>
        )}

        {requireTypedConfirmation !== undefined && (
          <div className="confirm-dialog-typed">
            <label htmlFor={typedInputId}>{typedConfirmationLabel}</label>
            <p className="confirm-dialog-typed-target">
              <code>{requireTypedConfirmation}</code>
            </p>
            <input
              id={typedInputId}
              type="text"
              value={typedValue}
              autoComplete="off"
              spellCheck={false}
              disabled={busy}
              onChange={event => setTypedValue(event.target.value)}
              ref={element => {
                initialFocusRef.current = element;
              }}
            />
          </div>
        )}

        {errorMessage && (
          <p className="confirm-dialog-error" id={errorId} role="alert">
            {errorMessage}
          </p>
        )}

        <div className="actions confirm-dialog-actions">
          <button
            type="button"
            className="secondary"
            disabled={busy}
            onClick={onCancel}
            ref={element => {
              if (requireTypedConfirmation === undefined) {
                initialFocusRef.current = element;
              }
            }}
          >
            {cancelLabel}
          </button>
          <button
            type="button"
            className={destructive ? 'danger' : ''}
            disabled={confirmDisabled}
            aria-describedby={errorMessage ? errorId : undefined}
            onClick={onConfirm}
          >
            {busy && busyLabel ? busyLabel : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
