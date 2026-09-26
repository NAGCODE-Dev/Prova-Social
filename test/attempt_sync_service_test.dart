import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/backend/attempt_submission.dart';
import 'package:prova_social/core/backend/attempt_sync_service.dart';
import 'package:prova_social/domain/models/exam.dart';

class MemoryQueueStorage implements AttemptQueueStorage {
  String? value;
  bool failWrites = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('armazenamento indisponível');
    this.value = value;
  }
}

class FakeSubmitter implements AttemptSubmitter {
  FakeSubmitter({this.error});
  AttemptSubmissionException? error;
  int calls = 0;
  final ids = <String>[];

  @override
  Future<ExamResult> submit(AttemptSubmission submission) async {
    calls++;
    ids.add(submission.clientAttemptId);
    if (error case final failure?) throw failure;
    return ExamResult(
      exam: submission.exam.copyWith(
        questions: submission.exam.questions
            .map((question) => question.copyWith(correctIndex: 1))
            .toList(),
      ),
      answers: submission.answers,
      markedForReview: submission.markedForReview,
      durationSeconds: submission.durationSeconds,
      finishedAt: submission.finishedAt,
    );
  }
}

class ControlledSubmitter implements AttemptSubmitter {
  final gate = Completer<ExamResult>();
  int calls = 0;

  @override
  Future<ExamResult> submit(AttemptSubmission submission) {
    calls++;
    return gate.future;
  }
}

const exam = Exam(
  id: 'exam-1',
  category: 'Geral',
  title: 'Prova',
  description: '',
  author: 'Fonte',
  durationMinutes: 30,
  attempts: 0,
  questions: [
    Question(id: 'q1', topic: 'Geral', statement: 'Q?', options: ['A', 'B']),
  ],
);

AttemptSubmission submission([
  String id = '11111111-1111-4111-8111-111111111111',
]) => AttemptSubmission(
  clientAttemptId: id,
  exam: exam,
  answers: const {0: 1},
  markedForReview: const {},
  durationSeconds: 10,
  finishedAt: DateTime.utc(2026, 9, 21),
);

void main() {
  test(
    'entrega captura respostas antes de aguardar gravações anteriores',
    () async {
      final store = AttemptQueueStore(storage: MemoryQueueStorage());
      final answers = <int, int>{0: 1};
      final marked = <int>{0};
      final value = AttemptSubmission(
        clientAttemptId: submission().clientAttemptId,
        exam: exam,
        answers: answers,
        markedForReview: marked,
        durationSeconds: 10,
        finishedAt: DateTime.utc(2026, 9, 26),
      );
      final writing = store.enqueue(value);
      answers[0] = 0;
      marked.clear();
      await writing;
      final persisted = (await store.pending()).single.submission;
      expect(persisted.answers, {0: 1});
      expect(persisted.markedForReview, {0});
    },
  );

  test(
    'conteúdo iniciado sobrevive ao reinício sem acesso ao servidor',
    () async {
      final storage = MemoryQueueStorage();
      await AttemptQueueStore(storage: storage).saveStartedExam(exam);
      final restored = await AttemptQueueStore(storage: storage).startedExams();
      expect(restored.single.id, exam.id);
      expect(restored.single.questions.single.options, ['A', 'B']);
      expect(restored.single.questions.single.correctIndex, isNull);
      expect(restored.single.sourceType, exam.sourceType);
    },
  );

  test('entrega substitui conteúdo iniciado na mesma gravação', () async {
    final storage = MemoryQueueStorage();
    final store = AttemptQueueStore(storage: storage);
    await store.saveStartedExam(exam);
    storage.failWrites = true;
    await expectLater(store.enqueue(submission()), throwsStateError);
    expect((await store.startedExams()).single.id, exam.id);
    expect(await store.pending(), isEmpty);
    storage.failWrites = false;
    await store.enqueue(submission());
    final restarted = AttemptQueueStore(storage: storage);
    expect(await restarted.startedExams(), isEmpty);
    expect((await restarted.pending()).single.submission.exam.id, exam.id);
  });

  test(
    'resultado local persiste sem entrar na fila de sincronização',
    () async {
      final storage = MemoryQueueStorage();
      final store = AttemptQueueStore(storage: storage);
      final local = Exam(
        id: 'local',
        category: exam.category,
        title: exam.title,
        description: exam.description,
        author: exam.author,
        durationMinutes: exam.durationMinutes,
        attempts: 0,
        questions: [exam.questions.single.copyWith(correctIndex: 1)],
        isLocal: true,
      );
      final result = ExamResult(
        exam: local,
        answers: const {0: 1},
        markedForReview: const {0},
        durationSeconds: 15,
        finishedAt: DateTime.utc(2026, 9, 26),
      );
      await store.saveStartedExam(local);
      storage.failWrites = true;
      await expectLater(
        store.completeLocal('local-attempt', result),
        throwsStateError,
      );
      expect((await store.startedExams()).single.id, local.id);
      storage.failWrites = false;
      await store.completeLocal('local-attempt', result);
      final restarted = AttemptQueueStore(storage: storage);
      expect(await restarted.startedExams(), isEmpty);
      expect(await restarted.pending(), isEmpty);
      final completed = (await restarted.completed())['local-attempt']!;
      expect(completed.correct, 1);
      expect(completed.markedForReview, {0});
      expect(completed.durationSeconds, 15);
      expect(completed.exam.isLocal, isTrue);
    },
  );

  test('finalização online armazena somente o resultado corrigido', () async {
    final storage = MemoryQueueStorage();
    final submitter = FakeSubmitter();
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: submitter,
    );
    await service.saveForSync(submission());
    final outcome = await service.sync(
      submission().clientAttemptId,
      ignoreSchedule: true,
    );
    expect(outcome.result!.correct, 1);
    expect(await service.store.pending(), isEmpty);
    expect((await service.store.completed()).length, 1);
  });

  test('finalização offline persiste fila e agenda backoff', () async {
    final storage = MemoryQueueStorage();
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: FakeSubmitter(
        error: const AttemptSubmissionException(
          message: 'sem rede',
          transient: true,
        ),
      ),
    );
    await service.saveForSync(submission());
    final outcome = await service.sync(
      submission().clientAttemptId,
      ignoreSchedule: true,
    );
    expect(outcome.attempt.state, AttemptSyncState.waitingConnection);
    expect(outcome.attempt.attemptCount, 1);
    expect(outcome.attempt.lastError, 'sem rede');
    expect(outcome.attempt.nextAttemptAt, isNotNull);
  });

  test('reinício restaura entrega e permite reenvio posterior', () async {
    final storage = MemoryQueueStorage();
    final offline = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: FakeSubmitter(
        error: const AttemptSubmissionException(
          message: 'sem rede',
          transient: true,
        ),
      ),
    );
    await offline.saveForSync(submission());
    await offline.sync(submission().clientAttemptId, ignoreSchedule: true);

    final onlineSubmitter = FakeSubmitter();
    final restarted = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: onlineSubmitter,
    );
    final restored = (await restarted.store.pending()).single;
    expect(restored.attemptCount, 1);
    expect(restored.nextAttemptAt, isNotNull);
    final outcome = await restarted.sync(
      submission().clientAttemptId,
      ignoreSchedule: true,
    );
    expect(outcome.result, isNotNull);
    expect(onlineSubmitter.ids.single, submission().clientAttemptId);
  });

  test('clientAttemptId duplicado ocupa uma única posição na fila', () async {
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: MemoryQueueStorage()),
      submitter: FakeSubmitter(),
    );
    await service.saveForSync(submission());
    await service.saveForSync(submission());
    expect((await service.store.pending()).length, 1);
  });

  test(
    'clientAttemptId não pode ser reutilizado com respostas diferentes',
    () async {
      final service = AttemptSyncService(
        store: AttemptQueueStore(storage: MemoryQueueStorage()),
        submitter: FakeSubmitter(),
      );
      final original = submission();
      await service.saveForSync(original);
      final changed = AttemptSubmission(
        clientAttemptId: original.clientAttemptId,
        exam: original.exam,
        answers: const {0: 0},
        markedForReview: original.markedForReview,
        durationSeconds: original.durationSeconds,
        finishedAt: original.finishedAt,
      );
      await expectLater(service.saveForSync(changed), throwsStateError);
    },
  );

  test(
    'reenvios simultâneos do mesmo clientAttemptId compartilham a RPC',
    () async {
      final submitter = ControlledSubmitter();
      final service = AttemptSyncService(
        store: AttemptQueueStore(storage: MemoryQueueStorage()),
        submitter: submitter,
      );
      final value = submission();
      await service.saveForSync(value);

      final first = service.sync(value.clientAttemptId, ignoreSchedule: true);
      final second = service.sync(value.clientAttemptId, ignoreSchedule: true);
      await Future<void>.delayed(Duration.zero);
      expect(submitter.calls, 1);

      submitter.gate.complete(
        ExamResult(
          exam: value.exam.copyWith(
            questions: value.exam.questions
                .map((question) => question.copyWith(correctIndex: 1))
                .toList(),
          ),
          answers: value.answers,
          markedForReview: value.markedForReview,
          durationSeconds: value.durationSeconds,
          finishedAt: value.finishedAt,
        ),
      );
      expect((await first).result, isNotNull);
      expect((await second).result, isNotNull);
    },
  );

  test(
    'sincronizações de IDs diferentes são serializadas globalmente',
    () async {
      final submitter = ControlledSubmitter();
      final service = AttemptSyncService(
        store: AttemptQueueStore(storage: MemoryQueueStorage()),
        submitter: submitter,
      );
      final firstValue = submission();
      final secondValue = submission('22222222-2222-4222-8222-222222222222');
      await service.saveForSync(firstValue);
      await service.saveForSync(secondValue);

      final first = service.sync(
        firstValue.clientAttemptId,
        ignoreSchedule: true,
      );
      final second = service.sync(
        secondValue.clientAttemptId,
        ignoreSchedule: true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(submitter.calls, 1);

      submitter.gate.complete(
        ExamResult(
          exam: firstValue.exam.copyWith(
            questions: firstValue.exam.questions
                .map((question) => question.copyWith(correctIndex: 1))
                .toList(),
          ),
          answers: firstValue.answers,
          markedForReview: firstValue.markedForReview,
          durationSeconds: firstValue.durationSeconds,
          finishedAt: firstValue.finishedAt,
        ),
      );
      await first;
      await second;
      expect(submitter.calls, 2);
    },
  );

  test('erro permanente requer atenção e não é reenviado', () async {
    final submitter = FakeSubmitter(
      error: const AttemptSubmissionException(
        message: 'entrega inválida',
        transient: false,
      ),
    );
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: MemoryQueueStorage()),
      submitter: submitter,
    );
    await service.saveForSync(submission());
    final first = await service.sync(
      submission().clientAttemptId,
      ignoreSchedule: true,
    );
    final second = await service.sync(
      submission().clientAttemptId,
      ignoreSchedule: true,
    );
    expect(first.attempt.state, AttemptSyncState.requiresAttention);
    expect(second.attempt.state, AttemptSyncState.requiresAttention);
    expect(submitter.calls, 1);
  });

  test(
    'retry explícito recupera entrega após correção externa sem trocar ID',
    () async {
      final submitter = FakeSubmitter(
        error: const AttemptSubmissionException(
          message: 'serviço desatualizado',
          transient: false,
        ),
      );
      final storage = MemoryQueueStorage();
      final firstService = AttemptSyncService(
        store: AttemptQueueStore(storage: storage),
        submitter: submitter,
      );
      final value = submission();
      await firstService.saveForSync(value);
      await firstService.sync(value.clientAttemptId);
      submitter.error = null;
      final restarted = AttemptSyncService(
        store: AttemptQueueStore(storage: storage),
        submitter: submitter,
      );
      await restarted.syncDue();
      expect(submitter.calls, 1);
      final retried = await restarted.sync(
        value.clientAttemptId,
        ignoreSchedule: true,
        retryAttention: true,
      );
      expect(retried.result!.answers, value.answers);
      expect(submitter.ids, [value.clientAttemptId, value.clientAttemptId]);
      expect(await restarted.store.pending(), isEmpty);
      expect(await restarted.store.completed(), hasLength(1));
    },
  );

  test('backoff é limitado a uma hora', () async {
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: MemoryQueueStorage()),
      submitter: FakeSubmitter(
        error: const AttemptSubmissionException(
          message: 'sem rede',
          transient: true,
        ),
      ),
    );
    await service.saveForSync(submission());
    AttemptSyncOutcome? outcome;
    for (var index = 0; index < 7; index++) {
      outcome = await service.sync(
        submission().clientAttemptId,
        ignoreSchedule: true,
      );
    }
    final delay = outcome!.attempt.nextAttemptAt!.difference(DateTime.now());
    expect(delay <= const Duration(hours: 1), isTrue);
    expect(outcome.attempt.attemptCount, 7);
  });

  test('falha ao salvar fila é propagada sem item parcial', () async {
    final storage = MemoryQueueStorage()..failWrites = true;
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: FakeSubmitter(),
    );
    await expectLater(service.saveForSync(submission()), throwsStateError);
    storage.failWrites = false;
    expect(await service.store.pending(), isEmpty);
  });
}
