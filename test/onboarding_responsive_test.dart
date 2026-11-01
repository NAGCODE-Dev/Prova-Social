import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prova_social/core/theme/app_theme.dart';
import 'package:prova_social/features/onboarding/onboarding_page.dart';

void main() {
  testWidgets('onboarding fits a landscape phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const OnboardingPage()),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Encontre o que estudar'), findsOneWidget);
    expect(
      find.text(
        'Busque provas por concurso, banca ou matéria e confira a origem antes de começar.',
      ),
      findsOneWidget,
    );
    expect(find.text('Continuar'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Resolva sem distrações'), findsOneWidget);
    expect(find.text('Voltar'), findsOneWidget);

    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Encontre o que estudar'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Transforme PDF em prova'), findsOneWidget);
    expect(find.text('Explorar sem conta'), findsOneWidget);
  });
}
