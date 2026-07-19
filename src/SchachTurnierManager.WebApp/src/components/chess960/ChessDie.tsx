// Visual wooden D6 used by the Chess960 dice flows. Purely decorative: the
// authoritative, valid starting position is produced by the backend service.
// Extracted from main.tsx (STM-FE-014).
import React from 'react';
import { diceFaceGlyphs, diceRestTransforms } from '../../lib/chess960';

export function ChessDie({ rolling, spin, face, quick, compact }: { rolling: boolean; spin: number; face: number; quick?: boolean; compact?: boolean }): React.ReactElement {
  // Sichtbarer Holz-D6: tumbelt/fliegt beim Würfeln und legt sich danach auf die Ergebnisfigur.
  // Rein visuell – die tatsächliche, gültige Chess960-Stellung erzeugt der Backend-Service.
  const restStyle = rolling ? undefined : { transform: diceRestTransforms[face] ?? diceRestTransforms[0] };
  const rollClass = rolling ? (quick ? ' rolling-quick' : ' rolling') : '';
  return (
    <div className={`dice-stage${compact ? ' compact' : ''}`}>
      <div className={`dice-cube${rollClass}`} key={spin} style={restStyle}>
        {diceFaceGlyphs.map((glyph, index) => (
          <div key={index} className={`dice-face dice-face-${index}`}>{glyph}</div>
        ))}
      </div>
    </div>
  );
}
