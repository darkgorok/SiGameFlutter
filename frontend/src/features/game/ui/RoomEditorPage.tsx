import { useEffect, useMemo, useState } from 'react';
import { useParams } from 'react-router-dom';

import { useI18n } from '../../../shared/i18n/i18nContext';
import { gameRepository } from '../data/gameRepository';
import type { QuestionDraft, QuestionMediaType, QuestionModel, QuestionType } from '../domain/models';

const questionTypes: QuestionType[] = ['normal', 'cat_in_bag', 'wager', 'closest_number'];
const mediaTypes: QuestionMediaType[] = ['none', 'image', 'audio', 'video'];

const defaultDraft: QuestionDraft = {
  theme: '',
  text: '',
  answer: '',
  cost: 100,
  round: 1,
  type: 'normal',
  mediaUrl: '',
  mediaType: 'none',
  aliases: [],
};

type ImportPayload = {
  questions: QuestionDraft[];
};

function buildExportPayload(questions: QuestionModel[]): ImportPayload {
  return {
    questions: questions.map((q) => ({
      theme: q.theme,
      text: q.text,
      answer: q.answer,
      cost: q.cost,
      round: q.round,
      type: q.type,
      mediaUrl: q.mediaUrl,
      mediaType: q.mediaType,
      aliases: q.aliases,
    })),
  };
}

export function RoomEditorPage() {
  const { t } = useI18n();
  const params = useParams<{ roomId: string }>();
  const roomId = params.roomId ?? '';

  const [questions, setQuestions] = useState<QuestionModel[]>([]);
  const [draft, setDraft] = useState<QuestionDraft>(defaultDraft);
  const [editingQuestionId, setEditingQuestionId] = useState<string | null>(null);
  const [importJson, setImportJson] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!roomId) {
      return;
    }
    return gameRepository.watchQuestions(roomId, setQuestions);
  }, [roomId]);

  const roundOptions = useMemo(() => {
    const rounds = new Set<number>([1, draft.round]);
    for (const question of questions) {
      if (question.round > 0) {
        rounds.add(question.round);
      }
    }
    const sorted = [...rounds].sort((a, b) => a - b);
    const next = sorted[sorted.length - 1] + 1;
    if (!sorted.includes(next)) {
      sorted.push(next);
    }
    return sorted;
  }, [draft.round, questions]);

  const exportJson = useMemo(
    () => JSON.stringify(buildExportPayload(questions), null, 2),
    [questions],
  );

  if (!roomId) {
    return <section className="panel">{t('room.invalid')}</section>;
  }

  function resetDraft(): void {
    setDraft(defaultDraft);
    setEditingQuestionId(null);
  }

  async function run(action: () => Promise<unknown>): Promise<void> {
    setBusy(true);
    setError(null);
    try {
      await action();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Action failed');
    } finally {
      setBusy(false);
    }
  }

  async function onSaveQuestion(): Promise<void> {
    const normalizedDraft: QuestionDraft = {
      ...draft,
      theme: draft.theme.trim(),
      text: draft.text.trim(),
      answer: draft.answer.trim(),
      mediaUrl: draft.mediaUrl.trim(),
      aliases: draft.aliases.filter((item) => item.trim().length > 0),
    };

    if (!normalizedDraft.theme || !normalizedDraft.text || !normalizedDraft.answer) {
      setError('Theme, question text and answer are required.');
      return;
    }

    await run(async () => {
      if (editingQuestionId) {
        await gameRepository.updateQuestion(roomId, editingQuestionId, normalizedDraft);
      } else {
        await gameRepository.addQuestion(roomId, normalizedDraft);
      }
      resetDraft();
    });
  }

  async function onImport(): Promise<void> {
    if (!importJson.trim()) {
      setError('Paste JSON before import.');
      return;
    }

    await run(async () => {
      const raw = JSON.parse(importJson) as Partial<ImportPayload>;
      const parsed = Array.isArray(raw.questions) ? raw.questions : [];
      if (parsed.length === 0) {
        throw new Error('No questions in JSON payload');
      }
      const normalized = parsed.map((q) => ({
        theme: String(q.theme ?? '').trim(),
        text: String(q.text ?? '').trim(),
        answer: String(q.answer ?? '').trim(),
        cost: Number(q.cost) || 100,
        round: Number(q.round) || 1,
        type: (q.type as QuestionType) ?? 'normal',
        mediaUrl: String(q.mediaUrl ?? '').trim(),
        mediaType: (q.mediaType as QuestionMediaType) ?? 'none',
        aliases: Array.isArray(q.aliases)
          ? q.aliases.filter((item): item is string => typeof item === 'string').map((item) => item.trim())
          : [],
      }));
      await gameRepository.addQuestionsBulk(roomId, normalized);
      setImportJson('');
    });
  }

  function loadQuestion(question: QuestionModel): void {
    setEditingQuestionId(question.id);
    setDraft({
      theme: question.theme,
      text: question.text,
      answer: question.answer,
      cost: question.cost,
      round: question.round,
      type: question.type,
      mediaUrl: question.mediaUrl,
      mediaType: question.mediaType,
      aliases: question.aliases,
    });
  }

  return (
    <section className="stack-16">
      <article className="panel stack-8 glass-hero">
        <h2>
          {t('editor.title')}: {roomId}
        </h2>
        <input
          placeholder={t('editor.theme')}
          value={draft.theme}
          onChange={(event) => setDraft((prev) => ({ ...prev, theme: event.target.value }))}
        />
        <textarea
          placeholder={t('editor.question_text')}
          value={draft.text}
          onChange={(event) => setDraft((prev) => ({ ...prev, text: event.target.value }))}
        />
        <input
          placeholder={t('editor.answer')}
          value={draft.answer}
          onChange={(event) => setDraft((prev) => ({ ...prev, answer: event.target.value }))}
        />
        <input
          placeholder={t('editor.aliases')}
          value={draft.aliases.join(', ')}
          onChange={(event) =>
            setDraft((prev) => ({
              ...prev,
              aliases: event.target.value.split(',').map((item) => item.trim()),
            }))
          }
        />
        <input
          placeholder={t('editor.media_url')}
          value={draft.mediaUrl}
          onChange={(event) => setDraft((prev) => ({ ...prev, mediaUrl: event.target.value }))}
        />
        <div className="row gap-8 control-row">
          <input
            className="narrow-input"
            type="number"
            min={100}
            step={100}
            value={draft.cost}
            onChange={(event) =>
              setDraft((prev) => ({
                ...prev,
                cost: Number.parseInt(event.target.value, 10) || 100,
              }))
            }
          />
          <select
            value={draft.round}
            onChange={(event) =>
              setDraft((prev) => ({ ...prev, round: Number.parseInt(event.target.value, 10) || 1 }))
            }
          >
            {roundOptions.map((round) => (
              <option key={round} value={round}>
                {t('editor.round')} {round}
              </option>
            ))}
          </select>
          <select
            value={draft.type}
            onChange={(event) => setDraft((prev) => ({ ...prev, type: event.target.value as QuestionType }))}
          >
            {questionTypes.map((item) => (
              <option key={item} value={item}>
                {item}
              </option>
            ))}
          </select>
          <select
            value={draft.mediaType}
            onChange={(event) =>
              setDraft((prev) => ({ ...prev, mediaType: event.target.value as QuestionMediaType }))
            }
          >
            {mediaTypes.map((item) => (
              <option key={item} value={item}>
                {item}
              </option>
            ))}
          </select>
        </div>
        <div className="row gap-8 control-row">
          <button className="primary-action" disabled={busy} onClick={() => void onSaveQuestion()}>
            {editingQuestionId ? t('editor.update') : t('editor.add')}
          </button>
          {editingQuestionId ? (
            <button className="ghost-button" disabled={busy} onClick={resetDraft}>
              {t('editor.cancel_edit')}
            </button>
          ) : null}
        </div>
        {error ? <p className="error">{error}</p> : null}
      </article>

      <article className="panel stack-8">
        <h3>{t('editor.import_export')}</h3>
        <textarea readOnly value={exportJson} />
        <textarea
          placeholder={t('editor.import_placeholder')}
          value={importJson}
          onChange={(event) => setImportJson(event.target.value)}
        />
        <div className="row gap-8">
          <button className="primary-action" disabled={busy || !importJson.trim()} onClick={() => void onImport()}>
            {t('editor.import_bulk')}
          </button>
        </div>
      </article>

      <article className="panel stack-8">
        <h3>{t('editor.question_list')}</h3>
        {questions.length === 0 ? <p>{t('editor.none_questions')}</p> : null}
        {questions.map((question) => (
          <div key={question.id} className="room-card">
            <div>
              <strong>
                r{question.round} {question.theme} ({question.cost})
              </strong>
              <p className="room-meta">
                <span className="status-chip">{question.type}</span>
                <span className="phase-chip">{question.mediaType}</span>
              </p>
              <p>{question.text}</p>
            </div>
            <div className="row gap-8">
              <button disabled={busy || question.used} onClick={() => loadQuestion(question)}>
                {t('editor.edit')}
              </button>
              <button
                className="danger-button"
                disabled={busy || question.used}
                onClick={() => void run(() => gameRepository.deleteQuestion(roomId, question.id))}
              >
                {t('editor.delete')}
              </button>
            </div>
          </div>
        ))}
      </article>
    </section>
  );
}
