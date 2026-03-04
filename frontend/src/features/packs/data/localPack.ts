import type { QuestionDraft, QuestionMediaType, QuestionType } from '../../game/domain/models';

export type LocalPackQuestion = QuestionDraft;

export type LocalPackDocument = {
  name: string;
  questions: LocalPackQuestion[];
};

type RawQuestion = {
  theme?: unknown;
  text?: unknown;
  answer?: unknown;
  cost?: unknown;
  round?: unknown;
  type?: unknown;
  mediaUrl?: unknown;
  mediaType?: unknown;
  aliases?: unknown;
};

const allowedQuestionTypes: QuestionType[] = ['normal', 'cat_in_bag', 'wager', 'closest_number'];
const allowedMediaTypes: QuestionMediaType[] = ['none', 'image', 'audio', 'video'];

function normalizeQuestionType(value: unknown): QuestionType {
  const raw = typeof value === 'string' ? value.trim().toLowerCase() : '';
  if (raw === 'bagcat') {
    return 'cat_in_bag';
  }
  if (allowedQuestionTypes.includes(raw as QuestionType)) {
    return raw as QuestionType;
  }
  return 'normal';
}

function normalizeMediaType(value: unknown): QuestionMediaType {
  const raw = typeof value === 'string' ? value.trim().toLowerCase() : '';
  if (allowedMediaTypes.includes(raw as QuestionMediaType)) {
    return raw as QuestionMediaType;
  }
  return 'none';
}

function normalizeAliases(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const unique = new Set<string>();
  for (const item of value) {
    if (typeof item !== 'string') {
      continue;
    }
    const normalized = item.trim();
    if (!normalized) {
      continue;
    }
    unique.add(normalized);
  }
  return [...unique];
}

function normalizeQuestion(raw: RawQuestion): LocalPackQuestion {
  return {
    theme: String(raw.theme ?? '').trim(),
    text: String(raw.text ?? '').trim(),
    answer: String(raw.answer ?? '').trim(),
    cost: Number(raw.cost) > 0 ? Math.round(Number(raw.cost)) : 100,
    round: Number(raw.round) > 0 ? Math.round(Number(raw.round)) : 1,
    type: normalizeQuestionType(raw.type),
    mediaUrl: String(raw.mediaUrl ?? '').trim(),
    mediaType: normalizeMediaType(raw.mediaType),
    aliases: normalizeAliases(raw.aliases),
  };
}

export function parseLocalPack(raw: unknown): LocalPackDocument {
  if (Array.isArray(raw)) {
    const questions = raw
      .filter((item): item is RawQuestion => Boolean(item) && typeof item === 'object')
      .map(normalizeQuestion);
    return { name: 'Pack', questions };
  }

  if (!raw || typeof raw !== 'object') {
    throw new Error('Invalid pack JSON');
  }

  const map = raw as { name?: unknown; questions?: unknown };
  const name = typeof map.name === 'string' && map.name.trim() ? map.name.trim() : 'Pack';
  const questionsRaw = Array.isArray(map.questions) ? map.questions : [];
  const questions = questionsRaw
    .filter((item): item is RawQuestion => Boolean(item) && typeof item === 'object')
    .map(normalizeQuestion);

  return {
    name,
    questions,
  };
}

export function parseLocalPackJson(jsonText: string): LocalPackDocument {
  return parseLocalPack(JSON.parse(jsonText));
}
