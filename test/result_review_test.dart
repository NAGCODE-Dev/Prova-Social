import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:prova_social/features/quiz/quiz_page.dart';
import 'package:prova_social/features/result/result_page.dart';
import 'package:prova_social/features/result/review_page.dart';

void main() {
  testWidgets('result opens a virtualized review with working filters', (
    tester,
  ) async {
    final exam = Exam(
      id: 'exam',
      title: 'Prova longa',
      category: 'Geral',
      description: '',
      author: 'Fonte',
      durationMinutes: 60,
      attempts: 0,
      questions: [
        for (var index = 0; index < 100; index++)
          Question(
            id: 'question-$index',
            topic: 'Geral',
            statement: 'Enunciado $index',
            options: const ['A', 'B'],
            correctIndex: index == 3 ? null : 0,
          ),
      ],
    );
    final result = ExamResult(
      exam: exam,
      answers: {0: 0, 1: 1, 3: 1},
      markedForReview: const {},
      durationSeconds: 120,
      finishedAt: DateTime.utc(2026, 10, 31),
    );

    await tester.pumpWidget(MaterialApp(home: ResultPage(result: result)));
    expect(find.text('Abrir revisão das questões'), findsOneWidget);
    expect(find.text('Enunciado 0'), findsNothing);

    await tester.ensureVisible(find.text('Abrir revisão das questões'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir revisão das questões'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewPage), findsOneWidget);
    expect(find.text('Enunciado 0'), findsOneWidget);
    expect(find.text('Enunciado 99'), findsNothing);

    await tester.tap(find.text('Erradas'));
    await tester.pumpAndSettle();
    expect(find.text('Questão 2 · Errada'), findsOneWidget);
    expect(find.text('Enunciado 0'), findsNothing);

    await tester.tap(find.text('Sem gabarito'));
    await tester.pumpAndSettle();
    expect(find.text('Questão 4 · Sem gabarito'), findsOneWidget);
    expect(find.text('Exibidas: 1'), findsOneWidget);
  });

  testWidgets('retry opens a new attempt with only the wrong questions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final exam = Exam(
      id: 'exam-retry',
      title: 'Prova curta',
      category: 'Geral',
      description: '',
      author: 'Fonte',
      durationMinutes: 30,
      attempts: 0,
      questions: const [
        Question(
          id: 'q0',
          topic: 'Geral',
          statement: 'Questão certa',
          options: ['A', 'B'],
          correctIndex: 0,
        ),
        Question(
          id: 'q1',
          topic: 'Geral',
          statement: 'Questão errada um',
          options: ['A', 'B'],
          correctIndex: 0,
        ),
        Question(
          id: 'q2',
          topic: 'Geral',
          statement: 'Questão errada dois',
          options: ['A', 'B'],
          correctIndex: 0,
        ),
        Question(
          id: 'q3',
          topic: 'Geral',
          statement: 'Questão em branco',
          options: ['A', 'B'],
          correctIndex: 0,
        ),
      ],
    );
    final result = ExamResult(
      exam: exam,
      answers: {0: 0, 1: 1, 2: 1},
      markedForReview: const {},
      durationSeconds: 90,
      finishedAt: DateTime.utc(2026, 10, 31),
    );

    await tester.pumpWidget(MaterialApp(home: ResultPage(result: result)));
    const retryLabel = 'Refazer 2 questões erradas';
    expect(find.text(retryLabel), findsOneWidget);

    await tester.ensureVisible(find.text(retryLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(retryLabel));
    await tester.pumpAndSettle();

    expect(find.byType(QuizPage), findsOneWidget);
    expect(find.text('Questão 1 de 2'), findsOneWidget);
    expect(find.text('Questão errada um'), findsOneWidget);
    expect(find.text('Questão certa'), findsNothing);
    expect(find.text('Questão em branco'), findsNothing);
  });
}
