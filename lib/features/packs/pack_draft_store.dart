import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/shared_prefs_cache.dart';

class PackDraftStore {
  const PackDraftStore({required this.prefsKey, required this.fileName});

  final String prefsKey;
  final String fileName;

  Future<File?> _draftFile() async {
    if (kIsWeb) {
      return null;
    }
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  Future<String?> loadRaw() async {
    if (kIsWeb) {
      final prefs = await getSharedPreferencesCached();
      return prefs.getString(prefsKey);
    }
    final file = await _draftFile();
    if (file == null || !await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  Future<void> saveRaw(String raw) async {
    if (kIsWeb) {
      final prefs = await getSharedPreferencesCached();
      await prefs.setString(prefsKey, raw);
      return;
    }
    final file = await _draftFile();
    if (file == null) {
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(raw, flush: true);
  }

  Future<void> clearRaw() async {
    if (kIsWeb) {
      final prefs = await getSharedPreferencesCached();
      await prefs.remove(prefsKey);
      return;
    }
    final file = await _draftFile();
    if (file == null || !await file.exists()) {
      return;
    }
    await file.delete();
  }
}
