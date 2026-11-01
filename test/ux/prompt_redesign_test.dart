import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/theme/app_theme.dart';
import 'package:prova_social/core/widgets/source_badge.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:prova_social/features/publish/publish_page.dart';
import 'package:prova_social/features/result/result_page.dart';
import 'package:prova_social/features/search/search_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Exam _exam() => const Exam(
  id: 'real-result',
  title: 'Concurso público',
  category: 'Administrativo',
  description: '',
  author: 'Banca pública',
  year: 2024,
  sourceType: ExamSourceType.official,
  durationMinutes: 60,
  attempts: 12,
  questions: [
    Question(
      id: 'question-1',
      topic: 'Direito constitucional',
      statement: 'Enunciado da questão.',
      options: ['Alternativa A', 'Alternativa B'],
      correctIndex: 0,
    ),
  ],
);

void main() {
  testWidgets('Explore emphasizes study intent and shows source provenance', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SearchPage(search: (_) async => [_exam()], onOpen: (_) {}),
      ),
    );
    expect(find.text('O que você quer estudar?'), findsOneWidget);
    expect(find.text('Sugestões para começar'), findsOneWidget);
    expect(find.text('Direito Constitucional'), findsOneWidget);
    expect(find.text('Fontes oficiais'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), 'constitucional');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(SourceBadge), findsOneWidget);
    expect(find.text('Concurso público'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Explore suggestions fit a narrow screen with larger text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 760),
            devicePixelRatio: 1,
            textScaler: TextScaler.linear(1.25),
          ),
          child: SearchPage(search: (_) async => [], onOpen: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Português'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Português'), findsOneWidget);
    expect(find.text('Direito Constitucional'), findsOneWidget);
    expect(find.text('INEP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Publish options use a single column on mobile', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const PublishPage()),
    );

    final pdf = tester.getTopLeft(find.text('Importar PDF'));
    final json = tester.getTopLeft(find.text('Importar JSON'));
    expect(json.dy, greaterThan(pdf.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Publish options use two columns when space is available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const PublishPage()),
    );

    final pdf = tester.getTopLeft(find.text('Importar PDF'));
    final json = tester.getTopLeft(find.text('Importar JSON'));
    expect((json.dy - pdf.dy).abs(), lessThan(40));
    expect(json.dx, greaterThan(pdf.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Result visualizes subject performance at large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final result = ExamResult(
      exam: _exam(),
      answers: const {0: 0},
      markedForReview: const {},
      durationSeconds: 120,
      finishedAt: DateTime.utc(2026, 11, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: ResultPage(result: result),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Desempenho por assunto'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      1,
    );
    expect(tester.takeException(), isNull);
  });
}
