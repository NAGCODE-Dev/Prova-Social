import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/backend/attempt_draft_store.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:prova_social/features/quiz/quiz_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Focus Mode fits a narrow phone with larger system text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AttemptDraftStore();
    const exam = Exam(
      id: 'small-phone',
      category: 'Geral',
      title: 'Prova',
      description: '',
      author: 'Fonte',
      durationMinutes: 30,
      attempts: 0,
      questions: [
        Question(
          id: 'q1',
          topic: 'Geral',
          statement: 'Pergunta?',
          options: ['Alternativa um', 'Alternativa dois'],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: QuizPage(exam: exam, draftStore: store),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Questão 1 de 1'), findsOneWidget);
    expect(find.text('Revisar entrega'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
