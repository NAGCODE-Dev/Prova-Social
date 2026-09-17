import 'package:supabase_flutter/supabase_flutter.dart';

import '../import/question_parser.dart';
import 'digital_exam_service.dart';

class ExamPublicationService {
  ExamPublicationService({SupabaseClient? client, DigitalExamService? digital})
      : _client = client ?? Supabase.instance.client,
        _digital = digital ?? DigitalExamService();

  final SupabaseClient _client;
  final DigitalExamService _digital;

  Future<String> publish({
    required String title,
    required String source,
    required int durationMinutes,
    required List<ImportedQuestion> questions,
    int? year,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Entre na conta para publicar.');
    }

    final exam = await _client
        .from('exams')
        .insert({
          'author_id': user.id,
          'title': title,
          'description': 'Prova importada e revisada pela comunidade.',
          'category': 'Concursos',
          'source_name': source,
          'source_type': 'community',
          'year': year,
          'duration_minutes': durationMinutes,
          'status': 'draft',
          'is_public': false,
        })
        .select('id')
        .single();
    final examId = exam['id'] as String;

    final rows = List.generate(questions.length, (index) {
      final question = questions[index];
      return {
        'exam_id': examId,
        'position': index + 1,
        'statement': question.statement.trim(),
        'options': question.options.map((text) => text.trim()).toList(),
        'correct_index': question.correctIndex,
      };
    });
    await _client.from('questions').insert(rows);

    await _digital.upload(
      examId: examId,
      manifest: {
        'title': title,
        'source': source,
        'year': year,
        'durationMinutes': durationMinutes,
        'questionCount': questions.length,
      },
      questions: List.generate(
        questions.length,
        (index) => questions[index].toJson(index + 1),
      ),
    );

    await _client.from('exams').update({
      'status': 'published',
      'is_public': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', examId);
    return examId;
  }
}
