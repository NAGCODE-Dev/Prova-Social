import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/backend/attempt_draft_store.dart';

class ControlledStorage implements DraftStorage {
  final values = <String, String>{};
  final started = <String>[];
  final gates = <Completer<void>>[];
  bool fail = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    started.add(value);
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    if (fail) throw StateError('disco indisponível');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

AttemptDraft draft(int answer) => AttemptDraft(
  answers: {0: answer},
  review: const {},
  current: 0,
  elapsedSeconds: 3,
);

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'respostas rápidas são gravadas em ordem e a última é restaurada',
    () async {
      final storage = ControlledStorage();
      final store = AttemptDraftStore(storage: storage);
      final mutable = draft(0).answers;
      final first = store.save(
        'exam',
        AttemptDraft(
          answers: mutable,
          review: const {},
          current: 0,
          elapsedSeconds: 3,
        ),
      );
      mutable[0] = 1;
      final second = store.save('exam', draft(1));
      final third = store.save('exam', draft(2));
      await tick();
      expect(storage.started.length, 1);
      expect(store.status.value, DraftSaveStatus.saving);

      storage.gates[0].complete();
      await tick();
      expect(storage.started.length, 2);
      storage.gates[1].complete();
      await tick();
      expect(storage.started.length, 3);
      storage.gates[2].complete();
      await Future.wait([first, second, third, store.flush()]);
      expect(store.status.value, DraftSaveStatus.saved);
      expect((await store.load('exam'))!.answers[0], 2);
      expect((jsonDecode(storage.started.first) as Map)['answers']['0'], 0);
      store.dispose();
    },
  );

  test(
    'flush aguarda a última alteração mesmo se entrar durante a espera',
    () async {
      final storage = ControlledStorage();
      final store = AttemptDraftStore(storage: storage);
      unawaited(store.save('exam', draft(0)));
      final flushing = store.flush();
      unawaited(store.save('exam', draft(1)));
      await tick();
      storage.gates[0].complete();
      await tick();
      var completed = false;
      unawaited(
        flushing.then<void>((_) {
          completed = true;
        }),
      );
      await tick();
      expect(completed, isFalse);
      storage.gates[1].complete();
      await flushing;
      expect((await store.load('exam'))!.answers[0], 1);
      store.dispose();
    },
  );

  test(
    'falha mantém o último estado em memória e permite tentar novamente',
    () async {
      final storage = ControlledStorage()..fail = true;
      final store = AttemptDraftStore(storage: storage);
      unawaited(store.save('exam', draft(4)));
      await tick();
      storage.gates[0].complete();
      await tick();
      expect(store.status.value, DraftSaveStatus.failed);

      storage.fail = false;
      final retry = store.flush();
      await tick();
      expect(store.status.value, DraftSaveStatus.saving);
      storage.gates[1].complete();
      await retry;
      expect((await store.load('exam'))!.answers[0], 4);
      expect(store.status.value, DraftSaveStatus.saved);
      store.dispose();
    },
  );

  test('lê o formato v1 existente sem migração', () async {
    final storage = ControlledStorage();
    storage.values['attempt_draft_v1_exam'] =
        '{"answers":{"0":3},"review":[0],"current":0,"elapsedSeconds":12}';
    final store = AttemptDraftStore(storage: storage);
    final loaded = await store.load('exam');
    expect(loaded!.answers[0], 3);
    expect(loaded.review, {0});
    expect(loaded.elapsedSeconds, 12);
    expect(loaded.clientAttemptId, isNull);
    store.dispose();
  });

  test('preserva clientAttemptId estável no rascunho', () async {
    final storage = ControlledStorage();
    final store = AttemptDraftStore(storage: storage);
    final saving = store.save(
      'exam',
      const AttemptDraft(
        answers: {0: 1},
        review: {},
        current: 0,
        elapsedSeconds: 8,
        clientAttemptId: '11111111-1111-4111-8111-111111111111',
      ),
    );
    await tick();
    storage.gates.single.complete();
    await saving;
    expect(
      (await store.load('exam'))!.clientAttemptId,
      '11111111-1111-4111-8111-111111111111',
    );
    store.dispose();
  });
}
