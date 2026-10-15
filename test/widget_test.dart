import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:people_pulse/providers/hr_provider.dart';
import 'package:people_pulse/screens/app_shell.dart';
import 'package:people_pulse/services/hr_service.dart';

void main() {
  testWidgets('shows the dashboard and navigates to time off', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => HrProvider(HrService())..load(),
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PeoplePulse'), findsOneWidget);
    expect(find.text('Good ${_greeting()},'), findsOneWidget);

    await tester.tap(find.text('Time off'));
    await tester.pumpAndSettle();

    expect(find.text('Your requests'), findsOneWidget);
    expect(find.text('Request time off'), findsOneWidget);
  });
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'morning';
  if (hour < 17) return 'afternoon';
  return 'evening';
}
