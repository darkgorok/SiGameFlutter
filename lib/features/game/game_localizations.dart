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
