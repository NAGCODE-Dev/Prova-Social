import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/exam.dart';
import 'attempt_submission.dart';

class AttemptRepository implements AttemptSubmitter {
  AttemptRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  @override
  Future<ExamResult> submit(AttemptSubmission submission) async {
    final exam = submission.exam;
    final payload = <String, int>{};
    for (var index = 0; index < exam.questions.length; index++) {
      final questionId = exam.questions[index].id;
      final selected = submission.answers[index];
      if (questionId.isNotEmpty && selected != null) payload[questionId] = selected;
    }
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'submit_exam_attempt',
        params: {
          'p_exam_id': exam.id,
          'p_answers': payload,
          'p_review_question_ids': submission.markedForReview
              .where((index) => index >= 0 && index < exam.questions.length)
              .map((index) => exam.questions[index].id)
              .where((id) => id.isNotEmpty)
              .toList(),
          'p_duration_seconds': submission.durationSeconds,
          'p_client_attempt_id': submission.clientAttemptId,
        },
      ).timeout(const Duration(seconds: 15));
      final rawReview = List<Map<String, dynamic>>.from(response['review'] as List<dynamic>? ?? const []);
      final keys = <String, int>{
        for (final item in rawReview) item['question_id'] as String: item['correct_index'] as int,
      };
      final selectedById = <String, int>{
        for (final item in rawReview)
          if (item['selected_index'] case final int selected)
            item['question_id'] as String: selected,
      };
      final reviewIds = <String>{
        for (final item in rawReview)
          if (item['marked_for_review'] == true) item['question_id'] as String,
      };
      if (exam.questions.any((question) => !keys.containsKey(question.id))) {
        throw const AttemptSubmissionException(
          message: 'O servidor não devolveu o gabarito completo da prova.',
          transient: false,
        );
      }
      final correctedQuestions = exam.questions
          .map((question) => question.copyWith(correctIndex: keys[question.id]))
          .toList(growable: false);
      return ExamResult(
        exam: exam.copyWith(questions: correctedQuestions),
        answers: {
          for (var index = 0; index < exam.questions.length; index++)
            if (selectedById[exam.questions[index].id] case final selected?)
              index: selected,
        },
        markedForReview: {
          for (var index = 0; index < exam.questions.length; index++)
            if (reviewIds.contains(exam.questions[index].id)) index,
        },
        durationSeconds: submission.durationSeconds,
        finishedAt: submission.finishedAt,
      );
    } on AttemptSubmissionException {
      rethrow;
    } on AuthException catch (error) {
      throw AttemptSubmissionException(message: error.message, transient: false, cause: error);
    } on PostgrestException catch (error) {
      final code = error.code ?? '';
      final transient = code.startsWith('08') ||
          code.startsWith('40') ||
          code.startsWith('53') ||
          code.startsWith('57') ||
          code.startsWith('58') ||
          code == 'PGRST000' ||
          code == 'PGRST001' ||
          code == 'PGRST002' ||
          code == 'PGRST003';
      throw AttemptSubmissionException(
        message: error.message,
        transient: transient,
        cause: error,
      );
    } on TimeoutException catch (error) {
      throw AttemptSubmissionException(message: 'Tempo limite ao enviar a entrega.', transient: true, cause: error);
    } on http.ClientException catch (error) {
      throw AttemptSubmissionException(message: 'Sem conexão com o servidor.', transient: true, cause: error);
    } catch (error) {
      throw AttemptSubmissionException(
        message: 'Falha desconhecida ao enviar a entrega.',
        transient: false,
        cause: error,
      );
    }
  }
}
