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
  Future<void> Function()? beforeRemove;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    await beforeRemove?.call();
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
  testWidgets('responder, sair, retomar snapshot e entregar offline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final original = exam.copyWith(
      questions: [
        exam.questions.single,
        const Question(
          id: 'q2',
          topic: 'Geral',
          statement: 'Segunda pergunta?',
          options: ['Três', 'Quatro'],
        ),
        const Question(
          id: 'q3',
          topic: 'Geral',
          statement: 'Terceira pergunta?',
          options: ['Cinco', 'Seis'],
        ),
      ],
    );
    var catalog = original;
    final storage = _MemoryQueueStorage();
    final draftStorage = MemoryDraftStorage();
    var drafts = AttemptDraftStore(storage: draftStorage);
    final submitter = ReconnectingSubmitter();
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: storage),
      submitter: submitter,
    );
    List<PendingAttempt>? durableBeforeClear;
    draftStorage.beforeRemove = () async {
      durableBeforeClear = await AttemptQueueStore(storage: storage).pending();
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => QuizPage(
                    exam: catalog,
                    draftStore: drafts,
                    syncService: service,
                  ),
                ),
              ),
              child: const Text('Abrir prova'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir prova'));
    await tester.pumpAndSettle();
    expect((await service.store.startedExams()).single.questions.length, 3);
    await tester.tap(find.text('Um'));
    await tester.pump();
    expect((await drafts.load(exam.id))!.answers, {0: 0});
    await tester.tap(find.text('Dois'));
    await tester.pump();
    expect((await drafts.load(exam.id))!.answers, {0: 1});
    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();
    expect((await drafts.load(exam.id))!.current, 1);
    await tester.tap(find.text('Quatro'));
    await tester.pump();
    await tester.tap(find.byTooltip('Marcar para revisão'));
    await tester.pump();
    expect((await drafts.load(exam.id))!.review, {1});
    await tester.tap(find.text('Anterior'));
    await tester.pumpAndSettle();
    expect((await drafts.load(exam.id))!.answers, {0: 1, 1: 1});
    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byTooltip('Sair da prova'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(find.byType(QuizPage), findsNothing);
    final saved = (await drafts.load(exam.id))!;
    expect(saved.current, 1);
    expect(saved.elapsedSeconds, greaterThanOrEqualTo(3));
    expect(saved.clientAttemptId, isNotNull);
    drafts.dispose();
    drafts = AttemptDraftStore(storage: draftStorage);
    catalog = exam.copyWith(questions: const []);
    await tester.tap(find.text('Abrir prova'));
    await tester.pumpAndSettle();
    expect(find.text('Segunda pergunta?'), findsOneWidget);
    expect(find.byTooltip('Remover da revisão'), findsOneWidget);
    final selected = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Alternativa B, Quatro',
      ),
    );
    expect(selected.properties.selected, isTrue);
    final restored = (await drafts.load(exam.id))!;
    expect(restored.answers, saved.answers);
    expect(restored.review, saved.review);
    expect(restored.current, saved.current);
    expect(restored.clientAttemptId, saved.clientAttemptId);
    expect(restored.elapsedSeconds, saved.elapsedSeconds);
    final time =
        '${(saved.elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(saved.elapsedSeconds % 60).toString().padLeft(2, '0')}';
    expect(find.text(time), findsOneWidget);
    // Still offline: change the restored answer and leave question 3 blank.
    await tester.tap(find.text('Três'));
    await tester.pump();
    expect((await drafts.load(exam.id))!.answers, {0: 1, 1: 0});
    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();
    expect(find.text('Terceira pergunta?'), findsOneWidget);
    expect(submitter.calls, 0);
    await tester.tap(find.text('Revisar entrega'));
    await tester.pumpAndSettle();
    expect(find.text('2 de 3 respondidas'), findsOneWidget);
    expect(find.text('Não respondidas'), findsOneWidget);
    expect(find.text('Marcadas para revisão'), findsOneWidget);
    await tester.tap(find.text('Entregar mesmo com questões em branco'));
    await tester.pumpAndSettle();
    expect(find.byType(PendingResultPage), findsOneWidget);
    expect(durableBeforeClear, hasLength(1));
    expect(durableBeforeClear!.single.submission.answers, {0: 1, 1: 0});
    expect(await drafts.load(exam.id), isNull);
    final pending = (await AttemptQueueStore(
      storage: storage,
    ).pending()).single;
    expect(pending.state, AttemptSyncState.waitingConnection);
    expect(pending.submission.clientAttemptId, saved.clientAttemptId);
    expect(pending.submission.answers, {0: 1, 1: 0});
    expect(pending.submission.markedForReview, {1});
    expect(pending.submission.exam.questions.length, 3);
    expect(pending.submission.durationSeconds, greaterThanOrEqualTo(3));
    expect(await service.store.completed(), isEmpty);
    submitter.offline = false;
    await tester.tap(find.text('Tentar agora'));
    await tester.pumpAndSettle();
    expect(find.byType(ResultPage), findsOneWidget);
    expect(find.text('1 de 3 acertos'), findsOneWidget);
    final result = (await AttemptQueueStore(
      storage: storage,
    ).completed()).values.single;
    expect(result.answers, pending.submission.answers);
    expect(result.markedForReview, {1});
    expect(result.unanswered, 1);
    expect(result.wrongQuestionIndices, [1]);
    expect(await service.store.pending(), isEmpty);
    final calls = submitter.calls;
    await service.sync(saved.clientAttemptId!);
    expect(submitter.calls, calls);
    expect(await service.store.completed(), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    drafts.dispose();
  });

  testWidgets('conclusão local fica no histórico e libera nova tentativa', (
    tester,
  ) async {
    final storage = _MemoryQueueStorage();
    final draftStorage = MemoryDraftStorage();
    final drafts = AttemptDraftStore(storage: draftStorage);
    Map<String, ExamResult>? beforeClear;
    draftStorage.beforeRemove = () async {
      beforeClear = await AttemptQueueStore(storage: storage).completed();
    };
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
    expect(beforeClear, hasLength(1));
    expect(beforeClear!.values.single.answers, {0: 1});
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
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
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
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
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
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
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

class ReconnectingSubmitter implements AttemptSubmitter {
  bool offline = true;
  int calls = 0;

  @override
  Future<ExamResult> submit(AttemptSubmission submission) async {
    calls++;
    if (offline) {
      throw const AttemptSubmissionException(
        message: 'sem rede',
        transient: true,
      );
    }
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
