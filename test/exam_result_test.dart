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
        Question(topic: 'Geral', statement: 'Q1', options: ['A', 'B'], correctIndex: 1),
        Question(topic: 'Geral', statement: 'Q2', options: ['A', 'B'], correctIndex: 0),
        Question(topic: 'Geral', statement: 'Q3', options: ['A', 'B', 'C'], correctIndex: 2),
        Question(topic: 'Geral', statement: 'Q4', options: ['A', 'B'], correctIndex: 0),
        Question(topic: 'Geral', statement: 'Q5', options: ['A', 'B', 'C'], correctIndex: 2),
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
  });
}
