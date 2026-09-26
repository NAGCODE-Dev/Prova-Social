import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/features/result/result_page.dart';
import 'package:prova_social/domain/models/exam.dart';

void main() {
  test('calcula pontuação e gera JSON', () {
    const exam = Exam(
      id: 'exam-test',
      category: 'Matemática',
      title: 'Prova de teste',
      description: '',
      author: 'Teste',
      durationMinutes: 60,
      attempts: 0,
      questions: [
        Question(
          topic: 'Geral',
          statement: 'Q1',
          options: ['A', 'B'],
          correctIndex: 1,
        ),
        Question(
          topic: 'Geral',
          statement: 'Q2',
          options: ['A', 'B'],
          correctIndex: 0,
        ),
        Question(
          topic: 'Geral',
          statement: 'Q3',
          options: ['A', 'B', 'C'],
          correctIndex: 2,
        ),
        Question(
          topic: 'Geral',
          statement: 'Q4',
          options: ['A', 'B'],
          correctIndex: 0,
        ),
        Question(
          topic: 'Geral',
          statement: 'Q5',
          options: ['A', 'B', 'C'],
          correctIndex: 2,
        ),
      ],
    );
    final result = ExamResult(
      exam: exam,
      answers: {0: 1, 1: 0, 2: 2, 3: 1, 4: 2},
      markedForReview: {1},
      durationSeconds: 90,
      finishedAt: DateTime.utc(2026, 9, 16),
    );

    expect(result.correct, 4);
    expect(result.scorePercent, 80);
    expect(result.toJson()['total'], 5);
    expect(result.wrongQuestionIndices, [3]);
    expect(result.unanswered, 0);
    expect(result.byTopic['Geral'], (correct: 4, total: 5));
  });

  testWidgets('revisão distingue errada, em branco e sem gabarito', (
    tester,
  ) async {
    const exam = Exam(
      id: 'mixed-result',
      category: 'Geral',
      title: 'Revisão de teste',
      description: '',
      author: 'Instituição de teste',
      sourceType: ExamSourceType.official,
      sourceUrl: 'https://example.test/prova',
      durationMinutes: 30,
      attempts: 0,
      questions: [
        Question(
          id: 'q1',
          topic: 'Álgebra',
          statement: 'Questão acertada',
          options: ['Um', 'Dois'],
          correctIndex: 1,
        ),
        Question(
          id: 'q2',
          topic: 'Álgebra',
          statement: 'Questão errada',
          options: ['Três', 'Quatro'],
          correctIndex: 1,
        ),
        Question(
          id: 'q3',
          topic: 'Geometria',
          statement: 'Questão em branco',
          options: ['Cinco', 'Seis'],
          correctIndex: 0,
        ),
        Question(
          id: 'q4',
          topic: 'Sem correção',
          statement: 'Questão sem gabarito',
          options: ['Sete', 'Oito'],
        ),
      ],
    );
    final result = ExamResult(
      exam: exam,
      answers: {0: 1, 1: 0, 3: 1},
      markedForReview: {1, 3},
      durationSeconds: 95,
      finishedAt: DateTime.utc(2026, 9, 26),
    );
    expect(result.correct, 1);
    expect(result.scorePercent, 25);
    expect(result.wrongQuestionIndices, [1]);
    expect(result.unanswered, 1);
    expect(result.byTopic, {
      'Álgebra': (correct: 1, total: 2),
      'Geometria': (correct: 0, total: 1),
    });
    final exported = result.toJson();
    expect(exported['total'], 4);
    expect(exported['durationSeconds'], 95);
    final answers = exported['answers'] as List;
    expect(answers[1]['selected'], 0);
    expect(answers[1]['markedForReview'], isTrue);
    expect(answers[2]['selected'], isNull);
    expect(answers[3]['correct'], isNull);
    await tester.pumpWidget(MaterialApp(home: ResultPage(result: result)));
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('1 de 4 acertos'), findsOneWidget);
    expect(find.text('01:35'), findsOneWidget);
    expect(find.text('Erradas: 1'), findsOneWidget);
    expect(find.text('Em branco: 1'), findsOneWidget);
    expect(find.text('Marcadas: 2'), findsOneWidget);
    expect(find.text('Fonte oficial'), findsOneWidget);
    expect(find.text('Instituição de teste'), findsOneWidget);
    expect(find.text('Abrir fonte'), findsOneWidget);
    expect(find.text('Álgebra: 1/2 acertos'), findsOneWidget);
    expect(find.text('Geometria: 0/1 acertos'), findsOneWidget);
    final wrongCard = find.ancestor(
      of: find.text('Questão errada'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: wrongCard, matching: find.text('Sua resposta: Três')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: wrongCard, matching: find.text('Gabarito: Quatro')),
      findsOneWidget,
    );
    expect(find.text('Sua resposta: Em branco'), findsOneWidget);
    final unknownCard = find.ancestor(
      of: find.text('Questão sem gabarito'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: unknownCard, matching: find.text('Sua resposta: Oito')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: unknownCard,
        matching: find.text('Gabarito indisponível'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: unknownCard, matching: find.text('Gabarito: Oito')),
      findsNothing,
    );
    expect(find.text('Marcada para revisão'), findsNWidgets(2));
    await tester.ensureVisible(find.text('Questão sem gabarito'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('questão em branco sem gabarito não é exportada como correta', () {
    const exam = Exam(
      id: 'sem-gabarito',
      category: 'Geral',
      title: 'Prova',
      description: '',
      author: 'Fonte',
      durationMinutes: 30,
      attempts: 0,
      questions: [
        Question(topic: 'Geral', statement: 'Q?', options: ['A', 'B']),
      ],
    );
    final result = ExamResult(
      exam: exam,
      answers: {},
      markedForReview: {},
      durationSeconds: 0,
      finishedAt: DateTime.utc(2026, 9, 26),
    );
    expect(result.correct, 0);
    expect(result.unanswered, 1);
    expect(result.wrongQuestionIndices, isEmpty);
    expect((result.toJson()['answers'] as List).single['isCorrect'], isFalse);
    final empty = ExamResult(
      exam: exam.copyWith(questions: []),
      answers: {},
      markedForReview: {},
      durationSeconds: 0,
      finishedAt: result.finishedAt,
    );
    expect(empty.scorePercent, 0);
    expect(empty.correct, 0);
    expect(empty.unanswered, 0);
    expect(empty.wrongQuestionIndices, isEmpty);
    expect(empty.byTopic, isEmpty);
    expect(empty.toJson()['answers'], isEmpty);
  });
}
