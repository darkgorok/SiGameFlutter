import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/application/app_locale_controller.dart';
import '../l10n.dart';

class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedLocale = ref.watch(appLocaleProvider);
    final selectedCode =
        selectedLocale?.languageCode ??
        Localizations.localeOf(context).languageCode;
    final currentCode = supportedLanguageCodes.contains(selectedCode)
        ? selectedCode
        : 'en';
    const orderedCodes = <String>['en', 'ru', 'uk'];
    final currentIndex = orderedCodes.indexOf(currentCode);
    const totalWidth = 300.0;
    const height = 44.0;
    const segmentWidth = totalWidth / 3;

    final labels = <String, String>{
      'en': context.l10n.languageEnglish,
      'ru': context.l10n.languageRussian,
      'uk': context.l10n.languageUkrainian,
    };

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.languageLabel),
            const SizedBox(height: 8),
            SizedBox(
              width: totalWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      left: currentIndex * segmentWidth,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: segmentWidth,
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: orderedCodes
                          .map(
                            (code) => Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => ref
                                    .read(appLocaleProvider.notifier)
                                    .setLanguageCode(code),
                                child: Center(
                                  child: Text(
                                    labels[code]!,
                                    style: TextStyle(
                                      fontWeight: code == currentCode
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
