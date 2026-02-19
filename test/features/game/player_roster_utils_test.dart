import 'package:flutter_test/flutter_test.dart';
import 'package:si_game_flutter/features/game/game_models.dart';
import 'package:si_game_flutter/features/game/presentation/player_roster_utils.dart';

PlayerModel _player({
  required String uid,
  required PlayerRole role,
  bool finalWagerSubmitted = false,
}) {
  return PlayerModel(
    uid: uid,
    nickname: uid,
    avatarUrl: '',
    role: role,
    score: 0,
    connected: true,
    correctAnswers: 0,
    wrongAnswers: 0,
    buzzCount: 0,
    finalWager: 0,
    finalWagerSubmitted: finalWagerSubmitted,
    finalAnswerSubmitted: false,
    finalAnswerText: null,
    finalResult: FinalResult.pending,
    finalRevealed: false,
  );
}

void main() {
  group('summarizeRoster', () {
    test('handles empty roster', () {
      final summary = summarizeRoster(const <PlayerModel>[]);
      expect(summary.total, 0);
      expect(summary.active, 0);
      expect(summary.spectators, 0);
    });

    test('counts one active player', () {
      final summary = summarizeRoster([
        _player(uid: 'p1', role: PlayerRole.player),
      ]);
      expect(summary.total, 1);
      expect(summary.active, 1);
      expect(summary.spectators, 0);
    });

    test('counts many players with spectators', () {
      final summary = summarizeRoster([
        _player(uid: 'host', role: PlayerRole.host),
        _player(uid: 'p1', role: PlayerRole.player),
        _player(uid: 'ed', role: PlayerRole.editor),
        _player(uid: 's1', role: PlayerRole.spectator),
        _player(uid: 's2', role: PlayerRole.spectator),
      ]);
      expect(summary.total, 5);
      expect(summary.active, 3);
      expect(summary.spectators, 2);
    });
  });

  group('allFinalWagersSubmitted', () {
    test('returns false for empty eligible list', () {
      final ok = allFinalWagersSubmitted(
        eligibleUids: const <String>[],
        players: const <PlayerModel>[],
      );
      expect(ok, isFalse);
    });

    test('returns true when all eligible submitted', () {
      final ok = allFinalWagersSubmitted(
        eligibleUids: const ['p1', 'p2'],
        players: [
          _player(
            uid: 'p1',
            role: PlayerRole.player,
            finalWagerSubmitted: true,
          ),
          _player(
            uid: 'p2',
            role: PlayerRole.player,
            finalWagerSubmitted: true,
          ),
          _player(
            uid: 's1',
            role: PlayerRole.spectator,
            finalWagerSubmitted: false,
          ),
        ],
      );
      expect(ok, isTrue);
    });

    test('returns false when at least one eligible did not submit', () {
      final ok = allFinalWagersSubmitted(
        eligibleUids: const ['p1', 'p2'],
        players: [
          _player(
            uid: 'p1',
            role: PlayerRole.player,
            finalWagerSubmitted: true,
          ),
          _player(
            uid: 'p2',
            role: PlayerRole.player,
            finalWagerSubmitted: false,
          ),
        ],
      );
      expect(ok, isFalse);
    });

    test('returns false when eligible uid is missing in players list', () {
      final ok = allFinalWagersSubmitted(
        eligibleUids: const ['p1', 'ghost'],
        players: [
          _player(
            uid: 'p1',
            role: PlayerRole.player,
            finalWagerSubmitted: true,
          ),
        ],
      );
      expect(ok, isFalse);
    });
  });
}
