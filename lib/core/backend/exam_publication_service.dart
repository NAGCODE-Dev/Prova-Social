import 'package:supabase_flutter/supabase_flutter.dart';

import '../import/question_parser.dart';

class ExamPublicationService {
  ExamPublicationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> publish({
    required String title,
    required String category,
    required String source,
    required int durationMinutes,
    required List<ImportedQuestion> questions,
    int? year,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Entre na conta para publicar.');
    }

    if (questions.isEmpty ||
        questions.any((question) =>
            question.statement.trim().length < 2 ||
            question.options.length < 2 ||
            question.correctIndex == null ||
            question.correctIndex! < 0 ||
            question.correctIndex! >= question.options.length)) {
      throw const FormatException('Revise todas as questões e o gabarito.');
    }
    final examId = await _client.rpc<String>(
      'publish_exam',
      params: {
        'p_title': title.trim(),
        'p_category': category.trim(),
        'p_source': source.trim(),
        'p_source_type': 'community',
        'p_year': year,
        'p_duration_minutes': durationMinutes,
        'p_questions': questions
            .map((question) => {
                  'topic': 'Geral',
                  'statement': question.statement.trim(),
                  'options': question.options
                      .map((text) => text.trim())
                      .toList(growable: false),
                  'correct_index': question.correctIndex,
                })
            .toList(growable: false),
      },
    );
    return examId;
  }
}
