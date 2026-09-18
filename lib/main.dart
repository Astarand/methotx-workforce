import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/notification_service.dart';
import 'core/services/remote_config_service.dart';
import 'core/services/storage_service.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'routes/app_router.dart';

// Global GoRouter instance for handling navigation from background/terminated notifications
GoRouter? globalRouter;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Run Firebase and SharedPreferences initialization concurrently in parallel
  final results = await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    SharedPreferences.getInstance(),
  ]);

  final prefs = results[1] as SharedPreferences;

  // On iOS, Keychain persists even across app uninstalls.
  // On a truly fresh install (SharedPreferences empty), wipe orphaned Keychain credentials.
  final isFirstRun = prefs.getBool('app_first_run_completed') != true;
  if (isFirstRun) {
    const secureStorage = FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
    await secureStorage.deleteAll();
    await prefs.setBool('app_first_run_completed', true);
  }

  // Set preferred orientation non-blocking
  unawaited(
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  );

  // Enforce navigation/status bar defaults globally
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Push Notification & Local Notification services in background
  unawaited(NotificationService.instance.initialize());

  // Initialize Firebase Remote Config for In-App Updates in background
  unawaited(RemoteConfigService().initialize());

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MethotXApp(),
    ),
  );
}

class MethotXApp extends ConsumerWidget {
  const MethotXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Expose the router globally so NotificationService can navigate
    globalRouter = router;

    return MaterialApp.router(
      title: 'MethotX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
