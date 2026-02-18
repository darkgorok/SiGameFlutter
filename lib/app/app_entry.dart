import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/firebase_config.dart';
import '../core/l10n.dart';
import '../features/home/home_screen.dart';
import '../features/profile/initial_profile_setup_screen.dart';
import '../l10n/app_localizations.dart';
import 'application/app_locale_controller.dart';
import 'application/bootstrap_provider.dart';
import 'presentation/global_async_feedback.dart';
import 'presentation/loading_screen.dart';
import 'router.dart';

class SiGameApp extends ConsumerWidget {
  const SiGameApp({super.key});

  ThemeData _darkGameTheme() {
    const bg = Color(0xFF2B2B2B);
    const surface = Color(0xFF343434);
    const surfaceSoft = Color(0xFF3D3D3D);
    const stroke = Color(0xFF4C4C4C);
    const textMuted = Color(0xFF9AA1AA);
    const accent = Color(0xFFEDEFF2);

    const radius = 22.0;

    final scheme = const ColorScheme.dark(
      primary: accent,
      onPrimary: Color(0xFF101114),
      secondary: Color(0xFFCED4DB),
      onSecondary: Color(0xFF111317),
      error: Color(0xFFFF6D6D),
      onError: Color(0xFF1A0202),
      surface: surface,
      onSurface: Color(0xFFEDEFF2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: stroke,
      fontFamily: 'Segoe UI',
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: Color(0xFFEDEFF2),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: stroke),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.35,
          color: Color(0xFFEDEFF2),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.35,
          color: Color(0xFFD1D6DC),
        ),
        bodySmall: TextStyle(fontSize: 13, height: 1.3, color: textMuted),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF4F6F8),
        ),
        titleSmall: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEDEFF2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoft,
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Color(0xFF646C76), width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: surfaceSoft,
          foregroundColor: const Color(0xFFEDEFF2),
          disabledBackgroundColor: const Color(0xFF1A1D21),
          disabledForegroundColor: const Color(0xFF7B828C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: const BorderSide(color: stroke),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDDE2E8),
          side: const BorderSide(color: stroke),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF14171B),
        contentTextStyle: const TextStyle(color: Color(0xFFE8EDF2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: surfaceSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: stroke),
        ),
        labelColor: const Color(0xFFEFF2F6),
        unselectedLabelColor: textMuted,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocale = ref.watch(appLocaleProvider);
    final dark = _darkGameTheme();
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      themeMode: ThemeMode.dark,
      theme: dark,
      darkTheme: dark,
      locale: appLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ru'), Locale('uk')],
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
      loading: () => const LoadingScreen(),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(context.l10n.initializationError(error.toString())),
          ),
        ),
      ),
      data: (_) {
        if (FirebaseAuth.instance.currentUser == null) {
          return const LoadingScreen();
        }
        return FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                !snapshot.hasData) {
              return const LoadingScreen();
            }
            final nickname =
                snapshot.data?.getString('profile_nickname')?.trim() ?? '';
            if (nickname.isEmpty) {
              return const InitialProfileSetupScreen();
            }
            return const HomeScreen();
          },
        );
      },
    );
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.firebaseNotConfiguredMessage,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
