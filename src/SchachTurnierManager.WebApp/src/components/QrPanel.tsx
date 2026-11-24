// Inline QR code for the LAN dice URL. Rendered locally, no external service.
// Extracted from main.tsx (STM-FE-014).
import React from 'react';
import { encodeText, Ecl } from '../qrcodegen';
import { useI18n } from '../i18n';
export function QrPanel({ url }: { url: string }): React.ReactElement {
  const { t } = useI18n();
  const rendered = React.useMemo(() => {
    try {
      const qr = encodeText(url, Ecl.Medium);
      const border = 4;
      const dimension = qr.size + border * 2;
      let path = '';
      for (let y = 0; y < qr.size; y++) {
        for (let x = 0; x < qr.size; x++) {
          if (qr.getModule(x, y)) {
            path += `M${x + border} ${y + border}h1v1h-1z`;
          }
        }
      }
      return { ok: true as const, dimension, path };
    } catch {
      return { ok: false as const, dimension: 0, path: '' };
    }
  }, [url]);

  if (!rendered.ok) {
    return <p className="board-dice-error">{t('dice.qrError')}</p>;
  }

  return (
    <svg
      className="qr-svg"
      viewBox={`0 0 ${rendered.dimension} ${rendered.dimension}`}
      role="img"
      aria-label={t('dice.qrLabel')}
      shapeRendering="crispEdges"
    >
      <rect width={rendered.dimension} height={rendered.dimension} fill="#ffffff" />
      <path d={rendered.path} fill="#0f172a" />
    </svg>
  );
}

// Eigenständige, schlanke Würfelseite für das Handy (Aufruf per QR / LAN-URL ?dice=...&round=...&board=...).
// Lädt nur das eine Turnier, zeigt nur dieses Brett und nutzt denselben Backend-Endpunkt.
