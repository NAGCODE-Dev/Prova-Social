import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/backend/attempt_draft_store.dart';
import 'package:prova_social/core/backend/attempt_submission.dart';
import 'package:prova_social/core/backend/attempt_sync_service.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:prova_social/features/quiz/quiz_page.dart';
import 'package:prova_social/features/result/result_page.dart';

class MemoryDraftStorage implements DraftStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class FailingQueueStorage implements AttemptQueueStorage {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('sem espaço');
    this.value = value;
  }
}

class TransientSubmitter implements AttemptSubmitter {
  @override
  Future<ExamResult> submit(AttemptSubmission submission) =>
      throw const AttemptSubmissionException(
        message: 'sem rede',
        transient: true,
      );
}

class CorrectingSubmitter implements AttemptSubmitter {
  @override
  Future<ExamResult> submit(AttemptSubmission submission) async => ExamResult(
    exam: submission.exam.copyWith(
      questions: const [
        Question(
          id: 'q1',
          topic: 'Geral',
          statement: 'Pergunta?',
          options: ['Um', 'Dois'],
          correctIndex: 1,
        ),
      ],
    ),
    answers: submission.answers,
    markedForReview: submission.markedForReview,
    durationSeconds: submission.durationSeconds,
    finishedAt: submission.finishedAt,
  );
}

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
      statement: 'Pergunta?',
      options: ['Um', 'Dois'],
    ),
  ],
);

void main() {
  testWidgets('retomada usa conteúdo original mesmo com catálogo alterado', (
    tester,
  ) async {
    final storage = _MemoryQueueStorage();
    final store = AttemptQueueStore(storage: storage);
    await store.saveStartedExam(exam);
    final drafts = AttemptDraftStore(storage: MemoryDraftStorage());
    await drafts.save(
      exam.id,
      const AttemptDraft(
        answers: {0: 1},
        review: {},
        current: 0,
        elapsedSeconds: 15,
        clientAttemptId: '11111111-1111-4111-8111-111111111111',
      ),
    );
    final changed = exam.copyWith(
      questions: const [
        Question(
          id: 'q1',
          topic: 'Geral',
          statement: 'Enunciado alterado',
          options: ['Alternativa nova', 'Outra nova'],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: QuizPage(
          exam: changed,
          draftStore: drafts,
          syncService: AttemptSyncService(
            store: store,
            submitter: TransientSubmitter(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pergunta?'), findsOneWidget);
    expect(find.text('Dois'), findsOneWidget);
    expect(find.text('Enunciado alterado'), findsNothing);
    expect((await store.startedExams()).single.questions.single.options, [
      'Um',
      'Dois',
    ]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    drafts.dispose();
  });

  testWidgets('conclusão local fica no histórico e libera nova tentativa', (
    tester,
  ) async {
    final storage = _MemoryQueueStorage();
    final drafts = AttemptDraftStore(storage: MemoryDraftStorage());
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: TransientSubmitter(),
    );
    final local = Exam(
      id: 'local-exam',
      isLocal: true,
      category: exam.category,
      title: exam.title,
      description: exam.description,
      author: exam.author,
      durationMinutes: exam.durationMinutes,
      attempts: 0,
      questions: [exam.questions.single.copyWith(correctIndex: 1)],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: QuizPage(exam: local, draftStore: drafts, syncService: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dois'));
    await tester.pump();
    await tester.tap(find.text('Revisar entrega'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entregar prova'));
    await tester.pumpAndSettle();
    expect(find.byType(ResultPage), findsOneWidget);
    final restarted = AttemptQueueStore(storage: storage);
    expect((await restarted.completed()).values.single.correct, 1);
    expect(await restarted.pending(), isEmpty);
    expect(await restarted.startedExams(), isEmpty);
    expect(await drafts.load(local.id), isNull);
    await tester.pumpWidget(const SizedBox());
    drafts.dispose();
  });

  testWidgets('finalização online abre resultado corrigido', (tester) async {
    final drafts = AttemptDraftStore(storage: MemoryDraftStorage());
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: _MemoryQueueStorage()),
      submitter: CorrectingSubmitter(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: QuizPage(exam: exam, draftStore: drafts, syncService: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dois'));
    await tester.pump();
    await tester.tap(find.text('Revisar entrega'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entregar prova'));
    await tester.pumpAndSettle();
    expect(find.byType(ResultPage), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    drafts.dispose();
  });

  testWidgets('rascunho não é apagado quando fila não pode ser persistida', (
    tester,
  ) async {
    final drafts = AttemptDraftStore(storage: MemoryDraftStorage());
    final queue = FailingQueueStorage();
    final sync = AttemptSyncService(
      store: AttemptQueueStore(storage: queue),
      submitter: TransientSubmitter(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: QuizPage(exam: exam, draftStore: drafts, syncService: sync),
      ),
    );
    await tester.pumpAndSettle();
    queue.fail = true;
    await tester.tap(find.text('Dois'));
    await tester.pump();
    await tester.tap(find.text('Revisar entrega'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entregar prova'));
    await tester.pump();
    await tester.pump();
    expect((await drafts.load('exam'))!.answers[0], 1);
    expect(find.byType(QuizPage), findsOneWidget);
    drafts.dispose();
  });

  testWidgets('entrega offline não exibe nota nem gabarito', (tester) async {
    final storage = _MemoryQueueStorage();
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: TransientSubmitter(),
    );
    final submission = AttemptSubmission(
      clientAttemptId: '11111111-1111-4111-8111-111111111111',
      exam: exam,
      answers: {0: 1},
      markedForReview: {},
      durationSeconds: 5,
      finishedAt: DateTime.utc(2026, 9, 21),
    );
    await service.saveForSync(submission);
    await tester.pumpWidget(
      MaterialApp(
        home: PendingResultPage(
          clientAttemptId: submission.clientAttemptId,
          syncService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('aguardando correção'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('Gabarito'), findsNothing);
  });
}

class _MemoryQueueStorage implements AttemptQueueStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}
