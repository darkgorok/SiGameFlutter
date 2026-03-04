export type GameStatus = 'lobby' | 'in_game' | 'paused' | 'final_round' | 'completed';

export type GamePhase =
  | 'lobby'
  | 'board_select'
  | 'question_reveal'
  | 'cat_targeting'
  | 'wager_bidding'
  | 'answering'
  | 'answer_review'
  | 'final_setup'
  | 'final_wagering'
  | 'final_answering'
  | 'final_reveal'
  | 'game_over';

export type PlayerRole = 'host' | 'player' | 'spectator' | 'editor';

export type FinalResult = 'pending' | 'correct' | 'wrong' | 'no_answer';

export type QuestionType = 'normal' | 'cat_in_bag' | 'wager' | 'closest_number';
export type QuestionMediaType = 'none' | 'image' | 'audio' | 'video';

export type RoomModel = {
  id: string;
  name: string;
  hostUid: string;
  passwordProtected: boolean;
  status: GameStatus;
  phase: GamePhase;
  currentRound: number;
  currentQuestionId: string | null;
  currentAttemptUid: string | null;
  buzzQueue: string[];
  pausedByUid: string | null;
  chooserUid: string | null;
  timerDeadlineAtMs: number | null;
  timerRemainingMs: number | null;
  activeQuestion: ActiveQuestion | null;
  targetedUid: string | null;
  wagerValue: number | null;
  finalTheme: string | null;
  finalQuestion: string | null;
  finalAnswer: string | null;
  finalThemePool: string[];
  finalThemeDeleteCandidates: string[];
  finalThemeDeleteNeedsSelection: boolean;
  finalThemeDeleteCurrentUid: string | null;
  finalEligibleUids: string[];
  finalAnswerOrder: string[];
  finalAnswerCurrentUid: string | null;
  finalRevealOrder: string[];
  finalRevealCurrentUid: string | null;
  rules: RoomRules;
  appealActive: boolean;
  appealRequestedByUid: string | null;
  appealForUid: string | null;
};

export type ActiveQuestion = {
  id: string;
  theme: string;
  text: string;
  answer: string;
  cost: number;
  type: QuestionType;
};

export type PlayerModel = {
  uid: string;
  nickname: string;
  role: PlayerRole;
  score: number;
  connected: boolean;
  correctAnswers: number;
  wrongAnswers: number;
  buzzCount: number;
  finalResult: FinalResult;
  finalWager: number;
  finalWagerSubmitted: boolean;
  finalAnswerSubmitted: boolean;
  finalAnswerText: string;
  finalRevealed: boolean;
};

export type GameEventModel = {
  id: string;
  type: string;
  message: string;
  actorUid: string;
  createdAt: Date | null;
};

export type QuestionModel = {
  id: string;
  theme: string;
  text: string;
  answer: string;
  cost: number;
  round: number;
  type: QuestionType;
  mediaUrl: string;
  mediaType: QuestionMediaType;
  aliases: string[];
  used: boolean;
};

export type QuestionDraft = {
  theme: string;
  text: string;
  answer: string;
  cost: number;
  round: number;
  type: QuestionType;
  mediaUrl: string;
  mediaType: QuestionMediaType;
  aliases: string[];
};

export type PackSummary = {
  id: string;
  name: string;
  version: number;
  questionCount: number;
};

export type RoomRules = {
  falseStartEnabled: boolean;
  useAppeals: boolean;
  timers: Record<string, number>;
};
