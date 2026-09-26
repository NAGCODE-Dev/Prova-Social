import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prova_social/core/backend/attempt_repository.dart';
import 'package:prova_social/core/backend/attempt_submission.dart';
import 'package:prova_social/domain/models/exam.dart';

void main() {
  const validReview = {
    'question_id': 'q1',
    'correct_index': 1,
    'selected_index': 1,
    'marked_for_review': false,
  };
  final cases = <String, Map<String, dynamic>>{
    'gabarito fora das alternativas': {
      'review': [
        {...validReview, 'correct_index': 9},
      ],
    },
    'resposta fora das alternativas': {
      'review': [
        {...validReview, 'selected_index': 9},
      ],
    },
    'resposta diferente da entrega': {
      'review': [
        {...validReview, 'selected_index': 0},
      ],
    },
    'marcação diferente da entrega': {
      'review': [
        {...validReview, 'marked_for_review': true},
      ],
    },
    'questão desconhecida': {
      'review': [
        {...validReview, 'question_id': 'other'},
      ],
    },
    'questão duplicada': {
      'review': [validReview, validReview],
    },
    'questão ausente': {'review': <dynamic>[]},
    'contagem divergente': {
      'review': [validReview],
      'correct': 0,
    },
  };
  for (final entry in cases.entries) {
    test('recusa ${entry.key} sem inventar resultado', () async {
      final client = SupabaseClient(
        'https://example.test',
        'public-key',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'total': 1, 'correct': 1, ...entry.value}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        AttemptRepository(client: client).submit(testSubmission()),
        throwsA(
          isA<AttemptSubmissionException>().having(
            (error) => error.transient,
            'não transformar uma correção inválida em resultado',
            false,
          ),
        ),
      );
    });
  }
  test('aceita correção completa correspondente à entrega', () async {
    final client = SupabaseClient(
      'https://example.test',
      'public-key',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'total': 1,
            'correct': 1,
            'review': [validReview],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.dispose);
    final result = await AttemptRepository(client: client)
        .submit(testSubmission());
    expect(result.correct, 1);
    expect(result.answers, {0: 1});
    expect(result.markedForReview, isEmpty);
  });

  for (final code in ['PGRST202', '22023', '42501']) {
    test('classifica $code preservando a chamada idempotente', () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.test',
        'public-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({'code': code, 'message': 'RPC recusada'}),
            400,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      const exam = Exam(
        id: 'exam',
        category: 'Geral',
        title: 'Prova',
        description: '',
        author: 'Fonte',
        durationMinutes: 30,
        attempts: 0,
        questions: [
          Question(
            id: 'q1',
            topic: 'Geral',
            statement: 'Q?',
            options: ['A', 'B'],
          ),
        ],
      );
      await expectLater(
        AttemptRepository(client: client).submit(
          AttemptSubmission(
            clientAttemptId: '11111111-1111-4111-8111-111111111111',
            exam: exam,
            answers: const {0: 1},
            markedForReview: const {},
            durationSeconds: 10,
            finishedAt: DateTime.utc(2026, 9, 26),
          ),
        ),
        throwsA(
          isA<AttemptSubmissionException>().having(
            (error) => error.transient,
            'pode tentar novamente após atualização do serviço',
            code == 'PGRST202',
          ),
        ),
      );
      expect(requests, hasLength(1));
      expect(
        (jsonDecode(requests.single.body) as Map)['p_client_attempt_id'],
        '11111111-1111-4111-8111-111111111111',
      );
    });
  }
}

AttemptSubmission testSubmission() => AttemptSubmission(
  clientAttemptId: '11111111-1111-4111-8111-111111111111',
  exam: const Exam(
    id: 'exam',
    category: 'Geral',
    title: 'Prova',
    description: '',
    author: 'Fonte',
    durationMinutes: 30,
    attempts: 0,
    questions: [
      Question(id: 'q1', topic: 'Geral', statement: 'Q?', options: ['A', 'B']),
    ],
  ),
  answers: const {0: 1},
  markedForReview: const {},
  durationSeconds: 10,
  finishedAt: DateTime.utc(2026, 9, 26),
);
