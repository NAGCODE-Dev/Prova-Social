import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/exam.dart';

class AttemptRepository {
  AttemptRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> saveCompleted(ExamResult result) async {
    final user = _client.auth.currentUser;
    if (user == null || result.exam.id.startsWith('sample-')) return;
    final attempt = await _client.from('attempts').insert({
      'user_id': user.id,
      'exam_id': result.exam.id,
      'duration_seconds': result.durationSeconds,
      'correct_count': result.correct,
      'total_count': result.exam.questions.length,
      'score_percent': result.scorePercent,
      'completed_at': result.finishedAt.toUtc().toIso8601String(),
    }).select('id').single();
    final attemptId = attempt['id'] as String;
    final rows = <Map<String, Object?>>[];
    for (var index = 0; index < result.exam.questions.length; index++) {
      final question = result.exam.questions[index];
      if (question.id.isEmpty) continue;
      rows.add({
        'attempt_id': attemptId,
        'question_id': question.id,
        'selected_index': result.answers[index],
        'is_correct': result.answers[index] == question.correctIndex,
        'marked_for_review': result.markedForReview.contains(index),
      });
    }
    if (rows.isNotEmpty) await _client.from('attempt_answers').insert(rows);
  }
}
