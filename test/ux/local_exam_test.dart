import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prova_social/core/backend/local_exam_store.dart';
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
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('question edits cannot restore answers against old alternatives', () {
    final first = draft('Prova');
    final second = draft('Prova');
    expect(first.attemptExamId, second.attemptExamId);
    second.questions.single.options[0] = 'Outra alternativa';
    expect(first.attemptExamId, isNot(second.attemptExamId));
  });
  test(
    'private exam persists, restores answers and publication intent',
    () async {
      await LocalExamStore().save(draft('Minha prova', pending: true));
      final restored = (await LocalExamStore().load()).single;
      expect(restored.title, 'Minha prova');
      expect(restored.pendingPublication, isTrue);
      expect(restored.exam.isLocal, isTrue);
      expect(restored.questions.single.correctIndex, 1);
      expect(restored.toJson().containsKey('is_public'), isFalse);
    },
  );
  test(
    'serial writes retain latest version and backup recovers corruption',
    () async {
      final store = LocalExamStore();
      await Future.wait([
        store.save(draft('Primeira')),
        store.save(draft('Segunda')),
      ]);
      expect((await store.load()).single.title, 'Segunda');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LocalExamStore.key, 'broken');
      expect((await store.load()).single.title, 'Primeira');
      await store.save(draft('Recuperada'));
      expect((await store.load()).single.title, 'Recuperada');
    },
  );
  test('unrecoverable data is not overwritten', () async {
    SharedPreferences.setMockInitialValues({LocalExamStore.key: 'broken'});
    await expectLater(
      LocalExamStore().save(draft('Nova')),
      throwsFormatException,
    );
    expect(
      (await SharedPreferences.getInstance()).getString(LocalExamStore.key),
      'broken',
    );
  });
  test('oversized write fails without losing previous exam', () async {
    await LocalExamStore().save(draft('Anterior'));
    await expectLater(
      LocalExamStore().save(draft('a' * (4 * 1024 * 1024))),
      throwsStateError,
    );
    expect((await LocalExamStore().load()).single.title, 'Anterior');
  });
}
