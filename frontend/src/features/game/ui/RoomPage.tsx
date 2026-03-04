import { useEffect, useMemo, useState } from 'react';
import { Link, useParams } from 'react-router-dom';

import { auth } from '../../../shared/firebase/client';
import { useI18n } from '../../../shared/i18n/i18nContext';
import { readLocalSettings, subscribeLocalSettings } from '../../../shared/settings/localSettings';
import { gameRepository } from '../data/gameRepository';
import { getRoomUiPermissions } from '../data/gameUiPermissions';
import type { FinalResult, GameEventModel, PlayerModel, QuestionModel, RoomModel } from '../domain/models';

const finalResultOptions: FinalResult[] = ['correct', 'wrong', 'no_answer'];

export function RoomPage() {
  const { t } = useI18n();
  const params = useParams<{ roomId: string }>();
  const roomId = params.roomId ?? '';
  const uid = auth.currentUser?.uid ?? '';

  const [room, setRoom] = useState<RoomModel | null>(null);
  const [players, setPlayers] = useState<PlayerModel[]>([]);
  const [questions, setQuestions] = useState<QuestionModel[]>([]);
  const [events, setEvents] = useState<GameEventModel[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [cleanView, setCleanView] = useState(false);
  const [localSettings, setLocalSettings] = useState(readLocalSettings);

  const [finalTheme, setFinalTheme] = useState('');
  const [finalQuestion, setFinalQuestion] = useState('');
  const [finalAnswer, setFinalAnswer] = useState('');
  const [finalWagerInput, setFinalWagerInput] = useState('100');
  const [finalAnswerInput, setFinalAnswerInput] = useState('');
  const [catTargetUidInput, setCatTargetUidInput] = useState('');
  const [wagerInput, setWagerInput] = useState('100');
  const [numericAnswerInput, setNumericAnswerInput] = useState('0');
  const [scoreDeltaInput, setScoreDeltaInput] = useState('100');
  const [falseStartEnabled, setFalseStartEnabled] = useState(false);
  const [useAppeals, setUseAppeals] = useState(false);
  const [answeringTimerMs, setAnsweringTimerMs] = useState('25000');
  const [pressingTimerMs, setPressingTimerMs] = useState('5000');

  useEffect(() => {
    if (!roomId) {
      return;
    }
    const offRoom = gameRepository.watchRoom(roomId, setRoom);
    const offPlayers = gameRepository.watchPlayers(roomId, setPlayers);
    const offQuestions = gameRepository.watchQuestions(roomId, setQuestions);
    const offEvents = gameRepository.watchEvents(roomId, setEvents);
    return () => {
      offRoom();
      offPlayers();
      offQuestions();
      offEvents();
      void gameRepository.markDisconnected(roomId);
    };
  }, [roomId]);

  useEffect(() => subscribeLocalSettings(setLocalSettings), []);

  useEffect(() => {
    if (!room) {
      return;
    }
    setFalseStartEnabled(room.rules.falseStartEnabled);
    setUseAppeals(room.rules.useAppeals);
    setAnsweringTimerMs(String(room.rules.timers.ANSWERING ?? 25000));
    setPressingTimerMs(String(room.rules.timers.PRESSING ?? 5000));
  }, [room]);

  const scoreboard = useMemo(() => [...players].sort((a, b) => b.score - a.score), [players]);
  const myPlayer = players.find((player) => player.uid === uid) ?? null;
  const myRole = myPlayer?.role ?? 'player';
  const isHost = room?.hostUid === uid;
  const canEdit = isHost || myRole === 'editor';
  const permissions = room
    ? getRoomUiPermissions({
        room,
        uid,
        myRole,
        isHost: Boolean(isHost),
      })
    : null;
  const eligiblePlayers = useMemo(
    () => players.filter((player) => room?.finalEligibleUids.includes(player.uid)),
    [players, room?.finalEligibleUids],
  );
  const effectiveCleanView = myRole === 'spectator' ? !cleanView : cleanView;

  useEffect(() => {
    if (myRole === 'spectator') {
      setCleanView(!localSettings.spectatorCleanViewDefault);
    }
  }, [localSettings.spectatorCleanViewDefault, myRole]);

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

  function eventActorName(actorUid: string): string {
    if (!actorUid) {
      return '-';
    }
    const player = players.find((item) => item.uid === actorUid);
    return player?.nickname ?? actorUid;
  }

  function eventTimeLabel(createdAt: Date | null): string {
    if (!createdAt) {
      return '-';
    }
    const now = new Date();
    const sameDay =
      now.getFullYear() === createdAt.getFullYear() &&
      now.getMonth() === createdAt.getMonth() &&
      now.getDate() === createdAt.getDate();
    const time = createdAt.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    if (sameDay) {
      return time;
    }
    return `${createdAt.toLocaleDateString()} ${time}`;
  }

  useEffect(() => {
    if (!room || !permissions || busy) {
      return;
    }

    const isTextInputFocused = (target: EventTarget | null): boolean => {
      const node = target as HTMLElement | null;
      if (!node) return false;
      if (node.isContentEditable) return true;
      const tag = node.tagName;
      return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT';
    };

    const onKeyDown = (event: KeyboardEvent) => {
      if (isTextInputFocused(event.target)) {
        return;
      }

      const key = event.code;
      if (key === localSettings.answerHotkey && permissions.canBuzz) {
        event.preventDefault();
        void run(() => gameRepository.buzz(roomId));
        return;
      }

      if (!isHost) {
        return;
      }

      if (key === 'KeyS' && permissions.canStartGame) {
        event.preventDefault();
        void run(() => gameRepository.startGame(roomId));
      } else if (key === 'KeyR' && permissions.canAdvanceRound2) {
        event.preventDefault();
        void run(() => gameRepository.advanceToRound2(roomId));
      } else if (key === 'KeyF' && permissions.canStartFinalRound) {
        event.preventDefault();
        void run(() => gameRepository.startFinalRound(roomId));
      } else if (key === 'KeyP') {
        event.preventDefault();
        if (permissions.canResume) {
          void run(() => gameRepository.resumeGame(roomId));
        } else if (permissions.canPause) {
          void run(() => gameRepository.pauseGame(roomId));
        }
      }
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [busy, isHost, localSettings.answerHotkey, permissions, room, roomId]);

  if (!roomId) {
    return <section className="panel">{t('room.invalid')}</section>;
  }

  return (
    <section className="stack-16">
      <article className="panel stack-8">
        <h2>Room {roomId}</h2>
        <p>{room ? `${room.name}: ${room.status} / ${room.phase}` : t('room.loading')}</p>
        {myRole === 'spectator' ? (
          <button className="ghost-button" onClick={() => setCleanView((current) => !current)}>
            {effectiveCleanView ? t('room.show_panels') : t('room.broadcast_mode')}
          </button>
        ) : null}
        <div className="row gap-8">
          <button
            disabled={busy || !permissions?.canStartGame}
            onClick={() => void run(() => gameRepository.startGame(roomId))}
          >
            {t('room.start')}
          </button>
          <button
            disabled={busy || !permissions?.canAdvanceRound2}
            onClick={() => void run(() => gameRepository.advanceToRound2(roomId))}
          >
            {t('room.round2')}
          </button>
          <button
            disabled={busy || !permissions?.canStartFinalRound}
            onClick={() => void run(() => gameRepository.startFinalRound(roomId))}
          >
            {t('room.final')}
          </button>
          <button
            disabled={busy || !permissions?.canOpenBuzzing}
            onClick={() => void run(() => gameRepository.openBuzzing(roomId))}
          >
            {t('room.open_buzzing')}
          </button>
          <button disabled={busy || !permissions?.canBuzz} onClick={() => void run(() => gameRepository.buzz(roomId))}>
            {t('room.buzz')}
          </button>
          <button
            disabled={busy || myRole === 'spectator'}
            onClick={() => void run(() => gameRepository.submitAnswer(roomId))}
          >
            {t('room.submit_answer')}
          </button>
          <button
            disabled={busy || !isHost}
            onClick={() => void run(() => gameRepository.judgeAnswer(roomId, true))}
          >
            {t('room.mark_correct')}
          </button>
          <button
            disabled={busy || !isHost}
            onClick={() => void run(() => gameRepository.judgeAnswer(roomId, false))}
          >
            {t('room.mark_wrong')}
          </button>
          <button
            disabled={busy || !permissions?.canPause}
            onClick={() => void run(() => gameRepository.pauseGame(roomId))}
          >
            {t('room.pause')}
          </button>
          <button
            disabled={busy || !permissions?.canResume}
            onClick={() => void run(() => gameRepository.resumeGame(roomId))}
          >
            {t('room.resume')}
          </button>
          {canEdit ? (
            <Link className="button-link" to={`/room/${roomId}/editor`}>
              {t('room.open_editor')}
            </Link>
          ) : null}
        </div>
        {error ? <p className="error">{error}</p> : null}
      </article>

      {!effectiveCleanView && isHost ? (
        <article className="panel stack-8">
          <h3>{t('room.rules_title')}</h3>
          <label className="row gap-8">
            <input
              type="checkbox"
              checked={falseStartEnabled}
              onChange={(event) => setFalseStartEnabled(event.target.checked)}
            />
            {t('room.rules_false_start')}
          </label>
          <label className="row gap-8">
            <input
              type="checkbox"
              checked={useAppeals}
              onChange={(event) => setUseAppeals(event.target.checked)}
            />
            {t('room.rules_appeals')}
          </label>
          <div className="row gap-8">
            <input
              className="narrow-input"
              type="number"
              min={1000}
              value={answeringTimerMs}
              onChange={(event) => setAnsweringTimerMs(event.target.value)}
            />
            <span>{t('room.rules_timer_answering')}</span>
          </div>
          <div className="row gap-8">
            <input
              className="narrow-input"
              type="number"
              min={1000}
              value={pressingTimerMs}
              onChange={(event) => setPressingTimerMs(event.target.value)}
            />
            <span>{t('room.rules_timer_pressing')}</span>
          </div>
          <div className="row gap-8">
            <button
              disabled={busy}
              onClick={() =>
                void run(() =>
                  gameRepository.updateRoomRules(roomId, {
                    falseStartEnabled,
                    useAppeals,
                    timers: {
                      ANSWERING: Number.parseInt(answeringTimerMs, 10) || 25000,
                      PRESSING: Number.parseInt(pressingTimerMs, 10) || 5000,
                    },
                  }),
                )
              }
            >
              {t('room.rules_save')}
            </button>
            <button disabled={busy} onClick={() => void run(() => gameRepository.handleTimerExpiration(roomId))}>
              {t('room.force_timer_expire')}
            </button>
          </div>
        </article>
      ) : null}

      {!effectiveCleanView && room?.appealActive ? (
        <article className="panel stack-8">
          <h3>{t('room.appeal_title')}</h3>
          <p>
            {t('room.appeal_for')}: {room.appealForUid ?? '-'} / {t('room.appeal_requested_by')}:{' '}
            {room.appealRequestedByUid ?? '-'}
          </p>
          <div className="row gap-8">
            {!isHost ? (
              <button disabled={busy} onClick={() => void run(() => gameRepository.submitAppeal(roomId))}>
                {t('room.appeal_submit')}
              </button>
            ) : null}
            {isHost ? (
              <>
                <button disabled={busy} onClick={() => void run(() => gameRepository.resolveAppeal(roomId, true))}>
                  {t('room.appeal_accept')}
                </button>
                <button disabled={busy} onClick={() => void run(() => gameRepository.resolveAppeal(roomId, false))}>
                  {t('room.appeal_reject')}
                </button>
              </>
            ) : null}
          </div>
        </article>
      ) : null}

      {!effectiveCleanView ? (
        <article className="panel stack-8">
        <h3>{t('room.final_title')}</h3>
        <p>
          Theme: {room?.finalTheme ?? '-'} | Eligible: {room?.finalEligibleUids.length ?? 0}
        </p>
        <p>
          Q: {room?.finalQuestion ?? '-'} | A: {room?.finalAnswer ?? '-'}
        </p>
        <p>
          Current answer player: {room?.finalAnswerCurrentUid ?? '-'} | Current reveal player:{' '}
          {room?.finalRevealCurrentUid ?? '-'}
        </p>

        {isHost ? (
          <div className="stack-8">
            <div className="row gap-8">
              <input
                placeholder="Final theme"
                value={finalTheme}
                onChange={(event) => setFinalTheme(event.target.value)}
              />
              <input
                placeholder="Final question"
                value={finalQuestion}
                onChange={(event) => setFinalQuestion(event.target.value)}
              />
              <input
                placeholder="Final answer"
                value={finalAnswer}
                onChange={(event) => setFinalAnswer(event.target.value)}
              />
              <button
                disabled={busy || !finalTheme.trim() || !finalQuestion.trim() || !finalAnswer.trim()}
                onClick={() =>
                  void run(() =>
                    gameRepository.setFinalQuestion(
                      roomId,
                      finalTheme.trim(),
                      finalQuestion.trim(),
                      finalAnswer.trim(),
                    ),
                  )
                }
              >
                {t('room.final_set_question')}
              </button>
            </div>

            <div className="row gap-8">
              <button
                disabled={busy || room?.phase !== 'final_setup'}
                onClick={() => void run(() => gameRepository.openFinalWagers(roomId))}
              >
                {t('room.final_open_wagers')}
              </button>
              <button
                disabled={busy || room?.phase !== 'final_wagering'}
                onClick={() => void run(() => gameRepository.openFinalAnswers(roomId))}
              >
                {t('room.final_open_answers')}
              </button>
              <button
                disabled={busy || (room?.phase !== 'final_answering' && room?.phase !== 'final_reveal')}
                onClick={() => void run(() => gameRepository.revealFinal(roomId))}
              >
                {t('room.final_reveal')}
              </button>
            </div>

            <div className="row gap-8">
              {(room?.finalThemePool ?? []).map((theme) => (
                <button
                  key={theme}
                  disabled={busy || room.phase !== 'final_setup'}
                  onClick={() => void run(() => gameRepository.deleteFinalTheme(roomId, theme))}
                >
                  {t('room.final_delete_theme')}: {theme}
                </button>
              ))}
            </div>

            <div className="row gap-8">
              {(room?.finalThemeDeleteCandidates ?? []).map((playerUid) => (
                <button
                  key={playerUid}
                  disabled={busy || !room.finalThemeDeleteNeedsSelection}
                  onClick={() =>
                    void run(() => gameRepository.selectFinalThemeDeleter(roomId, playerUid))
                  }
                >
                  {t('room.final_select_deleter')}: {playerUid}
                </button>
              ))}
            </div>

            {eligiblePlayers.map((player) => (
              <div key={`final-result-${player.uid}`} className="room-card">
                <strong>{player.nickname}</strong>
                <span>
                  result: {player.finalResult} / wager: {player.finalWager} / submitted:{' '}
                  {player.finalAnswerSubmitted ? 'yes' : 'no'}
                </span>
                <div className="row gap-8">
                  {finalResultOptions.map((result) => (
                    <button
                      key={`${player.uid}-${result}`}
                      disabled={busy || room?.phase !== 'final_answering'}
                      onClick={() =>
                        void run(() => gameRepository.setFinalPlayerResult(roomId, player.uid, result))
                      }
                    >
                      {result}
                    </button>
                  ))}
                </div>
              </div>
            ))}
          </div>
        ) : null}

        <div className="row gap-8">
          <input
            className="narrow-input"
            type="number"
            min={0}
            value={finalWagerInput}
            onChange={(event) => setFinalWagerInput(event.target.value)}
          />
          <button
            disabled={busy || room?.phase !== 'final_wagering' || !room?.finalEligibleUids.includes(uid)}
            onClick={() =>
              void run(() => gameRepository.submitFinalWager(roomId, Number.parseInt(finalWagerInput, 10) || 0))
            }
          >
            {t('room.final_submit_wager')}
          </button>
          <input
            placeholder="Final answer"
            value={finalAnswerInput}
            onChange={(event) => setFinalAnswerInput(event.target.value)}
          />
          <button
            disabled={
              busy ||
              !finalAnswerInput.trim() ||
              room?.phase !== 'final_answering' ||
              !room?.finalEligibleUids.includes(uid)
            }
            onClick={() => void run(() => gameRepository.submitFinalAnswer(roomId, finalAnswerInput.trim()))}
          >
            {t('room.final_submit_answer')}
          </button>
        </div>
      </article>
      ) : null}

      {!effectiveCleanView ? (
        <article className="panel stack-8">
        <h3>{t('room.special_title')}</h3>
        <div className="row gap-8">
          <input
            placeholder="Cat target UID"
            value={catTargetUidInput}
            onChange={(event) => setCatTargetUidInput(event.target.value)}
          />
          <button
            disabled={busy || !catTargetUidInput.trim() || room?.phase !== 'cat_targeting'}
            onClick={() =>
              void run(() => gameRepository.selectCatTarget(roomId, catTargetUidInput.trim()))
            }
          >
            {t('room.special_select_cat')}
          </button>
        </div>
        <div className="row gap-8">
          <input
            className="narrow-input"
            type="number"
            min={0}
            value={wagerInput}
            onChange={(event) => setWagerInput(event.target.value)}
          />
          <button
            disabled={busy || room?.phase !== 'wager_bidding'}
            onClick={() =>
              void run(() => gameRepository.setWagerAndOpen(roomId, Number.parseInt(wagerInput, 10) || 0))
            }
          >
            {t('room.special_set_wager_open')}
          </button>
        </div>
        <div className="row gap-8">
          <input
            className="narrow-input"
            type="number"
            value={numericAnswerInput}
            onChange={(event) => setNumericAnswerInput(event.target.value)}
          />
          <button
            disabled={busy || room?.phase !== 'answering'}
            onClick={() =>
              void run(
                () => gameRepository.submitNumericAnswer(roomId, Number.parseFloat(numericAnswerInput) || 0),
              )
            }
          >
            {t('room.special_submit_numeric')}
          </button>
        </div>
      </article>
      ) : null}

      {!effectiveCleanView ? (
        <article className="panel stack-8">
        <h3>{t('room.players_title')}</h3>
        {scoreboard.length === 0 ? <p>{t('room.none_players')}</p> : null}
        {scoreboard.map((player) => (
          <div key={player.uid} className="room-card">
            <strong>
              {player.nickname}
              {player.uid === uid ? ' (you)' : ''}
            </strong>
            <span>
              {player.role} / {player.score} / connected: {player.connected ? 'yes' : 'no'}
            </span>
            <span>
              stats: +{player.correctAnswers} / -{player.wrongAnswers} / buzz {player.buzzCount}
            </span>
            {isHost && player.uid !== uid ? (
              <div className="row gap-8">
                <input
                  className="narrow-input"
                  type="number"
                  value={scoreDeltaInput}
                  onChange={(event) => setScoreDeltaInput(event.target.value)}
                />
                <button
                  disabled={busy}
                  onClick={() =>
                    void run(
                      () =>
                        gameRepository.applyScore(
                          roomId,
                          player.uid,
                          Math.abs(Number.parseInt(scoreDeltaInput, 10) || 100),
                        ),
                    )
                  }
                >
                  {t('room.add_score')}
                </button>
                <button
                  disabled={busy}
                  onClick={() =>
                    void run(
                      () =>
                        gameRepository.applyScore(
                          roomId,
                          player.uid,
                          -Math.abs(Number.parseInt(scoreDeltaInput, 10) || 100),
                        ),
                    )
                  }
                >
                  {t('room.remove_score')}
                </button>
                <button
                  disabled={busy}
                  onClick={() => void run(() => gameRepository.setPlayerRole(roomId, player.uid, 'editor'))}
                >
                  {t('room.make_editor')}
                </button>
                <button
                  disabled={busy}
                  onClick={() =>
                    void run(() => gameRepository.setPlayerRole(roomId, player.uid, 'spectator'))
                  }
                >
                  {t('room.make_spectator')}
                </button>
                <button
                  disabled={busy}
                  onClick={() => void run(() => gameRepository.setPlayerRole(roomId, player.uid, 'player'))}
                >
                  {t('room.make_player')}
                </button>
                <button
                  className="danger-button"
                  disabled={busy}
                  onClick={() => void run(() => gameRepository.kickPlayer(roomId, player.uid))}
                >
                  {t('room.kick')}
                </button>
                <button
                  className="danger-button"
                  disabled={busy}
                  onClick={() => {
                    const reason = window.prompt(t('room.ban_reason_prompt'))?.trim() ?? '';
                    void run(() => gameRepository.banPlayer(roomId, player.uid, reason));
                  }}
                >
                  {t('room.ban')}
                </button>
                <button
                  disabled={busy}
                  onClick={() => void run(() => gameRepository.unbanPlayer(roomId, player.uid))}
                >
                  {t('room.unban')}
                </button>
              </div>
            ) : null}
          </div>
        ))}
      </article>
      ) : null}

      {!effectiveCleanView ? (
        <article className="panel stack-8">
        <h3>{t('room.questions_title')}</h3>
        {questions.length === 0 ? <p>{t('room.none_questions')}</p> : null}
        {questions.slice(0, 50).map((question) => (
          <div key={question.id} className="room-card">
            <div>
              <strong>{question.theme}</strong>
              <p>
                {question.cost} / {question.type} / r{question.round}
              </p>
              {question.mediaUrl ? <p>media: {question.mediaType}</p> : null}
            </div>
            <div className="row gap-8">
              <span>{question.used ? t('room.status_used') : t('room.status_open')}</span>
              <button
                disabled={busy || !permissions?.canPickQuestion || question.used}
                onClick={() => void run(() => gameRepository.pickQuestion(roomId, question.id))}
              >
                {t('room.question_pick')}
              </button>
            </div>
          </div>
        ))}
      </article>
      ) : null}

      {!effectiveCleanView ? (
        <article className="panel stack-8">
          <h3>{t('room.log_title')}</h3>
          {events.length === 0 ? <p>{t('room.log_empty')}</p> : null}
          {events.map((event) => (
            <div key={event.id} className="room-card">
              <div>
                <strong>{event.message || event.type}</strong>
                <p>
                  {eventActorName(event.actorUid)} / {eventTimeLabel(event.createdAt)}
                </p>
              </div>
            </div>
          ))}
        </article>
      ) : null}
    </section>
  );
}
