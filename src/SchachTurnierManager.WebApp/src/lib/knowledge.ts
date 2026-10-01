// Local, offline knowledge base lookup for the in-app assistant.
// Extracted from main.tsx (STM-FE-014); no network access by design.
import rawLocalKnowledgeBase from '../knowledge/localKnowledgeBase.json';
import type {
  KnowledgeBase,
  KnowledgeChatMessage,
  KnowledgeTopic,
  Tournament,
  TournamentAssistantRecommendation,
} from '../api/contracts';
export const localKnowledgeBase = rawLocalKnowledgeBase as KnowledgeBase;
export const knowledgeQuickQuestions = localKnowledgeBase.quickQuestions;
export const knowledgeTopics = localKnowledgeBase.topics;


function normalizeKnowledgeText(value: string): string {
  return value.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

function topicScore(question: string, topic: KnowledgeTopic): number {
  const normalizedQuestion = normalizeKnowledgeText(question);
  return topic.keywords.reduce((score, keyword) => normalizedQuestion.includes(normalizeKnowledgeText(keyword)) ? score + 2 : score, 0)
    + normalizeKnowledgeText(topic.title).split(/\s+/).filter(part => part.length > 3 && normalizedQuestion.includes(part)).length;
}

export function buildKnowledgeContext(tournament: Tournament | undefined, recommendation: TournamentAssistantRecommendation): string[] {
  const context: string[] = [];
  if (tournament) {
    const roundCount = tournament.rounds.length;
    const activePlayers = tournament.players.filter(player => player.status === 0).length;
    context.push(`Aktueller Kontext: „${tournament.name}“ mit ${activePlayers}/${tournament.players.length} aktiven Teilnehmern und ${roundCount} Runde(n).`);
    if (roundCount === 0) {
      context.push('Noch keine Runde ausgelost: zuerst Teilnehmer/Einstellungen prüfen und ein Startbackup erstellen.');
    }
    else {
      const latestRound = tournament.rounds.reduce((max, round) => Math.max(max, round.roundNumber), 0);
      context.push(`Letzte bekannte Runde: ${latestRound}. Nach Ergebniserfassung Backup und Tabelle prüfen.`);
    }
  }
  else {
    context.push('Kein Turnier ausgewählt: Empfehlung bezieht sich auf die aktuelle Assistenten-Eingabe.');
  }

  context.push(`Assistenten-Vorschlag: ${recommendation.formatLabel}, ${recommendation.plannedRounds} Runde(n), ca. ${recommendation.estimatedTotalMinutes} Minuten.`);
  if (recommendation.warnings.length > 0) {
    context.push(`Prüfhinweis: ${recommendation.warnings[0]}`);
  }

  return context;
}

export function buildLocalKnowledgeAnswer(question: string, tournament: Tournament | undefined, recommendation: TournamentAssistantRecommendation): KnowledgeChatMessage {
  const scored = knowledgeTopics
    .map(topic => ({ topic, score: topicScore(question, topic) }))
    .sort((left, right) => right.score - left.score);
  const best = scored[0]?.score > 0 ? scored[0].topic : knowledgeTopics[0];
  if (!best) {
    return {
      id: `assistant-${Date.now()}-${Math.random().toString(36).slice(2)}`,
      role: 'assistant',
      text: `Die lokale Wissensbasis ist leer. Bitte src/knowledge/localKnowledgeBase.json pruefen.\n\nHinweis: ${localKnowledgeBase.privacyNotice}`,
      sources: ['src/knowledge/localKnowledgeBase.json']
    };
  }
  const context = buildKnowledgeContext(tournament, recommendation);
  const text = [
    `**${best.title}**`,
    best.answer,
    '',
    ...context.map(item => `• ${item}`),
    '',
    'Nächste Schritte:',
    ...best.steps.map((step, index) => `${index + 1}. ${step}`),
    '',
    `Hinweis: ${localKnowledgeBase.privacyNotice}`
  ].join('\n');

  return {
    id: `assistant-${Date.now()}-${Math.random().toString(36).slice(2)}`,
    role: 'assistant',
    text,
    sources: best.sources
  };
}

