import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:prova_social/features/quiz/quiz_page.dart';
import 'package:prova_social/features/result/result_page.dart';

void main() {
  testWidgets('a single mistake offers the singular retry label', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const exam = Exam(
      id: 'exam-singular',
      title: 'Prova curta',
      category: 'Geral',
      description: '',
      author: 'Fonte',
      durationMinutes: 30,
      attempts: 0,
      questions: [
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
          statement: 'Questão errada',
          options: ['A', 'B'],
          correctIndex: 0,
        ),
      ],
    );
    final result = ExamResult(
      exam: exam,
      answers: const {0: 0, 1: 1},
      markedForReview: const {},
      durationSeconds: 45,
      finishedAt: DateTime.utc(2026, 11, 1),
    );

    await tester.pumpWidget(MaterialApp(home: ResultPage(result: result)));
    expect(find.text('Refazer 1 questão errada'), findsOneWidget);
    expect(find.textContaining('Refazer 1 questões'), findsNothing);

    await tester.ensureVisible(find.text('Refazer 1 questão errada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refazer 1 questão errada'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizPage), findsOneWidget);
    expect(find.text('Questão 1 de 1'), findsOneWidget);
    expect(find.text('Questão errada'), findsOneWidget);
    expect(find.text('Questão certa'), findsNothing);
  });
}
