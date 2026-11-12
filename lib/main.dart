import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    runApp(_SupabaseConfigRequiredApp(preferences: preferences));
    return;
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
    accessToken: () async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return user.getIdToken();
    },
  );
  runApp(PeoplePulseApp(preferences: preferences));
}

class PeoplePulseApp extends StatelessWidget {
  const PeoplePulseApp({required this.preferences, super.key});

  final SharedPreferences preferences;

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF3B6F64);

    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(preferences),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'PeoplePulse',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: brandColor,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF8F9F7),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF8F9F7),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: brandColor,
              brightness: Brightness.dark,
            ),
            appBarTheme: const AppBarTheme(
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            ),
          ),
          home: const AuthGate(),
        ),
      ),
    );
  }
}

class _SupabaseConfigRequiredApp extends StatelessWidget {
  const _SupabaseConfigRequiredApp({required this.preferences});

  final SharedPreferences preferences;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(preferences),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'PeoplePulse',
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3B6F64),
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3B6F64),
              brightness: Brightness.dark,
            ),
          ),
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings_rounded, size: 40),
                      SizedBox(height: 12),
                      Text(
                        'Supabase configuration is missing.',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Run the app with SUPABASE_URL and '
                        'SUPABASE_PUBLISHABLE_KEY dart-define values. '
                        'See README.md for setup instructions.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
