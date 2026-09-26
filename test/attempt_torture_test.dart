import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/backend/attempt_draft_store.dart';
import 'package:prova_social/core/backend/attempt_submission.dart';
import 'package:prova_social/core/backend/attempt_sync_service.dart';
import 'package:prova_social/domain/models/exam.dart';

import 'attempt_sync_service_test.dart' as fixture;
import 'quiz_offline_submission_test.dart' as widget_fixture;

// Simulates process termination by keeping only durable bytes and discarding
// service/store instances. No production hooks and no real network are used.
class BoundaryStorage implements AttemptQueueStorage {
  String? value;
  String? crashImage;
  bool rejectCompletion = false;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    final json = jsonDecode(value) as Map;
    if (rejectCompletion && (json['completed'] as Map).isNotEmpty) {
      crashImage = this.value;
      throw StateError('QA: crash after remote success, before local commit');
    }
    this.value = value;
  }
}

class AcceptedThenLost implements AttemptSubmitter {
  final accepted = <String, ExamResult>{};
  final payloads = <AttemptSubmission>[];
  bool loseFirstReply = true;

  @override
  Future<ExamResult> submit(AttemptSubmission value) async {
    payloads.add(value);
    final result = accepted.putIfAbsent(
      value.clientAttemptId,
      () => ExamResult(
        exam: value.exam,
        answers: value.answers,
        markedForReview: value.markedForReview,
        durationSeconds: value.durationSeconds,
        finishedAt: value.finishedAt,
      ),
    );
    if (loseFirstReply) {
      loseFirstReply = false;
      throw const AttemptSubmissionException(
        message: 'QA: accepted, response lost',
        transient: true,
      );
    }
    return result;
  }
}

void expectFrozen(AttemptSubmission actual, AttemptSubmission original) {
  expect(actual.clientAttemptId, original.clientAttemptId);
  expect(actual.answers, original.answers);
  expect(actual.markedForReview, original.markedForReview);
  expect(actual.durationSeconds, original.durationSeconds);
  expect(actual.finishedAt, original.finishedAt);
  expect(actual.exam.id, original.exam.id);
  expect(actual.exam.title, original.exam.title);
  expect(actual.exam.questions.single.id, original.exam.questions.single.id);
  expect(
    actual.exam.questions.single.statement,
    original.exam.questions.single.statement,
  );
  expect(
    actual.exam.questions.single.options,
    original.exam.questions.single.options,
  );
}

void main() {
  test('resultado local rejeita mesmo ID com respostas conflitantes', () async {
    final store = AttemptQueueStore(storage: fixture.MemoryQueueStorage());
    final publicExam = fixture.exam;
    final local = Exam(
      id: publicExam.id,
      isLocal: true,
      category: publicExam.category,
      title: publicExam.title,
      description: publicExam.description,
      author: publicExam.author,
      durationMinutes: publicExam.durationMinutes,
      attempts: 0,
      questions: publicExam.questions,
    );
    ExamResult result(int answer) => ExamResult(
      exam: local,
      answers: {0: answer},
      markedForReview: const {},
      durationSeconds: 10,
      finishedAt: DateTime.utc(2026, 9, 26),
    );
    await store.completeLocal('qa-same-local-id', result(1));
    await expectLater(
      store.completeLocal('qa-same-local-id', result(0)),
      throwsStateError,
    );
    expect((await store.completed()).values.single.answers, {0: 1});
  });

  test('mesmo ID com snapshot diferente exige conflito explícito', () async {
    final store = AttemptQueueStore(storage: fixture.MemoryQueueStorage());
    final original = fixture.submission();
    await store.enqueue(original);
    final changed = AttemptSubmission(
      clientAttemptId: original.clientAttemptId,
      exam: original.exam.copyWith(
        questions: const [
          Question(
            id: 'q2',
            topic: 'Geral',
            statement: 'B?',
            options: ['C', 'D'],
          ),
        ],
      ),
      answers: original.answers,
      markedForReview: original.markedForReview,
      durationSeconds: original.durationSeconds,
      finishedAt: original.finishedAt,
    );
    await expectLater(store.enqueue(changed), throwsStateError);
    expectFrozen((await store.pending()).single.submission, original);
  });

  test('resposta perdida, mutação local e retry preservam payload', () async {
    final storage = fixture.MemoryQueueStorage();
    final submitter = AcceptedThenLost();
    final answers = <int, int>{0: 1};
    final options = <String>['A', 'B'];
    final original = fixture.submission();
    final value = AttemptSubmission(
      clientAttemptId: original.clientAttemptId,
      exam: original.exam.copyWith(
        questions: [
          Question(id: 'q1', topic: 'Geral', statement: 'Q?', options: options),
        ],
      ),
      answers: answers,
      markedForReview: <int>{},
      durationSeconds: original.durationSeconds,
      finishedAt: original.finishedAt,
    );
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: submitter,
    );
    await service.saveForSync(value);
    final failed = await service.sync(value.clientAttemptId);
    expect(failed.result, isNull);
    expect(failed.attempt.state, AttemptSyncState.waitingConnection);
    answers[0] = 0;
    options[1] = 'catalog B';
    await service.store.saveStartedExam(value.exam);
    final restarted = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: submitter,
    );
    final outcome = await restarted.sync(
      value.clientAttemptId,
      ignoreSchedule: true,
    );
    expect(outcome.result!.answers, {0: 1});
    expect(submitter.payloads, hasLength(2));
    for (final sent in submitter.payloads) {
      expectFrozen(sent, original);
    }
    expect(submitter.accepted.keys, [original.clientAttemptId]);
    expect(await restarted.store.pending(), isEmpty);
    expect(
      (await restarted.store.completed()).keys,
      [original.clientAttemptId],
    );
  });

  test('morte após aceite remoto mantém fila', () async {
    final storage = BoundaryStorage();
    final submitter = AcceptedThenLost()..loseFirstReply = false;
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: submitter,
    );
    final value = fixture.submission();
    await service.saveForSync(value);
    storage.rejectCompletion = true;
    await expectLater(service.sync(value.clientAttemptId), throwsStateError);
    expect(submitter.accepted, hasLength(1));
    expect(await service.store.completed(), isEmpty);
    final crashed = BoundaryStorage()..value = storage.crashImage;
    final restarted = AttemptSyncService(
      store: AttemptQueueStore(storage: crashed),
      submitter: submitter,
    );
    final pending = (await restarted.store.pending()).single;
    expect(pending.state, AttemptSyncState.sending);
    expectFrozen(pending.submission, value);
    await restarted.syncDue();
    expect(await restarted.store.pending(), isEmpty);
    expect((await restarted.store.completed()).keys, [value.clientAttemptId]);
    expect(submitter.accepted, hasLength(1));
    expect(submitter.payloads, hasLength(2));
    expectFrozen(submitter.payloads.last, value);
  });

  for (final sending in [false, true]) {
    test('reinício com sending=$sending', () async {
      final storage = fixture.MemoryQueueStorage();
      final store = AttemptQueueStore(storage: storage);
      final value = fixture.submission();
      await store.enqueue(value);
      if (sending) {
        final pending = (await store.pending()).single;
        await store.update(pending.copyWith(state: AttemptSyncState.sending));
      }
      final submitter = fixture.FakeSubmitter();
      final restarted = AttemptSyncService(
        store: AttemptQueueStore(storage: storage),
        submitter: submitter,
      );
      await restarted.syncDue();
      expectFrozen(submitter.payloads.single, value);
      expect(await restarted.store.pending(), isEmpty);
      expect((await restarted.store.completed()).keys, [value.clientAttemptId]);
    });
  }

  test('dois enqueues rápidos e retry posterior não duplicam', () async {
    final storage = fixture.MemoryQueueStorage();
    final submitter = fixture.FakeSubmitter();
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: submitter,
    );
    final value = fixture.submission();
    await Future.wait([service.saveForSync(value), service.saveForSync(value)]);
    expect(await service.store.pending(), hasLength(1));
    await Future.wait([
      service.sync(value.clientAttemptId),
      service.sync(value.clientAttemptId),
    ]);
    await service.sync(value.clientAttemptId);
    expect(submitter.calls, 1);
    expect((await service.store.completed()).keys, [value.clientAttemptId]);
  });

  test('JSON inválido preserva fila e permite recuperação', () async {
    final storage = fixture.MemoryQueueStorage();
    final store = AttemptQueueStore(storage: storage);
    await store.enqueue(fixture.submission());
    final valid = storage.value;
    storage.value = '{QA invalid JSON';
    await expectLater(store.pending(), throwsFormatException);
    await expectLater(
      store.enqueue(fixture.submission()),
      throwsFormatException,
    );
    expect(storage.value, '{QA invalid JSON');
    // QA restores exact pre-corruption bytes; product does not repair JSON.
    storage.value = valid;
    expect(await store.pending(), hasLength(1));
  });

  test('item incompleto propaga erro sem apagar outros dados', () async {
    final storage = fixture.MemoryQueueStorage();
    final store = AttemptQueueStore(storage: storage);
    await store.enqueue(fixture.submission());
    final json = jsonDecode(storage.value!) as Map<String, dynamic>;
    (json['pending'] as List).add({'clientAttemptId': 'qa-incomplete'});
    storage.value = jsonEncode(json);
    final corrupt = storage.value;
    await expectLater(store.pending(), throwsA(isA<TypeError>()));
    expect(storage.value, corrupt);
    expect((jsonDecode(storage.value!) as Map)['pending'], hasLength(2));
  });

  test('campos opcionais ausentes preservam respostas', () async {
    final storage = fixture.MemoryQueueStorage();
    final store = AttemptQueueStore(storage: storage);
    await store.enqueue(fixture.submission());
    final json = jsonDecode(storage.value!) as Map<String, dynamic>;
    final pending = (json['pending'] as List).single as Map;
    const optional = ['review', 'attemptCount', 'lastError', 'nextAttemptAt'];
    for (final field in optional) {
      pending.remove(field);
    }
    storage.value = jsonEncode(json);
    final loaded = (await store.pending()).single;
    expect(loaded.submission.answers, {0: 1});
    expect(
      loaded.submission.clientAttemptId,
      fixture.submission().clientAttemptId,
    );
    expect(loaded.submission.markedForReview, isEmpty);
    expect(loaded.attemptCount, 0);
  });

  test('draft ausente/corrompido preserva draft de outra prova', () async {
    final storage = widget_fixture.MemoryDraftStorage();
    final store = AttemptDraftStore(storage: storage);
    addTearDown(store.dispose);
    expect(await store.load('missing'), isNull);
    await store.save(
      'other',
      const AttemptDraft(
        answers: {0: 1},
        review: {},
        current: 0,
        elapsedSeconds: 1,
      ),
    );
    storage.values['attempt_draft_v1_broken'] = '{invalid';
    await expectLater(store.load('broken'), throwsFormatException);
    expect((await store.load('other'))!.answers, {0: 1});
    expect(storage.values['attempt_draft_v1_broken'], '{invalid');
  });
}
