import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prova_social/core/backend/attempt_draft_store.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:prova_social/features/quiz/quiz_page.dart';

class SlowDraftStorage implements DraftStorage {
  final values = <String, String>{};
  final writes = <Completer<void>>[];

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    final gate = Completer<void>();
    writes.add(gate);
    await gate.future;
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

void main() {
  testWidgets('sair espera a gravação pendente e preserva a resposta', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = SlowDraftStorage();
    final store = AttemptDraftStore(storage: storage);
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
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => QuizPage(exam: exam, draftStore: store),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dois'));
    await tester.pump();
    expect(find.text('Salvando no aparelho'), findsOneWidget);
    await tester.tap(find.byTooltip('Sair da prova'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await tester.pump();
    expect(find.byType(QuizPage), findsOneWidget);

    storage.writes[0].complete();
    await tester.pump();
    expect(find.byType(QuizPage), findsOneWidget);
    storage.writes[1].complete();
    await tester.pumpAndSettle();
    expect(find.byType(QuizPage), findsNothing);
    expect((await store.load('exam'))!.answers[0], 1);
    store.dispose();
  });
}
