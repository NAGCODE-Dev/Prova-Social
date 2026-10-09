import 'dart:convert';

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
    String? sourceUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Entre na conta para publicar.');
    }

    final normalizedSourceUrl = normalizeSourceUrl(sourceUrl);
    if (title.trim().length < 3 ||
        title.trim().length > 180 ||
        category.trim().length < 2 ||
        category.trim().length > 80 ||
        source.trim().length < 2 ||
        source.trim().length > 160 ||
        durationMinutes < 1 ||
        durationMinutes > 1440 ||
        (year != null && (year < 1900 || year > 2200))) {
      throw const FormatException('Revise os dados e a origem da prova.');
    }
    if (questions.isEmpty ||
        questions.length > 300 ||
        questions.any(
          (question) =>
              question.statement.trim().length < 2 ||
              question.statement.trim().length > 20000 ||
              question.options.length < 2 ||
              question.options.length > 8 ||
              question.options.any(
                (option) =>
                    option.trim().isEmpty || option.trim().length > 4000,
              ) ||
              question.correctIndex == null ||
              question.correctIndex! < 0 ||
              question.correctIndex! >= question.options.length,
        )) {
      throw const FormatException('Revise todas as questões e o gabarito.');
    }
    final questionPayload = questions
        .map(
          (question) => {
            'topic': 'Geral',
            'statement': question.statement.trim(),
            'options': question.options
                .map((text) => text.trim())
                .toList(growable: false),
            'correct_index': question.correctIndex,
          },
        )
        .toList(growable: false);
    if (utf8.encode(jsonEncode(questionPayload)).length > 8 * 1024 * 1024) {
      throw const FormatException('O conteúdo excede o limite de 8 MB.');
    }
    final params = <String, dynamic>{
      'p_title': title.trim(),
      'p_category': category.trim(),
      'p_source': source.trim(),
      'p_source_type': 'community',
      'p_year': year,
      'p_duration_minutes': durationMinutes,
      'p_questions': questionPayload,
    };
    final examId = normalizedSourceUrl == null
        ? await _client.rpc<String>('publish_exam', params: params)
        : await _client.rpc<String>(
            'publish_exam_with_source_url',
            params: {...params, 'p_source_url': normalizedSourceUrl},
          );
    return examId;
  }

  static bool isValidSourceUrl(String? value) {
    try {
      normalizeSourceUrl(value);
      return true;
    } on FormatException {
      return false;
    }
  }

  static String? normalizeSourceUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    final uri = Uri.tryParse(normalized);
    if (normalized.length > 500 ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'O link da fonte precisa ser uma URL HTTPS válida.',
      );
    }
    return normalized;
  }
}
