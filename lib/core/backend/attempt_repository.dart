import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/exam.dart';
import 'attempt_submission.dart';

class AttemptRepository implements AttemptSubmitter {
  AttemptRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  @override
  Future<ExamResult> submit(AttemptSubmission submission) async {
    final exam = submission.exam;
    if (exam.isLocal)
      throw StateError('Provas locais não podem ser enviadas ao servidor.');
    final payload = <String, int>{};
    for (var index = 0; index < exam.questions.length; index++) {
      final questionId = exam.questions[index].id;
      final selected = submission.answers[index];
      if (questionId.isNotEmpty && selected != null)
        payload[questionId] = selected;
    }
    try {
      final response = await _client
          .rpc<Map<String, dynamic>>(
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
          )
          .timeout(const Duration(seconds: 15));
      final rawReview = List<Map<String, dynamic>>.from(
        response['review'] as List<dynamic>? ?? const [],
      );
      final positions = <String, int>{
        for (var index = 0; index < exam.questions.length; index++)
          exam.questions[index].id: index,
      };
      final seen = <String>{};
      var correctCount = 0;
      const invalidReview = AttemptSubmissionException(
        message:
            'A correção recebida não corresponde à entrega salva. '
            'Suas respostas foram preservadas no aparelho.',
        transient: false,
      );
      if (rawReview.length != exam.questions.length ||
          positions.length != exam.questions.length ||
          exam.questions.isEmpty) {
        throw invalidReview;
      }
      for (final item in rawReview) {
        final id = item['question_id'];
        final index = positions[id];
        if (id is! String || index == null || !seen.add(id)) {
          throw invalidReview;
        }
        final optionCount = exam.questions[index].options.length;
        final correct = item['correct_index'];
        final selected = item['selected_index'];
        if (correct is! int ||
            correct < 0 ||
            correct >= optionCount ||
            (selected != null &&
                (selected is! int ||
                    selected < 0 ||
                    selected >= optionCount)) ||
            selected != submission.answers[index] ||
            item['marked_for_review'] !=
                submission.markedForReview.contains(index)) {
          throw invalidReview;
        }
        if (selected == correct) correctCount++;
      }
      if (response['total'] != exam.questions.length ||
          response['correct'] != correctCount) {
        throw invalidReview;
      }
      final keys = <String, int>{
        for (final item in rawReview)
          item['question_id'] as String: item['correct_index'] as int,
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
      throw AttemptSubmissionException(
        message: error.message,
        transient: false,
        cause: error,
      );
    } on PostgrestException catch (error) {
      final code = error.code ?? '';
      final transient =
          code.startsWith('08') ||
          code.startsWith('40') ||
          code.startsWith('53') ||
          code.startsWith('57') ||
          code.startsWith('58') ||
          code == 'PGRST000' ||
          code == 'PGRST001' ||
          code == 'PGRST002' ||
          code == 'PGRST003' ||
          code == 'PGRST202';
      throw AttemptSubmissionException(
        message: code == 'PGRST202'
            ? 'O serviço de correção precisa ser atualizado. '
                  'Sua entrega continua salva no aparelho.'
            : error.message,
        transient: transient,
        cause: error,
      );
    } on TimeoutException catch (error) {
      throw AttemptSubmissionException(
        message: 'Tempo limite ao enviar a entrega.',
        transient: true,
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw AttemptSubmissionException(
        message: 'Sem conexão com o servidor.',
        transient: true,
        cause: error,
      );
    } catch (error) {
      throw AttemptSubmissionException(
        message: 'Falha desconhecida ao enviar a entrega.',
        transient: false,
        cause: error,
      );
    }
  }
}
