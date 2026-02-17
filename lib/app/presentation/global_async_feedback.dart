import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../features/game/application/game_providers.dart';

class GlobalAsyncFeedback extends ConsumerWidget {
  const GlobalAsyncFeedback({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<void>>(gameActionsControllerProvider, (prev, next) {
      final hadSameError = prev?.hasError == true && prev?.error == next.error;
      if (!next.hasError || hadSameError) {
        return;
      }
      final failure = mapErrorToFailure(next.error!);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    });
    return child;
  }
}
