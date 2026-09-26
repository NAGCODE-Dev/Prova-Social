import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prova_social/core/backend/attempt_repository.dart';
import 'package:prova_social/core/backend/attempt_submission.dart';
import 'package:prova_social/core/backend/attempt_sync_service.dart';
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

  test('aceite remoto com resposta perdida repete o mesmo payload', () async {
    final requests = <Map<String, dynamic>>[];
    final accepted = <String, Map<String, dynamic>>{};
    final client = SupabaseClient(
      'https://example.test',
      'public-key',
      httpClient: MockClient((request) async {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(payload);
        final id = payload['p_client_attempt_id'] as String;
        final previous = accepted[id];
        if (previous == null) {
          accepted[id] = payload;
          // The simulated server commits, but its response never arrives.
          throw TimeoutException('resposta perdida após aceite');
        }
        expect(payload, previous);
        return http.Response(
          jsonEncode({
            'total': 1,
            'correct': 1,
            'review': [validReview],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final storage = _QueueStorage();
    final repository = AttemptRepository(client: client);
    final first = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: repository,
    );
    final value = testSubmission();
    await first.saveForSync(value);
    final failed = await first.sync(value.clientAttemptId);
    expect(failed.attempt.state, AttemptSyncState.waitingConnection);
    expect(failed.result, isNull);
    expect(await first.store.completed(), isEmpty);
    expect((await first.store.pending()).single.submission.answers, {0: 1});

    final restarted = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: repository,
    );
    final retry = await restarted.sync(
      value.clientAttemptId,
      ignoreSchedule: true,
    );
    expect(retry.result!.correct, 1);
    expect(requests, hasLength(2));
    expect(requests.first, requests.last);
    expect(accepted.keys, [value.clientAttemptId]);
    expect(await restarted.store.pending(), isEmpty);
    expect((await restarted.store.completed()).keys, [value.clientAttemptId]);
    final cached = await restarted.sync(value.clientAttemptId);
    expect(cached.result!.toJson(), retry.result!.toJson());
    expect(requests, hasLength(2));
  });

  for (final failure in ['PGRST202', 'timeout-before-accept']) {
    test('$failure seguido de retry usa mesma RPC e payload', () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.test',
        'public-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (requests.length == 1) {
            if (failure == 'timeout-before-accept') {
              throw TimeoutException('QA: servidor não aceitou ainda');
            }
            return http.Response(
              jsonEncode({'code': 'PGRST202', 'message': 'RPC unavailable'}),
              404,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'total': 1,
              'correct': 1,
              'review': [validReview],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final storage = _QueueStorage();
      final repository = AttemptRepository(client: client);
      final first = AttemptSyncService(
        store: AttemptQueueStore(storage: storage),
        submitter: repository,
      );
      final value = testSubmission();
      await first.saveForSync(value);
      final waiting = await first.sync(value.clientAttemptId);
      expect(waiting.attempt.state, AttemptSyncState.waitingConnection);
      expect(waiting.result, isNull);
      final restarted = AttemptSyncService(
        store: AttemptQueueStore(storage: storage),
        submitter: repository,
      );
      final retry = await restarted.sync(
        value.clientAttemptId,
        ignoreSchedule: true,
      );
      expect(retry.result!.correct, 1);
      expect(requests, hasLength(2));
      expect(requests.first.url.path, '/rest/v1/rpc/submit_exam_attempt');
      expect(requests.last.url, requests.first.url);
      expect(requests.last.body, requests.first.body);
      for (final request in requests) {
        expect(
          (jsonDecode(request.body) as Map)['p_client_attempt_id'],
          value.clientAttemptId,
        );
      }
      expect(await restarted.store.pending(), isEmpty);
      expect((await restarted.store.completed()).keys, [value.clientAttemptId]);
    });
  }

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

class _QueueStorage implements AttemptQueueStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}
