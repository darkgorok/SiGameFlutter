import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/shared_prefs_cache.dart';

const supportedLanguageCodes = <String>{'en', 'ru', 'uk'};

final appLocaleProvider = StateNotifierProvider<AppLocaleController, Locale?>((
  ref,
) {
  return AppLocaleController();
});

class AppLocaleController extends StateNotifier<Locale?> {
  AppLocaleController() : super(null) {
    unawaited(_loadSavedLocale());
  }

  bool _explicitSelection = false;

  Future<void> _loadSavedLocale() async {
    final prefs = await getSharedPreferencesCached();
    final savedCode = prefs.getString('setting_language_code');
    if (_explicitSelection) return;
    if (savedCode == null || !supportedLanguageCodes.contains(savedCode)) {
      return;
    }
    state = Locale(savedCode);
  }

  Future<void> setLanguageCode(String code) async {
    if (!supportedLanguageCodes.contains(code)) return;
    _explicitSelection = true;
    state = Locale(code);
    final prefs = await getSharedPreferencesCached();
    await prefs.setString('setting_language_code', code);
  }
}
