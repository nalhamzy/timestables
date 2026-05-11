import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/tokens.dart';
import 'features/home/presentation/home_screen.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only — non-timed kids drill UX (SPEC §10 item 9)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Global error handler — logs locally, no telemetry (SPEC §9)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  runApp(
    const ProviderScope(
      child: TimesTablesApp(),
    ),
  );
}

class TimesTablesApp extends ConsumerStatefulWidget {
  const TimesTablesApp({super.key});

  @override
  ConsumerState<TimesTablesApp> createState() => _TimesTablesAppState();
}

class _TimesTablesAppState extends ConsumerState<TimesTablesApp> {
  @override
  void initState() {
    super.initState();
    // Silently restore purchases on launch to refresh cached entitlement state.
    // IapService.initialize() also calls restorePurchases() internally.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(iapServiceProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Times Tables Trainer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: kBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
