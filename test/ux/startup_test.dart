import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/startup/startup_gate.dart';
import 'package:prova_social/core/widgets/brand.dart';

void main() {
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
