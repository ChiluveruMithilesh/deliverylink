import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/providers/core_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Offline cache / local queue for sync-when-reconnected support.
  await Hive.initFlutter();

  // Firebase.initializeApp() is intentionally not called here without
  // platform config files (google-services.json / GoogleService-Info.plist).
  // Add them under android/app and ios/Runner, then uncomment:
  // await Firebase.initializeApp();

  runApp(const ProviderScope(child: DeliveryLinkApp()));
}

class DeliveryLinkApp extends ConsumerWidget {
  const DeliveryLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final isDark = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'DeliveryLink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      locale: Locale(locale),
      supportedLocales: const [Locale('en'), Locale('te')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
