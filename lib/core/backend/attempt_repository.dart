import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/exam.dart';

class AttemptRepository {
  AttemptRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<ExamResult> submit({
    required Exam exam,
    required Map<int, int> answers,
    required Set<int> markedForReview,
    required int durationSeconds,
    required DateTime finishedAt,
  }) async {
    final payload = <String, int>{};
    for (var index = 0; index < exam.questions.length; index++) {
      final questionId = exam.questions[index].id;
      final selected = answers[index];
      if (questionId.isNotEmpty && selected != null) {
        payload[questionId] = selected;
      }
    }
    final response = await _client.rpc<Map<String, dynamic>>(
      'submit_exam_attempt',
      params: {
        'p_exam_id': exam.id,
        'p_answers': payload,
        'p_review_question_ids': markedForReview
            .where((index) => index >= 0 && index < exam.questions.length)
            .map((index) => exam.questions[index].id)
            .where((id) => id.isNotEmpty)
            .toList(),
        'p_duration_seconds': durationSeconds,
      },
    );
    final rawReview = List<Map<String, dynamic>>.from(
      response['review'] as List<dynamic>? ?? const [],
    );
    final keys = <String, int>{
      for (final item in rawReview)
        item['question_id'] as String: item['correct_index'] as int,
    };
    final correctedQuestions = exam.questions
        .map((question) => question.copyWith(correctIndex: keys[question.id]))
        .toList(growable: false);
    if (correctedQuestions.any((question) => question.correctIndex == null)) {
      throw StateError('O servidor não devolveu o gabarito completo da prova.');
    }
    return ExamResult(
      exam: exam.copyWith(questions: correctedQuestions),
      answers: Map.of(answers),
      markedForReview: Set.of(markedForReview),
      durationSeconds: durationSeconds,
      finishedAt: finishedAt,
    );
  }
}
