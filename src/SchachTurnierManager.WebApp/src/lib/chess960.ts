// Chess960 helpers plus the LAN/QR dice-page URL parsing.
// Mirrors the domain service Chess960PositionService.FromPositionNumber so the
// left-to-right animation shows exactly the position the backend re-derives.
// Extracted from main.tsx (STM-FE-014).
export const diceFaceGlyphs = ['♔', '♕', '♖', '♗', '♘', '♙'];
export const diceFaceNames = ['König', 'Dame', 'Turm', 'Läufer', 'Springer', 'Bauer'];
export const diceRestTransforms = [
  'rotateX(-18deg) rotateY(24deg)',
  'rotateY(-90deg)',
  'rotateY(180deg)',
  'rotateY(90deg)',
  'rotateX(-90deg)',
  'rotateX(90deg)'
];


// Spiegelt exakt die Domain-Logik Chess960PositionService.FromPositionNumber wider, damit die
// links-nach-rechts-Animation dieselbe Stellung zeigt, die das Backend aus derselben
// Positionsnummer (0..959) erneut ableitet und speichert.
const chess960LightSquares = [1, 3, 5, 7];
const chess960DarkSquares = [0, 2, 4, 6];
const chess960KnightCombinations: Array<[number, number]> = (() => {
  const combinations: Array<[number, number]> = [];
  for (let first = 0; first < 5; first++) {
    for (let second = first + 1; second < 5; second++) {
      combinations.push([first, second]);
    }
  }
  return combinations;
})();

export function chess960BackRankFromNumber(positionNumber: number): string {
  let remaining = positionNumber;
  const backRank: string[] = new Array(8).fill('');
  const emptySquares = (): number[] =>
    backRank.map((piece, index) => (piece === '' ? index : -1)).filter(index => index >= 0);

  const lightBishopIndex = remaining % 4;
  remaining = Math.floor(remaining / 4);
  backRank[chess960LightSquares[lightBishopIndex]] = 'B';

  const darkBishopIndex = remaining % 4;
  remaining = Math.floor(remaining / 4);
  backRank[chess960DarkSquares[darkBishopIndex]] = 'B';

  let squares = emptySquares();
  const queenIndex = remaining % 6;
  remaining = Math.floor(remaining / 6);
  backRank[squares[queenIndex]] = 'Q';

  squares = emptySquares();
  const knight = chess960KnightCombinations[remaining % 10];
  backRank[squares[knight[0]]] = 'N';
  backRank[squares[knight[1]]] = 'N';

  squares = emptySquares();
  backRank[squares[0]] = 'R';
  backRank[squares[1]] = 'K';
  backRank[squares[2]] = 'R';

  return backRank.join('');
}

export const chess960PieceToFace: Record<string, number> = { K: 0, Q: 1, R: 2, B: 3, N: 4 };

export function chess960PieceFace(piece: string): number {
  return chess960PieceToFace[piece] ?? 0;
}

export type BoardDiceParams = { tournamentId: string; roundNumber: number; boardNumber: number };

export function parseBoardDiceParams(search: string): BoardDiceParams | null {
  const params = new URLSearchParams(search);
  const tournamentId = params.get('dice');
  const roundNumber = Number(params.get('round'));
  const boardNumber = Number(params.get('board'));
  if (!tournamentId || !Number.isInteger(roundNumber) || !Number.isInteger(boardNumber) || roundNumber < 1 || boardNumber < 1) {
    return null;
  }
  return { tournamentId, roundNumber, boardNumber };
}

export function defaultLanHost(): string {
  const host = window.location.hostname;
  return host === 'localhost' || host === '127.0.0.1' || host === '::1' ? '' : host;
}

