import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/backend/attempt_draft_store.dart';
import 'package:prova_social/core/backend/attempt_sync_service.dart';
import 'package:prova_social/core/backend/attempt_submission.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:prova_social/features/quiz/quiz_page.dart';
import 'package:prova_social/features/result/result_page.dart';

import 'attempt_sync_service_test.dart' as queue_fixture;
import 'quiz_offline_submission_test.dart' as fixture;

Exam localExam({int count = 3, bool withKey = true}) => Exam(
  id: 'qa-local-torture',
  isLocal: true,
  category: 'QA',
  title: 'QA fixture',
  description: '',
  author: 'QA',
  durationMinutes: 30,
  attempts: 0,
  questions: List.generate(
    count,
    (index) => Question(
      id: 'q$index',
      topic: 'QA',
      statement: 'QA questão $index',
      options: const ['Um', 'Dois'],
      correctIndex: withKey ? 1 : null,
    ),
  ),
);

void main() {
  testWidgets('resultado salvo permanece acessível durante vínculo offline', (
    tester,
  ) async {
    String? userId;
    final remote = queue_fixture.FakeSubmitter();
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: queue_fixture.MemoryQueueStorage()),
      submitter: remote,
      currentUserId: () => userId,
    );
    final submission = queue_fixture.submission();
    await service.saveForSync(submission);
    await service.sync(submission.clientAttemptId);
    userId = 'account-a';
    remote.error = const AttemptSubmissionException(
      message: 'QA offline',
      transient: true,
    );
    await service.syncDue();
    await tester.pumpWidget(
      MaterialApp(
        home: PendingResultPage(
          clientAttemptId: submission.clientAttemptId,
          syncService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ver resultado salvo'), findsOneWidget);
    expect(await service.store.pending(), hasLength(1));
    await tester.tap(find.text('Ver resultado salvo'));
    await tester.pumpAndSettle();
    expect(find.text('1 de 1 acertos'), findsOneWidget);
    expect(await service.store.completed(), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sem gabarito não inventa percentual', (tester) async {
    final result = ExamResult(
      exam: localExam(count: 1, withKey: false),
      answers: const {0: 1},
      markedForReview: const {},
      durationSeconds: 0,
      finishedAt: DateTime.utc(2026, 9, 26),
    );
    expect(result.wrongQuestionIndices, isEmpty);
    await tester.pumpWidget(MaterialApp(home: ResultPage(result: result)));
    expect(find.text('Gabarito indisponível'), findsWidgets);
    expect(find.textContaining('%'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final answered in [
    <int>{},
    {1, 2},
    {0, 1},
    {1},
  ]) {
    testWidgets('entrega com brancos: respondidas $answered', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final drafts = AttemptDraftStore(storage: fixture.MemoryDraftStorage());
      final store = AttemptQueueStore(
        storage: queue_fixture.MemoryQueueStorage(),
      );
      final service = AttemptSyncService(
        store: store,
        submitter: fixture.TransientSubmitter(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: QuizPage(
            exam: localExam(),
            draftStore: drafts,
            syncService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var index = 0; index < 3; index++) {
        expect(find.text('QA questão $index'), findsOneWidget);
        if (answered.contains(index)) {
          await tester.tap(find.text('Dois'));
          await tester.pump();
        }
        if (index < 2) {
          await tester.tap(find.text('Próxima'));
          await tester.pumpAndSettle();
        }
      }
      await tester.tap(find.text('Revisar entrega'));
      await tester.pumpAndSettle();
      expect(find.text('${answered.length} de 3 respondidas'), findsOneWidget);
      expect(find.text('Não respondidas'), findsOneWidget);
      await tester.tap(find.text('Entregar mesmo com questões em branco'));
      await tester.pumpAndSettle();
      expect(find.byType(ResultPage), findsOneWidget);
      final result = (await store.completed()).values.single;
      expect(result.correct, answered.length);
      expect(result.unanswered, 3 - answered.length);
      expect(result.wrongQuestionIndices, isEmpty);
      expect(result.answers.keys.toSet(), answered);
      expect(result.scorePercent, (answered.length / 3 * 100).round());
      expect(find.textContaining('NaN'), findsNothing);
      expect(find.textContaining('Infinity'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      drafts.dispose();
    });
  }

  for (final local in [true, false]) {
    testWidgets('reinício entre entrega durável e remoção: local=$local', (
      tester,
    ) async {
      final exam = local ? localExam(count: 1) : fixture.exam;
      final storage = queue_fixture.MemoryQueueStorage();
      final draftStorage = fixture.MemoryDraftStorage();
      final drafts = AttemptDraftStore(storage: draftStorage);
      final service = AttemptSyncService(
        store: AttemptQueueStore(storage: storage),
        submitter: fixture.TransientSubmitter(),
      );
      String? queueAtCrash;
      Map<String, String>? draftsAtCrash;
      draftStorage.beforeRemove = () async {
        // Capture the exact durable state at this boundary, then deny cleanup.
        queueAtCrash = storage.value;
        draftsAtCrash = Map.of(draftStorage.values);
        if (local) {
          expect(await service.store.completed(), hasLength(1));
        } else {
          expect(await service.store.pending(), hasLength(1));
        }
        throw StateError('QA interrupted cleanup');
      };
      await tester.pumpWidget(
        MaterialApp(
          home: QuizPage(exam: exam, draftStore: drafts, syncService: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dois'));
      await tester.pump();
      final id = (await drafts.load(exam.id))!.clientAttemptId!;
      await tester.tap(find.text('Revisar entrega'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entregar prova'));
      await tester.pumpAndSettle();
      expect(queueAtCrash, isNotNull);
      expect(draftsAtCrash, isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      drafts.dispose();

      // New stores have only the bytes captured at the crash point.
      final recoveredStorage = queue_fixture.MemoryQueueStorage()
        ..value = queueAtCrash;
      final recoveredDraftStorage = fixture.MemoryDraftStorage()
        ..values.addAll(draftsAtCrash!);
      final recoveredDrafts = AttemptDraftStore(storage: recoveredDraftStorage);
      final recovered = AttemptSyncService(
        store: AttemptQueueStore(storage: recoveredStorage),
        submitter: fixture.TransientSubmitter(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: QuizPage(
            exam: exam,
            draftStore: recoveredDrafts,
            syncService: recovered,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (local) {
        expect(find.byType(ResultPage), findsOneWidget);
        expect((await recovered.store.completed()).keys, [id]);
        expect((await recovered.store.completed())[id]!.answers, {0: 1});
        expect(await recovered.store.pending(), isEmpty);
      } else {
        expect(find.byType(PendingResultPage), findsOneWidget);
        final pending = (await recovered.store.pending()).single;
        expect(pending.submission.clientAttemptId, id);
        expect(pending.submission.answers, {0: 1});
        expect(await recovered.store.completed(), isEmpty);
      }
      expect(await recoveredDrafts.load(exam.id), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      recoveredDrafts.dispose();
    });
  }

  testWidgets('prova vazia não inventa resultado', (tester) async {
    final drafts = AttemptDraftStore(storage: fixture.MemoryDraftStorage());
    final store = AttemptQueueStore(
      storage: queue_fixture.MemoryQueueStorage(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: QuizPage(
          exam: localExam(count: 0),
          draftStore: drafts,
          syncService: AttemptSyncService(
            store: store,
            submitter: fixture.TransientSubmitter(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dois'), findsNothing);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.textContaining('Suas respostas salvas'), findsOneWidget);
    expect(find.byType(ResultPage), findsNothing);
    expect(await store.completed(), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    drafts.dispose();
  });
}
