import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/bootstrap_provider.dart';
import 'presentation/global_async_feedback.dart';
import 'router.dart';
import '../core/firebase_config.dart';
import '../features/home/home_screen.dart';

class SiGameApp extends StatelessWidget {
  const SiGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Своя игра онлайн',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF002E6D)),
        scaffoldBackgroundColor: const Color(0xFFF6F8FD),
      ),
      builder: (context, child) {
        return GlobalAsyncFeedback(child: child ?? const SizedBox.shrink());
      },
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: firebaseConfigured
          ? const BootstrapScreen()
          : const FirebaseSetupScreen(),
    );
  }
}

class BootstrapScreen extends ConsumerStatefulWidget {
  const BootstrapScreen({super.key});

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends ConsumerState<BootstrapScreen> {
  @override
  Widget build(BuildContext context) {
    final bootstrapAsync = ref.watch(bootstrapProvider);
    return bootstrapAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Ошибка инициализации: $error'),
          ),
        ),
      ),
      data: (_) {
        if (FirebaseAuth.instance.currentUser == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const HomeScreen();
      },
    );
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Firebase не настроен.\n\n'
            'Создай локальный файл config/firebase.web.json (пример в '
            'config/firebase.web.example.json), затем запусти:\n\n'
            'flutter run -d chrome --dart-define-from-file=config/firebase.web.json\n\n'
            'Тогда будут доступны комнаты, синхронизация, ре-коннект и онлайн-игра.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
