import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/startup/startup_gate.dart';
import 'package:prova_social/core/backend/supabase_config.dart';
import 'package:prova_social/core/theme/app_theme.dart';
import 'package:prova_social/core/update/update_gate.dart';
import 'package:prova_social/core/widgets/brand.dart';
import 'package:prova_social/core/widgets/emerald_backdrop.dart';

void main() {
  testWidgets('the initial screen keeps the brand backdrop, not a light box', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        builder: (context, child) =>
            EmeraldBackdrop(child: child ?? const SizedBox.shrink()),
        home: const UpdateGate(child: Text('Pronto')),
      ),
    );

    expect(
      find.ancestor(
        of: find.text('Pronto'),
        matching: find.byType(EmeraldBackdrop),
      ),
      findsOneWidget,
    );
    expect(
      AppTheme.dark.scaffoldBackgroundColor,
      isSameColorAs(Colors.transparent),
    );
    final lightBoxes = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((box) => box.color == AppColors.background)
        .toList();
    expect(
      lightBoxes,
      isEmpty,
      reason: 'a light palette box hides the backdrop',
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Supabase configuration failure explains how to recover', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StartupGate(
          initialize: () => Future<void>.error(
            const SupabaseConfigurationException(
              'Informe SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY.',
            ),
          ),
          child: const Text('Pronto'),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text('Informe SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY.'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  for (final reduced in [false, true]) {
    testWidgets(
      'static book, ring respects reduced motion=$reduced; no startup delay',
      (tester) async {
        final ready = Completer<void>();
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: StartupGate(
                initialize: () => ready.future,
                child: const Text('Pronto'),
              ),
            ),
          ),
        );
        expect(find.byType(BrandMark), findsOneWidget);
        final builders = tester.widgetList<AnimatedBuilder>(
          find.byType(AnimatedBuilder),
        );
        final controller = builders
            .map((w) => w.animation)
            .whereType<AnimationController>()
            .single;
        expect(controller.isAnimating, !reduced);
        final value = controller.value;
        await tester.pump(const Duration(milliseconds: 200));
        expect(controller.value == value, reduced);
        ready.complete();
        await tester.pump();
        await tester.pump();
        expect(find.text('Pronto'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
