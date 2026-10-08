import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prova_social/core/backend/local_exam_store.dart';
import 'package:prova_social/core/backend/local_exam_payload_store.dart';
import 'package:prova_social/core/import/question_parser.dart';

LocalExam draft(String title, {bool pending = false}) => LocalExam(
  id: 'local-test',
  title: title,
  category: 'Matéria',
  source: 'Origem',
  durationMinutes: 30,
  pendingPublication: pending,
  questions: [
    ImportedQuestion(
      statement: 'Questão de teste',
      options: ['A', 'B'],
      correctIndex: 1,
    ),
  ],
);

class MemoryPayloadStore implements ExamPayloadStorage {
  String? current;
  String? backup;
  bool failWrites = false;

  @override
  bool get fileBacked => true;

  @override
  Future<String?> read() async => current;
  @override
  Future<String?> readBackup() async => backup;
  @override
  Future<bool> migrate(String payload) async =>
      write(payload, backupPayload: '[]');
  @override
  Future<bool> write(String payload, {String? backupPayload}) async {
    if (failWrites) throw StateError('Falha simulada de persistência');
    backup = backupPayload ?? current;
    current = payload;
    return true;
  }
}

late MemoryPayloadStore payloadStore;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    payloadStore = MemoryPayloadStore();
    LocalExamStore.storageOverride = payloadStore;
  });
  test('question edits cannot restore answers against old alternatives', () {
    final first = draft('Prova');
    final second = draft('Prova');
    expect(first.attemptExamId, second.attemptExamId);
    second.questions.single
      ..confidence = .72
      ..warning = 'Metadado de extração';
    expect(first.attemptExamId, second.attemptExamId);
    second.questions.single.options[0] = 'Outra alternativa';
    expect(first.attemptExamId, isNot(second.attemptExamId));
  });
  test(
    'private exam persists, restores answers and publication intent',
    () async {
      final imported = draft('Minha prova', pending: true);
      imported.questions.single
        ..number = 7
        ..format = QuestionFormat.assertion
        ..confidence = .72
        ..warning = 'Estrutura incerta.';
      await LocalExamStore().save(imported);
      final restored = (await LocalExamStore().load()).single;
      expect(restored.title, 'Minha prova');
      expect(restored.pendingPublication, isTrue);
      expect(restored.exam.isLocal, isTrue);
      expect(restored.questions.single.correctIndex, 1);
      expect(restored.questions.single.number, 7);
      expect(restored.questions.single.format, QuestionFormat.assertion);
      expect(restored.questions.single.confidence, .72);
      expect(restored.questions.single.warning, 'Estrutura incerta.');
      expect(restored.toJson().containsKey('is_public'), isFalse);
    },
  );
  test(
    'review cursor, state and alternate-language versions persist',
    () async {
      final first = draft('Retomada').questions.single
        ..reviewState = QuestionReviewState.reviewed
        ..versionLabel = 'Inglês';
      first.alternateVersions.add(
        const ImportedQuestionVersion(
          label: 'Espanhol',
          statement: 'Enunciado alternativo?',
          options: ['Sí', 'No'],
          correctIndex: null,
          format: QuestionFormat.multipleChoice,
          confidence: .96,
          warning: null,
        ),
      );
      final exam = LocalExam(
        id: 'review-progress',
        title: 'Retomada',
        category: 'Idioma',
        source: 'PDF',
        durationMinutes: 30,
        reviewIndex: 1,
        questions: [
          first,
          ImportedQuestion(statement: 'Segunda?', options: ['A', 'B']),
        ],
      );

      await LocalExamStore().save(exam);
      final restored = (await LocalExamStore().load()).single;

      expect(restored.reviewIndex, 1);
      expect(
        restored.questions.first.reviewState,
        QuestionReviewState.reviewed,
      );
      expect(restored.questions.first.versionLabel, 'Inglês');
      expect(
        restored.questions.first.alternateVersions.single.label,
        'Espanhol',
      );
      expect(
        restored.questions.first.alternateVersions.single.statement,
        'Enunciado alternativo?',
      );
    },
  );
  test('migrates existing preferences payload to structured storage', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      LocalExamStore.key,
      jsonEncode([draft('Legada').toJson()]),
    );

    final restored = await LocalExamStore().load();

    expect(restored.single.title, 'Legada');
    expect(payloadStore.current, isNotNull);
    expect(preferences.getString(LocalExamStore.key), isNull);
  });
  test(
    'serial writes update existing exam and backup recovers corruption',
    () async {
      final store = LocalExamStore();
      await Future.wait([
        store.save(draft('Primeira')),
        store.save(draft('Segunda')),
      ]);
      expect((await store.load()).single.title, 'Segunda');
      payloadStore.current = 'broken';
      expect((await store.load()).single.title, 'Primeira');
      await store.save(draft('Recuperada'));
      expect((await store.load()).single.title, 'Recuperada');
    },
  );
  test('large exams save and survive a fresh store instance', () async {
    final questions = List.generate(
      90,
      (index) => ImportedQuestion(
        statement: 'Questão $index ${'texto da questão ' * 40}',
        options: List.generate(5, (option) => 'Alternativa $option'),
        correctIndex: 1,
      ),
    );
    await LocalExamStore().save(
      LocalExam(
        id: 'large',
        title: 'Prova longa',
        category: 'Geral',
        source: 'PDF',
        durationMinutes: 120,
        questions: questions,
      ),
    );
    LocalExamStore.storageOverride = payloadStore;
    expect((await LocalExamStore().load()).single.questions, hasLength(90));
  });
  test(
    'failed save preserves and recovers the previous valid version',
    () async {
      await LocalExamStore().save(draft('Versão válida'));
      final previousPayload = payloadStore.current;
      payloadStore.failWrites = true;
      await expectLater(
        LocalExamStore().save(draft('Nova versão')),
        throwsStateError,
      );
      payloadStore.failWrites = false;
      payloadStore.backup = previousPayload;
      payloadStore.current = 'broken';
      expect((await LocalExamStore().load()).single.title, 'Versão válida');
      expect(payloadStore.backup, previousPayload);
    },
  );
}
