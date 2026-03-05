import { useMemo, useRef, useState, type ChangeEvent } from 'react';
import { useI18n } from '../../../shared/i18n/i18nContext';

import { parseLocalPackJson } from '../data/localPack';
import type { QuestionMediaType, QuestionType } from '../../game/domain/models';

type StageKind = 'round' | 'final';

type BoardTheme = {
  id: string;
  title: string;
};

type BoardQuestion = {
  id: string;
  themeId: string;
  text: string;
  answer: string;
  cost: number;
  type: QuestionType;
  mediaUrl: string;
  mediaType: QuestionMediaType;
  aliases: string[];
};

type BoardRound = {
  id: string;
  title: string;
  themes: BoardTheme[];
  questions: BoardQuestion[];
};

type EditingTarget = {
  stage: StageKind;
  boardId: string;
  questionId: string;
} | null;

type BlitzFileV1 = {
  format: 'blitz-pack';
  version: 1;
  name: string;
  rounds: BoardRound[];
  finalRound: BoardRound;
};

const questionTypes: QuestionType[] = ['normal', 'cat_in_bag', 'wager', 'closest_number'];
const mediaTypes: QuestionMediaType[] = ['none', 'image', 'audio', 'video'];

function makeId(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }
  return `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

function createEmptyRound(index: number): BoardRound {
  return {
    id: makeId(),
    title: `Раунд ${index}`,
    themes: [],
    questions: [],
  };
}

function normalizeRoundTitles(input: BoardRound[]): BoardRound[] {
  return input.map((round, index) => ({
    ...round,
    title: `Раунд ${index + 1}`,
  }));
}

function createEmptyQuestion(themeId: string): BoardQuestion {
  return {
    id: makeId(),
    themeId,
    text: '',
    answer: '',
    cost: 0,
    type: 'normal',
    mediaUrl: '',
    mediaType: 'none',
    aliases: [],
  };
}

export function PackEditorPage() {
  const { t } = useI18n();
  const importInputRef = useRef<HTMLInputElement | null>(null);

  const [packName, setPackName] = useState('');
  const [rounds, setRounds] = useState<BoardRound[]>([createEmptyRound(1)]);
  const [finalRound, setFinalRound] = useState<BoardRound>({
    id: 'final',
    title: 'Финал',
    themes: [],
    questions: [],
  });
  const [selectedStage, setSelectedStage] = useState<{ kind: StageKind; roundId: string }>({
    kind: 'round',
    roundId: rounds[0].id,
  });
  const [editing, setEditing] = useState<EditingTarget>(null);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const selectedBoard = useMemo(() => {
    if (selectedStage.kind === 'final') {
      return finalRound;
    }
    return rounds.find((round) => round.id === selectedStage.roundId) ?? rounds[0];
  }, [finalRound, rounds, selectedStage]);

  const editingQuestion = useMemo(() => {
    if (!editing) return null;
    const board =
      editing.stage === 'final'
        ? finalRound
        : rounds.find((round) => round.id === editing.boardId) ?? null;
    if (!board) return null;
    return board.questions.find((question) => question.id === editing.questionId) ?? null;
  }, [editing, finalRound, rounds]);

  const editingThemeTitle = useMemo(() => {
    if (!editingQuestion || !editing) return '';
    const board =
      editing.stage === 'final'
        ? finalRound
        : rounds.find((round) => round.id === editing.boardId) ?? null;
    if (!board) return '';
    return board.themes.find((theme) => theme.id === editingQuestion.themeId)?.title ?? '';
  }, [editing, editingQuestion, finalRound, rounds]);

  function clearFeedback(): void {
    setError(null);
    setMessage(null);
  }

  function updateRound(roundId: string, mutate: (round: BoardRound) => BoardRound): void {
    setRounds((current) => current.map((round) => (round.id === roundId ? mutate(round) : round)));
  }

  function addRound(): void {
    clearFeedback();
    const nextRound = createEmptyRound(rounds.length + 1);
    setRounds((current) => normalizeRoundTitles([...current, nextRound]));
    setSelectedStage({ kind: 'round', roundId: nextRound.id });
  }

  function removeRound(roundId: string): void {
    clearFeedback();
    setRounds((current) => {
      if (current.length <= 1) {
        const reset = createEmptyRound(1);
        setSelectedStage({ kind: 'round', roundId: reset.id });
        return [reset];
      }
      const next = normalizeRoundTitles(current.filter((round) => round.id !== roundId));
      if (selectedStage.kind === 'round' && selectedStage.roundId === roundId) {
        setSelectedStage({ kind: 'round', roundId: next[0].id });
      }
      return next;
    });
  }

  function sanitizeBoardRound(input: BoardRound, fallbackTitle: string): BoardRound {
    const themes = Array.isArray(input.themes)
      ? input.themes.map((item, index) => ({
          id: typeof item?.id === 'string' && item.id.trim() ? item.id : makeId(),
          title: typeof item?.title === 'string' && item.title.trim() ? item.title : `Тема ${index + 1}`,
        }))
      : [];

    const themeIds = new Set(themes.map((item) => item.id));
    const questions = Array.isArray(input.questions)
      ? input.questions
          .filter((item) => item && typeof item === 'object')
          .map((item) => ({
            id: typeof item.id === 'string' && item.id.trim() ? item.id : makeId(),
            themeId:
              typeof item.themeId === 'string' && themeIds.has(item.themeId)
                ? item.themeId
                : themes[0]?.id ?? '',
            text: typeof item.text === 'string' ? item.text : '',
            answer: typeof item.answer === 'string' ? item.answer : '',
            cost: typeof item.cost === 'number' && Number.isFinite(item.cost) ? item.cost : 0,
            type: questionTypes.includes(item.type as QuestionType) ? (item.type as QuestionType) : 'normal',
            mediaUrl: typeof item.mediaUrl === 'string' ? item.mediaUrl : '',
            mediaType: mediaTypes.includes(item.mediaType as QuestionMediaType)
              ? (item.mediaType as QuestionMediaType)
              : 'none',
            aliases: Array.isArray(item.aliases)
              ? item.aliases.filter((alias): alias is string => typeof alias === 'string')
              : [],
          }))
          .filter((question) => question.themeId.length > 0)
      : [];

    return {
      id: typeof input.id === 'string' && input.id.trim() ? input.id : makeId(),
      title: typeof input.title === 'string' && input.title.trim() ? input.title : fallbackTitle,
      themes,
      questions,
    };
  }

  function addThemeToSelectedBoard(): void {
    clearFeedback();
    const board = selectedBoard;
    if (!board) return;
    const nextTheme: BoardTheme = {
      id: makeId(),
      title: `Тема ${board.themes.length + 1}`,
    };

    if (selectedStage.kind === 'final') {
      setFinalRound((current) => ({
        ...current,
        themes: [...current.themes, nextTheme],
      }));
      return;
    }

    updateRound(selectedStage.roundId, (round) => ({
      ...round,
      themes: [...round.themes, nextTheme],
    }));
  }

  function renameTheme(themeId: string): void {
    const board = selectedBoard;
    const theme = board.themes.find((item) => item.id === themeId);
    if (!theme) return;

    const nextTitle = window.prompt('Название темы', theme.title)?.trim();
    if (!nextTitle) return;

    if (selectedStage.kind === 'final') {
      setFinalRound((current) => ({
        ...current,
        themes: current.themes.map((item) => (item.id === themeId ? { ...item, title: nextTitle } : item)),
      }));
      return;
    }

    updateRound(selectedStage.roundId, (round) => ({
      ...round,
      themes: round.themes.map((item) => (item.id === themeId ? { ...item, title: nextTitle } : item)),
    }));
  }

  function removeTheme(themeId: string): void {
    clearFeedback();
    if (selectedStage.kind === 'final') {
      setFinalRound((current) => ({
        ...current,
        themes: current.themes.filter((theme) => theme.id !== themeId),
        questions: current.questions.filter((question) => question.themeId !== themeId),
      }));
      return;
    }

    updateRound(selectedStage.roundId, (round) => ({
      ...round,
      themes: round.themes.filter((theme) => theme.id !== themeId),
      questions: round.questions.filter((question) => question.themeId !== themeId),
    }));
  }

  function addQuestion(themeId: string): void {
    clearFeedback();
    const question = createEmptyQuestion(themeId);

    if (selectedStage.kind === 'final') {
      setFinalRound((current) => ({
        ...current,
        questions: [...current.questions, question],
      }));
      setEditing({
        stage: 'final',
        boardId: 'final',
        questionId: question.id,
      });
      return;
    }

    updateRound(selectedStage.roundId, (round) => ({
      ...round,
      questions: [...round.questions, question],
    }));
    setEditing({
      stage: 'round',
      boardId: selectedStage.roundId,
      questionId: question.id,
    });
  }

  function openQuestion(themeId: string, questionId: string): void {
    setEditing({
      stage: selectedStage.kind,
      boardId: selectedStage.kind === 'final' ? 'final' : selectedStage.roundId,
      questionId,
    });
    if (!selectedBoard.themes.find((theme) => theme.id === themeId)) {
      setError('Theme not found');
    }
  }

  function removeQuestionById(stage: StageKind, boardId: string, questionId: string): void {
    clearFeedback();
    if (stage === 'final') {
      setFinalRound((current) => ({
        ...current,
        questions: current.questions.filter((question) => question.id !== questionId),
      }));
      return;
    }
    updateRound(boardId, (round) => ({
      ...round,
      questions: round.questions.filter((question) => question.id !== questionId),
    }));
  }

  function updateEditingQuestion(patch: Partial<BoardQuestion>): void {
    if (!editingQuestion || !editing) return;
    const updater = (question: BoardQuestion) =>
      question.id === editing.questionId ? { ...question, ...patch } : question;

    if (editing.stage === 'final') {
      setFinalRound((current) => ({
        ...current,
        questions: current.questions.map(updater),
      }));
      return;
    }

    updateRound(editing.boardId, (round) => ({
      ...round,
      questions: round.questions.map(updater),
    }));
  }

  function deleteEditingQuestion(): void {
    if (!editing) return;
    if (editing.stage === 'final') {
      setFinalRound((current) => ({
        ...current,
        questions: current.questions.filter((question) => question.id !== editing.questionId),
      }));
      setEditing(null);
      return;
    }
    updateRound(editing.boardId, (round) => ({
      ...round,
      questions: round.questions.filter((question) => question.id !== editing.questionId),
    }));
    setEditing(null);
  }

  function closeEditor(): void {
    setEditing(null);
  }

  async function importFromFile(file: File): Promise<void> {
    clearFeedback();
    try {
      const text = await file.text();
      const raw = JSON.parse(text) as Partial<BlitzFileV1>;

      if (raw.format === 'blitz-pack' && raw.version === 1) {
      const importedRoundsRaw = Array.isArray(raw.rounds) ? raw.rounds : [];
      const importedRounds = importedRoundsRaw.map((round, index) =>
        sanitizeBoardRound(round, `Раунд ${index + 1}`),
      );
      const nextRounds = normalizeRoundTitles(
        importedRounds.length > 0 ? importedRounds : [createEmptyRound(1)],
      );
        const importedFinal = raw.finalRound
          ? sanitizeBoardRound(raw.finalRound, 'Финал')
          : {
              id: 'final',
              title: 'Финал',
              themes: [],
              questions: [],
            };

        setPackName(typeof raw.name === 'string' ? raw.name : '');
        setRounds(nextRounds);
        setFinalRound({
          ...importedFinal,
          id: 'final',
          title: 'Финал',
        });
        setSelectedStage({ kind: 'round', roundId: nextRounds[0].id });
        setEditing(null);
        setMessage('Пак импортирован');
        return;
      }

      const parsed = parseLocalPackJson(text);
      const maxRound = parsed.questions.reduce((max, question) => Math.max(max, question.round), 1);
      const normalRoundCount = Math.max(1, maxRound - 1);
      const nextRounds = normalizeRoundTitles(
        Array.from({ length: normalRoundCount }, (_, index) => createEmptyRound(index + 1)),
      );
      const nextFinal: BoardRound = {
        id: 'final',
        title: 'Финал',
        themes: [],
        questions: [],
      };

      for (const question of parsed.questions) {
        const isFinal = question.round >= maxRound && maxRound >= 2;
        const target = isFinal ? nextFinal : nextRounds[Math.max(0, question.round - 1)];

        let theme = target.themes.find((item) => item.title === question.theme);
        if (!theme) {
          theme = {
            id: makeId(),
            title: question.theme || `Тема ${target.themes.length + 1}`,
          };
          target.themes.push(theme);
        }
        target.questions.push({
          id: makeId(),
          themeId: theme.id,
          text: question.text,
          answer: question.answer,
          cost: question.cost,
          type: question.type,
          mediaUrl: question.mediaUrl,
          mediaType: question.mediaType,
          aliases: question.aliases,
        });
      }

      setPackName(parsed.name || '');
      setRounds(nextRounds);
      setFinalRound(nextFinal);
      setSelectedStage({ kind: 'round', roundId: nextRounds[0].id });
      setEditing(null);
      setMessage('Пак импортирован');
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Ошибка импорта');
    }
  }

  function handleImportClick(): void {
    importInputRef.current?.click();
  }

  async function handleFileChange(event: ChangeEvent<HTMLInputElement>): Promise<void> {
    const file = event.target.files?.[0] ?? null;
    if (!file) {
      return;
    }
    await importFromFile(file);
    event.target.value = '';
  }

  function saveToDevice(): void {
    clearFeedback();
    const payload: BlitzFileV1 = {
      format: 'blitz-pack',
      version: 1,
      name: packName.trim() || 'Pack',
      rounds,
      finalRound: {
        ...finalRound,
        id: 'final',
        title: 'Финал',
      },
    };
    const baseName = (packName.trim() || 'pack').replace(/[^\w\-]+/g, '_');
    const content = JSON.stringify(payload, null, 2);

    const canPickSaveTarget =
      typeof window !== 'undefined' && 'showSaveFilePicker' in window;

    if (canPickSaveTarget) {
      void (async () => {
        try {
          const pickerWindow = window as unknown as {
            showSaveFilePicker: (options?: {
              suggestedName?: string;
              types?: Array<{
                description?: string;
                accept?: Record<string, string[]>;
              }>;
            }) => Promise<{
              createWritable: () => Promise<{
                write: (data: string) => Promise<void>;
                close: () => Promise<void>;
              }>;
            }>;
          };
          const handle = await pickerWindow.showSaveFilePicker({
            suggestedName: `${baseName}.blitz`,
            types: [
              {
                description: 'BrainBlitz pack',
                accept: {
                  'application/json': ['.blitz'],
                },
              },
            ],
          });
          const writable = await handle.createWritable();
          await writable.write(content);
          await writable.close();
          setMessage('Пак сохранен');
        } catch {
          setError('Сохранение отменено или недоступно');
        }
      })();
      return;
    }

    const blob = new Blob([content], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `${baseName}.blitz`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
    setMessage('Пак сохранен в загрузки браузера');
  }

  return (
    <section className="stack-16">
      <article className="panel stack-8 glass-hero">
        <div className="row gap-8 control-row">
          <h2>{t('packs.title')}</h2>
          <div className="pack-header-actions">
            <button className="primary-action" onClick={saveToDevice}>
              Сохранить
            </button>
            <button className="secondary-action" onClick={handleImportClick}>
              Импортировать
            </button>
            <input
              ref={importInputRef}
              type="file"
              accept=".blitz,application/json,.json"
              className="hidden-file-input"
              onChange={(event) => void handleFileChange(event)}
            />
          </div>
        </div>
        <div className="row gap-8">
          <input placeholder={t('packs.name')} value={packName} onChange={(event) => setPackName(event.target.value)} />
        </div>
      </article>

      <article className="panel stack-8">
        <div className="board-tabs">
          {rounds.map((round) => (
            <div key={round.id} className="board-tab-item">
              <button
                className={
                  selectedStage.kind === 'round' && selectedStage.roundId === round.id
                    ? 'primary-action'
                    : 'secondary-action'
                }
                onClick={() => setSelectedStage({ kind: 'round', roundId: round.id })}
              >
                {round.title}
              </button>
              <button className="danger-button board-tab-delete" onClick={() => removeRound(round.id)}>
                x
              </button>
            </div>
          ))}
          <button className="ghost-button" onClick={addRound}>
            +
          </button>
          <button
            className={selectedStage.kind === 'final' ? 'primary-action' : 'secondary-action'}
            onClick={() => setSelectedStage({ kind: 'final', roundId: 'final' })}
          >
            Раунд финала
          </button>
        </div>

        <div className="pack-game-board">
          {selectedBoard.themes.map((theme) => {
            const themeQuestions = selectedBoard.questions.filter((question) => question.themeId === theme.id);
            return (
              <div key={theme.id} className="pack-board-row">
                <div className="pack-theme-left">
                  <button className="pack-theme-title" onClick={() => renameTheme(theme.id)}>
                    {theme.title}
                  </button>
                  <button className="danger-button pack-theme-delete" onClick={() => removeTheme(theme.id)}>
                    x
                  </button>
                </div>
                <div className="pack-theme-questions">
                  {themeQuestions.map((question) => (
                    <div key={question.id} className="pack-question-wrap">
                      <button
                        className="pack-question-card"
                        onClick={() => openQuestion(theme.id, question.id)}
                      >
                        {question.text.trim() ? question.text : '+'}
                      </button>
                      <button
                        className="danger-button pack-question-delete"
                        onClick={() =>
                          removeQuestionById(
                            selectedStage.kind,
                            selectedStage.kind === 'final' ? 'final' : selectedStage.roundId,
                            question.id,
                          )
                        }
                      >
                        x
                      </button>
                    </div>
                  ))}
                  <button className="pack-question-add" onClick={() => addQuestion(theme.id)}>
                    +
                  </button>
                </div>
              </div>
            );
          })}
          <div className="pack-theme-create-row">
            <button className="pack-theme-add" onClick={addThemeToSelectedBoard}>
              +
            </button>
          </div>
        </div>
      </article>

      {message ? <p className="success-text">{message}</p> : null}
      {error ? <p className="error">{error}</p> : null}

      {editing && editingQuestion ? (
        <div className="modal-backdrop" onClick={closeEditor}>
          <section className="modal-card panel stack-16" onClick={(event) => event.stopPropagation()}>
            <h3>Редактирование вопроса</h3>
            <p className="subtle-copy">Тема: {editingThemeTitle || '—'}</p>
            <textarea
              placeholder={t('editor.question_text')}
              value={editingQuestion.text}
              onChange={(event) => updateEditingQuestion({ text: event.target.value })}
            />
            <input
              placeholder={t('editor.answer')}
              value={editingQuestion.answer}
              onChange={(event) => updateEditingQuestion({ answer: event.target.value })}
            />
            <div className="row gap-8 control-row">
              <input
                className="narrow-input"
                type="number"
                min={0}
                value={editingQuestion.cost}
                onChange={(event) =>
                  updateEditingQuestion({ cost: Number.parseInt(event.target.value, 10) || 0 })
                }
              />
              <select
                value={editingQuestion.type}
                onChange={(event) => updateEditingQuestion({ type: event.target.value as QuestionType })}
              >
                {questionTypes.map((item) => (
                  <option key={item} value={item}>
                    {item}
                  </option>
                ))}
              </select>
              <select
                value={editingQuestion.mediaType}
                onChange={(event) =>
                  updateEditingQuestion({ mediaType: event.target.value as QuestionMediaType })
                }
              >
                {mediaTypes.map((item) => (
                  <option key={item} value={item}>
                    {item}
                  </option>
                ))}
              </select>
            </div>
            <input
              placeholder={t('editor.media_url')}
              value={editingQuestion.mediaUrl}
              onChange={(event) => updateEditingQuestion({ mediaUrl: event.target.value })}
            />
            <input
              placeholder={t('editor.aliases')}
              value={editingQuestion.aliases.join(', ')}
              onChange={(event) =>
                updateEditingQuestion({
                  aliases: event.target.value
                    .split(',')
                    .map((item) => item.trim())
                    .filter(Boolean),
                })
              }
            />
            <div className="row gap-8 dialog-actions">
              <button className="primary-action" onClick={closeEditor}>
                {t('profile.save')}
              </button>
              <button className="danger-button" onClick={deleteEditingQuestion}>
                {t('editor.delete')}
              </button>
              <button className="ghost-button" onClick={closeEditor}>
                {t('settings.cancel')}
              </button>
            </div>
          </section>
        </div>
      ) : null}
    </section>
  );
}
