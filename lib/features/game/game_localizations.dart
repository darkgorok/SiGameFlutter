import 'package:flutter/widgets.dart';

import '../../core/l10n.dart';
import 'game_models.dart';

extension GameStatusL10n on GameStatus {
  String localizedLabel(BuildContext context) {
    final l10n = context.l10n;
    switch (this) {
      case GameStatus.lobby:
        return l10n.gameStatusLobby;
      case GameStatus.inGame:
        return l10n.gameStatusInGame;
      case GameStatus.paused:
        return l10n.gameStatusPaused;
      case GameStatus.finalRound:
        return l10n.gameStatusFinalRound;
      case GameStatus.completed:
        return l10n.gameStatusCompleted;
    }
  }
}

extension GamePhaseL10n on GamePhase {
  String localizedLabel(BuildContext context) {
    final l10n = context.l10n;
    switch (this) {
      case GamePhase.lobby:
        return l10n.gamePhaseLobby;
      case GamePhase.boardSelect:
        return l10n.gamePhaseBoardSelect;
      case GamePhase.questionReveal:
        return l10n.gamePhaseQuestionReveal;
      case GamePhase.catTargeting:
        return l10n.gamePhaseCatTargeting;
      case GamePhase.wagerBidding:
        return l10n.gamePhaseWagerBidding;
      case GamePhase.answering:
        return l10n.gamePhaseAnswering;
      case GamePhase.answerReview:
        return l10n.gamePhaseAnswerReview;
      case GamePhase.finalSetup:
        return l10n.gamePhaseFinalSetup;
      case GamePhase.finalWagering:
        return l10n.gamePhaseFinalWagering;
      case GamePhase.finalAnswering:
        return l10n.gamePhaseFinalAnswering;
      case GamePhase.finalReveal:
        return l10n.gamePhaseFinalReveal;
      case GamePhase.gameOver:
        return l10n.gamePhaseGameOver;
    }
  }
}

extension QuestionTypeL10n on QuestionType {
  String localizedLabel(BuildContext context) {
    final l10n = context.l10n;
    switch (this) {
      case QuestionType.normal:
        return l10n.questionTypeNormal;
      case QuestionType.cat:
        return l10n.questionTypeCat;
      case QuestionType.wager:
        return l10n.questionTypeWager;
      case QuestionType.closestNumber:
        return l10n.questionTypeClosestNumber;
    }
  }
}

extension QuestionMediaTypeL10n on QuestionMediaType {
  String localizedLabel(BuildContext context) {
    final l10n = context.l10n;
    switch (this) {
      case QuestionMediaType.none:
        return l10n.questionMediaNone;
      case QuestionMediaType.image:
        return l10n.questionMediaImage;
      case QuestionMediaType.audio:
        return l10n.questionMediaAudio;
      case QuestionMediaType.video:
        return l10n.questionMediaVideo;
    }
  }
}

extension PlayerRoleL10n on PlayerRole {
  String localizedLabel(BuildContext context) {
    final l10n = context.l10n;
    switch (this) {
      case PlayerRole.host:
        return l10n.roleHost;
      case PlayerRole.player:
        return l10n.rolePlayer;
      case PlayerRole.spectator:
        return l10n.roleSpectator;
      case PlayerRole.editor:
        return l10n.roleEditor;
    }
  }
}

extension FinalResultL10n on FinalResult {
  String localizedLabel(BuildContext context) {
    final l10n = context.l10n;
    switch (this) {
      case FinalResult.pending:
        return l10n.finalResultPending;
      case FinalResult.correct:
        return l10n.finalResultCorrect;
      case FinalResult.wrong:
        return l10n.finalResultWrong;
      case FinalResult.noAnswer:
        return l10n.finalResultNoAnswer;
    }
  }
}

extension GameEventL10n on GameEventModel {
  String localizedMessage(BuildContext context) {
    final l10n = context.l10n;
    switch (type) {
      case 'question_add':
        return l10n.eventQuestionAdd;
      case 'question_add_bulk':
        return l10n.eventQuestionAddBulk;
      case 'question_update':
        return l10n.eventQuestionUpdate;
      case 'question_delete':
        return l10n.eventQuestionDelete;
      case 'pack_save':
        return l10n.eventPackSave;
      case 'pack_apply':
        return l10n.eventPackApply;
      case 'timer_expire':
        return l10n.eventTimerExpire;
      case 'final_reveal_start':
        return l10n.eventFinalRevealStart;
      case 'final_reveal_end':
        return l10n.eventFinalRevealEnd;
      case 'final_reveal_step':
        return l10n.eventFinalRevealStep;
      case 'answer_submit':
        return l10n.eventAnswerSubmit;
      case 'answer_submit_numeric':
        return l10n.eventAnswerSubmitNumeric;
      case 'final_start':
        return l10n.eventFinalStart;
      case 'judge':
        return l10n.eventJudge;
      case 'appeal_submit':
        return l10n.eventAppealSubmit;
      case 'appeal_resolve':
        return l10n.eventAppealResolve;
      case 'score_manual':
        return l10n.eventScoreManual;
      case 'pause':
        return l10n.eventPause;
      case 'resume':
        return l10n.eventResume;
      case 'final_question_set':
        return l10n.eventFinalQuestionSet;
      case 'final_theme_deleter_selected':
        return l10n.eventFinalThemeDeleterSelected;
      case 'final_theme_deleted':
        return l10n.eventFinalThemeDeleted;
      case 'final_wager_open':
        return l10n.eventFinalWagerOpen;
      case 'final_answers_open':
        return l10n.eventFinalAnswersOpen;
      case 'final_answer_submit':
        return l10n.eventFinalAnswerSubmit;
      case 'final_wager':
        return l10n.eventFinalWager;
      case 'final_mark':
        return l10n.eventFinalMark;
      case 'start':
        return l10n.eventStart;
      case 'question_pick':
        return l10n.eventQuestionPick;
      case 'buzz_open':
        return l10n.eventBuzzOpen;
      case 'cat_target':
        return l10n.eventCatTarget;
      case 'wager_set':
        return l10n.eventWagerSet;
      case 'round_next':
        return l10n.eventRoundNext;
      case 'buzz':
        return l10n.eventBuzz;
      case 'room_created':
        return l10n.eventRoomCreated;
      case 'join':
        return l10n.eventJoin;
      case 'role_change':
        return l10n.eventRoleChange;
      case 'kick':
        return l10n.eventKick;
      case 'ban':
        return l10n.eventBan;
      case 'unban':
        return l10n.eventUnban;
      case 'rules_update':
        return l10n.eventRulesUpdate;
    }
    return message.trim().isEmpty ? type : message;
  }
}
