import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/storage/preferences.dart';
import 'core/supabase/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/account_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Both loaded before the first frame so the splash can decide where to go
  // without waiting on a future. Supabase restores any saved session here.
  final prefs = await SharedPreferences.getInstance();
  final supabase = await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(supabase.client),
      ],
      child: const YumeterApp(),
    ),
  );
}

class YumeterApp extends ConsumerStatefulWidget {
  const YumeterApp({super.key});

  @override
  ConsumerState<YumeterApp> createState() => _YumeterAppState();
}

class _YumeterAppState extends ConsumerState<YumeterApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Coming back to the app is the likeliest moment a connection returned,
    // so retry anything logged offline.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(accountSyncProvider).syncAll(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Yumeter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
