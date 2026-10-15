import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/hr_provider.dart';
import 'screens/app_shell.dart';
import 'services/hr_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => HrProvider(HrService())..load(),
      child: const PeoplePulseApp(),
    ),
  );
}

class PeoplePulseApp extends StatelessWidget {
  const PeoplePulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF3B6F64);

    return MaterialApp(
      title: 'PeoplePulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandColor,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8F9F7),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const AppShell(),
    );
  }
}
