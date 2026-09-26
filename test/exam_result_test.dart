import 'package:flutter_test/flutter_test.dart';
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
  });
}
