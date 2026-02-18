import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:si_game_flutter/features/packs/pack_editor_screen.dart';
import 'package:si_game_flutter/l10n/app_localizations.dart';

void main() {
  Widget buildTestApp() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PackEditorScreen(startEmpty: true),
    );
  }

  testWidgets('renders core editor actions', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.upload_file), findsWidgets);
    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(find.byIcon(Icons.undo), findsOneWidget);
    expect(find.byIcon(Icons.redo), findsOneWidget);
  });

  testWidgets('shows unsaved draft state after edit', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final field = find.byType(TextField).first;
    await tester.enterText(field, 'New Name');
    await tester.pump();

    expect(find.text('Unsaved'), findsOneWidget);
  });
}
