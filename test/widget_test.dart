import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:myhealth/features/consent/consent_screen.dart';

void main() {
  testWidgets('Экран согласия показывает кнопку "Принимаю"', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ConsentScreen()),
      ),
    );
    // Дожидаемся завершения анимаций появления (flutter_animate).
    await tester.pumpAndSettle();

    expect(find.text('Ваши данные остаются у вас'), findsOneWidget);
    expect(find.text('Принимаю'), findsOneWidget);
  });
}
