import 'package:flutter/material.dart';

import '../l10n.dart';

enum AppPopupType { info, error, success }

Future<void> showAppPopup(
  BuildContext context, {
  required String message,
  AppPopupType type = AppPopupType.info,
  String? title,
}) {
  final scheme = Theme.of(context).colorScheme;
  final (icon, accent) = switch (type) {
    AppPopupType.error => (Icons.error_outline, scheme.error),
    AppPopupType.success => (
      Icons.check_circle_outline,
      const Color(0xFF35C67A),
    ),
    AppPopupType.info => (Icons.info_outline, scheme.primary),
  };

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'popup',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title ?? _defaultTitle(type, context),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(message),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.l10n.popupOk),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

String _defaultTitle(AppPopupType type, BuildContext context) {
  return switch (type) {
    AppPopupType.error => context.l10n.popupErrorTitle,
    AppPopupType.success => context.l10n.popupSuccessTitle,
    AppPopupType.info => context.l10n.popupInfoTitle,
  };
}
