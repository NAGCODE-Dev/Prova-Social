import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/data/sample_exams.dart';
import 'package:prova_social/domain/models/exam.dart';

void main() {
  test('calcula pontuação e gera JSON', () {
    final exam = sampleExams.first;
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
