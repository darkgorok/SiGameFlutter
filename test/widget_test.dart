import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:si_game_flutter/main.dart';

void main() {
  testWidgets('shows Firebase setup screen when no dart-defines are set', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BrainBlitzApp()));

    expect(find.textContaining('Firebase'), findsOneWidget);
  });
}
