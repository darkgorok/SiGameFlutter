import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_entry.dart';
import 'core/firebase_config.dart';

export 'app/app_entry.dart' show BrainBlitzApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installWebDebugNoiseFilter();
  await initializeFirebaseFromEnvironment();
  connectFirebaseEmulatorsIfEnabled();
  runApp(const ProviderScope(child: BrainBlitzApp()));
}

void _installWebDebugNoiseFilter() {
  if (!kDebugMode || !kIsWeb) {
    return;
  }

  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    if (_isKnownWebHotRestartNoise(message)) {
      return;
    }
    previousOnError?.call(details);
  };

  final previousPlatformOnError = ui.PlatformDispatcher.instance.onError;
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    if (_isKnownWebHotRestartNoise(error.toString())) {
      return true;
    }
    if (previousPlatformOnError != null) {
      return previousPlatformOnError(error, stack);
    }
    return false;
  };
}

bool _isKnownWebHotRestartNoise(String message) {
  return message.contains('Trying to render a disposed EngineFlutterView') ||
      (message.contains("LegacyJavaScriptObject") &&
          message.contains("DiagnosticsNode"));
}
