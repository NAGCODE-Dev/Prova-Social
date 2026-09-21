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
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async => throw StateError('sem espaço');
}

class TransientSubmitter implements AttemptSubmitter {
  @override
  Future<ExamResult> submit(AttemptSubmission submission) =>
      throw const AttemptSubmissionException(message: 'sem rede', transient: true);
}

class CorrectingSubmitter implements AttemptSubmitter {
  @override
  Future<ExamResult> submit(AttemptSubmission submission) async => ExamResult(
        exam: submission.exam.copyWith(questions: const [
          Question(id: 'q1', topic: 'Geral', statement: 'Pergunta?', options: ['Um', 'Dois'], correctIndex: 1),
        ]),
        answers: submission.answers,
        markedForReview: submission.markedForReview,
        durationSeconds: submission.durationSeconds,
        finishedAt: submission.finishedAt,
      );
}

const exam = Exam(
  id: 'exam', category: 'Geral', title: 'Prova', description: '',
  author: 'Fonte', durationMinutes: 30, attempts: 0,
  questions: [Question(id: 'q1', topic: 'Geral', statement: 'Pergunta?', options: ['Um', 'Dois'])],
);

void main() {
  testWidgets('finalização online abre resultado corrigido', (tester) async {
    final drafts = AttemptDraftStore(storage: MemoryDraftStorage());
    final service = AttemptSyncService(
      store: AttemptQueueStore(storage: _MemoryQueueStorage()),
      submitter: CorrectingSubmitter(),
    );
    await tester.pumpWidget(MaterialApp(home: QuizPage(
      exam: exam, draftStore: drafts, syncService: service,
    )));
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

  testWidgets('rascunho não é apagado quando fila não pode ser persistida', (tester) async {
    final drafts = AttemptDraftStore(storage: MemoryDraftStorage());
    final sync = AttemptSyncService(
      store: AttemptQueueStore(storage: FailingQueueStorage()),
      submitter: TransientSubmitter(),
    );
    await tester.pumpWidget(MaterialApp(home: QuizPage(
      exam: exam, draftStore: drafts, syncService: sync,
    )));
    await tester.pumpAndSettle();
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
    await tester.pumpWidget(MaterialApp(home: PendingResultPage(
      clientAttemptId: submission.clientAttemptId,
      syncService: service,
    )));
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
