import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/backend/exam_repository.dart';
import 'package:prova_social/domain/models/exam.dart';

void main() {
  final row = <String, dynamic>{
    'id': 'exam-1',
    'category': 'Matemática',
    'title': 'Prova real',
    'description': 'Descrição',
    'source_name': 'Instituição',
    'duration_minutes': 90,
    'attempts_count': 2,
  };
  final questions = <Map<String, dynamic>>[
    {
      'id': 'question-1',
      'topic': 'Álgebra',
      'statement': 'Quanto é 1 + 1?',
      'options': [
        {'text': '1'},
        {'text': '2'},
      ],
    },
  ];

  test('mapeia os três tipos e preserva URL HTTPS', () {
    for (final type in ExamSourceType.values) {
      final exam = ExamRepository.mapPublishedExam({
        ...row,
        'source_type': type.name,
        'source_url': 'https://example.org/prova',
      }, questions);
      expect(exam.sourceType, type);
      expect(exam.safeSourceUrl, Uri.parse('https://example.org/prova'));
      expect(exam.copyWith(questions: exam.questions).sourceType, type);
      expect(exam.questions.single.options, ['1', '2']);
    }
  });

  test('dados antigos, nulos e desconhecidos ficam não verificados', () {
    for (final value in [null, 'desconhecido', 42]) {
      final exam = ExamRepository.mapPublishedExam({
        ...row,
        'source_type': value,
        'source_url': null,
      }, questions);
      expect(exam.sourceType, ExamSourceType.unverified);
      expect(exam.safeSourceUrl, isNull);
    }
    final oldExam = ExamRepository.mapPublishedExam(row, questions);
    expect(oldExam.sourceType, ExamSourceType.unverified);
    expect(oldExam.sourceUrl, isNull);
    final missingSource = ExamRepository.mapPublishedExam({
      ...row,
      'source_name': null,
    }, questions);
    expect(missingSource.author, 'Fonte não informada');
  });

  test('bloqueia URLs que não são HTTPS válidas', () {
    for (final url in [
      'http://example.org',
      'javascript:alert(1)',
      '/prova',
      'https:',
    ]) {
      final exam = ExamRepository.mapPublishedExam({
        ...row,
        'source_url': url,
      }, questions);
      expect(exam.safeSourceUrl, isNull);
    }
  });
}
