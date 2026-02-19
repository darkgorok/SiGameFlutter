import 'package:flutter_test/flutter_test.dart';
import 'package:si_game_flutter/features/game/game_models.dart';

void main() {
  group('QuestionType.fromValue normalization', () {
    test('normalizes bagcat to cat_in_bag', () {
      expect(QuestionType.fromValue('bagcat'), QuestionType.cat);
    });

    test('normalizes secret_no_question to cat_in_bag', () {
      expect(QuestionType.fromValue('secret_no_question'), QuestionType.cat);
    });

    test('normalizes stake_all to wager', () {
      expect(QuestionType.fromValue('stake_all'), QuestionType.wager);
    });
  });
}
