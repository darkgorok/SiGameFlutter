import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/errors/app_failure.dart';
import '../../core/widgets/app_popup.dart';
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
      final message = switch (failure.code) {
        'permission_denied' => context.l10n.appFailurePermissionDenied,
        'network_error' => context.l10n.appFailureNetworkError,
        _ => failure.message,
      };
      showAppPopup(context, message: message, type: AppPopupType.error);
    });
    return child;
  }
}
