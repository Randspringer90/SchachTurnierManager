// Local, offline knowledge lookup. Catalogue content is data, never tool instructions.
import rawLocalKnowledgeBase from '../knowledge/localKnowledgeBase.json';
import rawEnglishKnowledgeBase from '../knowledge/localKnowledgeBase.en.json';
import type { KnowledgeBase, KnowledgeChatMessage, KnowledgeTopic, Tournament, TournamentAssistantRecommendation } from '../api/contracts';

// Keep the original exports for callers that do not select a language.
export const localKnowledgeBase = rawLocalKnowledgeBase as KnowledgeBase;
const englishKnowledgeBase = rawEnglishKnowledgeBase as KnowledgeBase;
export const knowledgeQuickQuestions = localKnowledgeBase.quickQuestions;
export const knowledgeTopics = localKnowledgeBase.topics;
export function getLocalKnowledgeBase(language = 'de'): KnowledgeBase {
  return language === 'de' ? localKnowledgeBase : englishKnowledgeBase;
}

function normalizeKnowledgeText(value: string): string {
  return value.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}
function topicScore(question: string, topic: KnowledgeTopic): number {
  const normalizedQuestion = normalizeKnowledgeText(question);
  // A language change must not make an already typed German/English question
  // select an unrelated topic. Aliases are local static data in both catalogues.
  const aliases = new Set([
    ...topic.keywords,
    ...(localKnowledgeBase.topics.find(item => item.id === topic.id)?.keywords ?? []),
    ...(englishKnowledgeBase.topics.find(item => item.id === topic.id)?.keywords ?? []),
  ]);
  return [...aliases].reduce((score, keyword) => normalizedQuestion.includes(normalizeKnowledgeText(keyword)) ? score + 2 : score, 0)
    + normalizeKnowledgeText(topic.title).split(/\s+/).filter(part => part.length > 3 && normalizedQuestion.includes(part)).length;
}

export function buildKnowledgeContext(tournament: Tournament | undefined, recommendation: TournamentAssistantRecommendation, language = 'de'): string[] {
  const english = language !== 'de';
  const context: string[] = [];
  if (tournament) {
    const roundCount = tournament.rounds.length;
    const activePlayers = tournament.players.filter(player => player.status === 0).length;
    context.push(english
      ? `Current context: “${tournament.name}” with ${activePlayers}/${tournament.players.length} active participants and ${roundCount} round(s).`
      : `Aktueller Kontext: „${tournament.name}“ mit ${activePlayers}/${tournament.players.length} aktiven Teilnehmern und ${roundCount} Runde(n).`);
    if (roundCount === 0) {
      context.push(english ? 'No round paired yet: check participants and settings, then export a starting backup.'
        : 'Noch keine Runde ausgelost: zuerst Teilnehmer/Einstellungen prüfen und ein Startbackup erstellen.');
    } else {
      const latestRound = tournament.rounds.reduce((max, round) => Math.max(max, round.roundNumber), 0);
      context.push(english ? `Latest known round: ${latestRound}. After entering results, check the backup and standings.`
        : `Letzte bekannte Runde: ${latestRound}. Nach Ergebniserfassung Backup und Tabelle prüfen.`);
    }
  } else {
    context.push(english ? 'No tournament selected: this recommendation uses the current assistant inputs.'
      : 'Kein Turnier ausgewählt: Empfehlung bezieht sich auf die aktuelle Assistenten-Eingabe.');
  }
  context.push(english ? `Assistant recommendation: ${recommendation.formatLabel}, ${recommendation.plannedRounds} round(s), approximately ${recommendation.estimatedTotalMinutes} minutes.`
    : `Assistenten-Vorschlag: ${recommendation.formatLabel}, ${recommendation.plannedRounds} Runde(n), ca. ${recommendation.estimatedTotalMinutes} Minuten.`);
  if (recommendation.warnings.length > 0) {
    context.push(english ? `Review notice: ${recommendation.warnings[0]}` : `Prüfhinweis: ${recommendation.warnings[0]}`);
  }
  return context;
}

export function buildLocalKnowledgeAnswer(question: string, tournament: Tournament | undefined, recommendation: TournamentAssistantRecommendation, language = 'de'): KnowledgeChatMessage {
  const base = getLocalKnowledgeBase(language);
  const english = language !== 'de';
  const scored = base.topics.map(topic => ({ topic, score: topicScore(question, topic) }))
    .sort((left, right) => right.score - left.score);
  const best = scored[0]?.score > 0 ? scored[0].topic : base.topics[0];
  if (!best) {
    return {
      id: `assistant-${Date.now()}-${Math.random().toString(36).slice(2)}`, role: 'assistant',
      text: english ? `The local knowledge base is empty. Check the installed knowledge files.\n\nNotice: ${base.privacyNotice}`
        : `Die lokale Wissensbasis ist leer. Bitte die installierten Wissensdateien prüfen.\n\nHinweis: ${base.privacyNotice}`,
      sources: ['src/knowledge/localKnowledgeBase.json'],
    };
  }
  const context = buildKnowledgeContext(tournament, recommendation, language);
  const text = [
    `**${best.title}**`, best.answer, '', ...context.map(item => `• ${item}`), '',
    english ? 'Next steps:' : 'Nächste Schritte:',
    ...best.steps.map((step, index) => `${index + 1}. ${step}`), '',
    `${english ? 'Notice' : 'Hinweis'}: ${base.privacyNotice}`,
  ].join('\n');
  return { id: `assistant-${Date.now()}-${Math.random().toString(36).slice(2)}`, role: 'assistant', text, sources: best.sources };
}
