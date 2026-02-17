import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_entry.dart';
import 'core/firebase_config.dart';

export 'app/app_entry.dart' show SiGameApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebaseFromEnvironment();
  runApp(const ProviderScope(child: SiGameApp()));
}
