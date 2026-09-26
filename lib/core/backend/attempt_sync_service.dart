import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/exam.dart';
import 'attempt_repository.dart';
import 'attempt_submission.dart';

enum AttemptSyncState {
  pendingSync,
  sending,
  waitingConnection,
  synced,
  requiresAttention,
}

class PendingAttempt {
  const PendingAttempt({
    required this.submission,
    required this.state,
    required this.attemptCount,
    this.lastError,
    this.nextAttemptAt,
  });

  final AttemptSubmission submission;
  final AttemptSyncState state;
  final int attemptCount;
  final String? lastError;
  final DateTime? nextAttemptAt;

  PendingAttempt copyWith({
    AttemptSyncState? state,
    int? attemptCount,
    String? lastError,
    DateTime? nextAttemptAt,
    bool clearNextAttempt = false,
  }) => PendingAttempt(
    submission: submission,
    state: state ?? this.state,
    attemptCount: attemptCount ?? this.attemptCount,
    lastError: lastError ?? this.lastError,
    nextAttemptAt: clearNextAttempt
        ? null
        : nextAttemptAt ?? this.nextAttemptAt,
  );
}

abstract class AttemptQueueStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class _PreferencesAttemptQueueStorage implements AttemptQueueStorage {
  static const key = 'attempt_sync_queue_v1';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String value) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      key,
      value,
    );
    if (!saved)
      throw StateError('Não foi possível salvar a entrega no aparelho.');
  }
}

class AttemptQueueStore {
  AttemptQueueStore({AttemptQueueStorage? storage})
    : _storage = storage ?? _PreferencesAttemptQueueStorage();

  final AttemptQueueStorage _storage;
  static Future<void> _globalTail = Future<void>.value();

  Future<T> _locked<T>(Future<T> Function() operation) {
    final result = _globalTail.then((_) => operation());
    _globalTail = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  Future<Map<String, dynamic>> _read() async {
    final raw = await _storage.read();
    if (raw == null)
      return {'pending': <dynamic>[], 'completed': <String, dynamic>{}};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> _write(Map<String, dynamic> data) =>
      _storage.write(jsonEncode(data));

  Future<void> saveStartedExam(Exam exam) => _locked(() async {
    final data = await _read();
    final started = Map<String, dynamic>.from(
      data['started'] as Map? ?? const {},
    );
    started[exam.id] = _examToJson(exam);
    data['started'] = started;
    await _write(data);
  });

  Future<List<Exam>> startedExams() => _locked(() async {
    final data = await _read();
    return Map<String, dynamic>.from(data['started'] as Map? ?? const {}).values
        .map((item) => _examFromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  });

  void _removeStarted(Map<String, dynamic> data, String examId) {
    final started = Map<String, dynamic>.from(
      data['started'] as Map? ?? const {},
    );
    started.remove(examId);
    data['started'] = started;
  }

  Future<void> completeLocal(String clientAttemptId, ExamResult result) =>
      _locked(() async {
        if (!result.exam.isLocal) {
          throw StateError(
            'Uma prova pública precisa de correção do servidor.',
          );
        }
        final data = await _read();
        final completed = Map<String, dynamic>.from(
          data['completed'] as Map? ?? const {},
        );
        completed[clientAttemptId] = _resultToJson(result);
        data['completed'] = completed;
        _removeStarted(data, result.exam.id);
        await _write(data);
      });

  Future<void> enqueue(AttemptSubmission value) {
    // Capture the complete payload before waiting for other queued writes.
    final submission = _submissionFromJson(
      jsonDecode(jsonEncode(_submissionToJson(value))) as Map<String, dynamic>,
    );
    return _locked(() async {
      final data = await _read();
      final completed = Map<String, dynamic>.from(
        data['completed'] as Map? ?? const {},
      );
      final completedJson = completed[submission.clientAttemptId];
      if (completedJson != null) {
        final result = _resultFromJson(
          Map<String, dynamic>.from(completedJson as Map),
        );
        if (!_matchesResult(submission, result)) {
          throw StateError(
            'clientAttemptId já usado por uma entrega diferente.',
          );
        }
        return;
      }
      final pending = List<dynamic>.from(data['pending'] as List? ?? const []);
      final duplicateIndex = pending.indexWhere(
        (item) =>
            (item as Map)['clientAttemptId'] == submission.clientAttemptId,
      );
      if (duplicateIndex >= 0) {
        final existing = _pendingFromJson(
          Map<String, dynamic>.from(pending[duplicateIndex] as Map),
        );
        if (!_sameSubmission(existing.submission, submission)) {
          throw StateError(
            'clientAttemptId já usado por uma entrega diferente.',
          );
        }
        return;
      }
      pending.add(
        _pendingToJson(
          PendingAttempt(
            submission: submission,
            state: AttemptSyncState.pendingSync,
            attemptCount: 0,
          ),
        ),
      );
      data['pending'] = pending;
      _removeStarted(data, submission.exam.id);
      await _write(data);
    });
  }

  Future<List<PendingAttempt>> pending() => _locked(() async {
    final data = await _read();
    return List<dynamic>.from(data['pending'] as List? ?? const [])
        .map((item) => _pendingFromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  });

  Future<PendingAttempt?> find(String clientAttemptId) async {
    final items = await pending();
    for (final item in items) {
      if (item.submission.clientAttemptId == clientAttemptId) return item;
    }
    return null;
  }

  Future<void> update(PendingAttempt value) => _locked(() async {
    final data = await _read();
    final pending = List<dynamic>.from(data['pending'] as List? ?? const []);
    final index = pending.indexWhere(
      (item) =>
          (item as Map)['clientAttemptId'] == value.submission.clientAttemptId,
    );
    if (index < 0) throw StateError('Entrega pendente não encontrada.');
    pending[index] = _pendingToJson(value);
    data['pending'] = pending;
    await _write(data);
  });

  Future<void> complete(PendingAttempt pending, ExamResult result) =>
      _locked(() async {
        final data = await _read();
        final items = List<dynamic>.from(data['pending'] as List? ?? const []);
        items.removeWhere(
          (item) =>
              (item as Map)['clientAttemptId'] ==
              pending.submission.clientAttemptId,
        );
        final completed = Map<String, dynamic>.from(
          data['completed'] as Map? ?? const {},
        );
        completed[pending.submission.clientAttemptId] = _resultToJson(result);
        data
          ..['pending'] = items
          ..['completed'] = completed;
        await _write(data);
      });

  Future<Map<String, ExamResult>> completed() => _locked(() async {
    final data = await _read();
    final completed = Map<String, dynamic>.from(
      data['completed'] as Map? ?? const {},
    );
    return completed.map(
      (key, value) => MapEntry(
        key,
        _resultFromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
  });
}

class AttemptSyncOutcome {
  const AttemptSyncOutcome({required this.attempt, this.result});
  final PendingAttempt attempt;
  final ExamResult? result;
}

class AttemptSyncService {
  AttemptSyncService({AttemptQueueStore? store, AttemptSubmitter? submitter})
    : store = store ?? AttemptQueueStore(),
      _submitter = submitter;

  final AttemptQueueStore store;
  final AttemptSubmitter? _submitter;
  static final Map<String, Future<AttemptSyncOutcome>> _inFlight = {};
  static Future<void> _globalSyncTail = Future<void>.value();

  static String newClientAttemptId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  Future<void> saveForSync(AttemptSubmission submission) async {
    if (submission.exam.isLocal)
      throw StateError('Provas locais não podem ser sincronizadas.');
    await store.enqueue(submission);
  }

  Future<AttemptSyncOutcome> sync(
    String clientAttemptId, {
    bool ignoreSchedule = false,
    bool retryAttention = false,
  }) {
    final running = _inFlight[clientAttemptId];
    if (running != null) return running;
    final operation = _globalSyncTail.then(
      (_) => _sync(
        clientAttemptId,
        ignoreSchedule: ignoreSchedule,
        retryAttention: retryAttention,
      ),
    );
    _globalSyncTail = operation.then<void>((_) {}, onError: (_, __) {});
    _inFlight[clientAttemptId] = operation;
    unawaited(
      operation.then<void>(
        (_) => _inFlight.remove(clientAttemptId),
        onError: (Object _, StackTrace __) {
          _inFlight.remove(clientAttemptId);
        },
      ),
    );
    return operation;
  }

  Future<AttemptSyncOutcome> _sync(
    String clientAttemptId, {
    required bool ignoreSchedule,
    required bool retryAttention,
  }) async {
    var pending = await store.find(clientAttemptId);
    if (pending == null) {
      final result = (await store.completed())[clientAttemptId];
      if (result == null) throw StateError('Entrega não encontrada.');
      return AttemptSyncOutcome(
        attempt: PendingAttempt(
          submission: AttemptSubmission(
            clientAttemptId: clientAttemptId,
            exam: result.exam,
            answers: result.answers,
            markedForReview: result.markedForReview,
            durationSeconds: result.durationSeconds,
            finishedAt: result.finishedAt,
          ),
          state: AttemptSyncState.synced,
          attemptCount: 0,
        ),
        result: result,
      );
    }
    if (pending.state == AttemptSyncState.requiresAttention &&
        !retryAttention) {
      return AttemptSyncOutcome(attempt: pending);
    }
    final now = DateTime.now();
    if (!ignoreSchedule &&
        pending.nextAttemptAt != null &&
        pending.nextAttemptAt!.isAfter(now)) {
      return AttemptSyncOutcome(attempt: pending);
    }
    pending = pending.copyWith(
      state: AttemptSyncState.sending,
      clearNextAttempt: true,
    );
    await store.update(pending);
    try {
      final result = await (_submitter ?? AttemptRepository()).submit(
        pending.submission,
      );
      await store.complete(pending, result);
      return AttemptSyncOutcome(
        attempt: pending.copyWith(state: AttemptSyncState.synced),
        result: result,
      );
    } on AttemptSubmissionException catch (error) {
      final attempts = pending.attemptCount + 1;
      if (!error.transient) {
        pending = pending.copyWith(
          state: AttemptSyncState.requiresAttention,
          attemptCount: attempts,
          lastError: error.message,
          clearNextAttempt: true,
        );
      } else {
        pending = pending.copyWith(
          state: AttemptSyncState.waitingConnection,
          attemptCount: attempts,
          lastError: error.message,
          nextAttemptAt: now.add(_backoff(attempts)),
        );
      }
      await store.update(pending);
      return AttemptSyncOutcome(attempt: pending);
    }
  }

  Future<void> syncDue() async {
    final now = DateTime.now();
    for (final item in await store.pending()) {
      if (item.state != AttemptSyncState.requiresAttention &&
          (item.nextAttemptAt == null || !item.nextAttemptAt!.isAfter(now))) {
        await sync(item.submission.clientAttemptId);
      }
    }
  }

  static Duration _backoff(int attempts) {
    const seconds = [30, 120, 600, 1800, 3600];
    return Duration(seconds: seconds[min(attempts - 1, seconds.length - 1)]);
  }
}

bool _sameSubmission(AttemptSubmission first, AttemptSubmission second) =>
    first.exam.id == second.exam.id &&
    first.durationSeconds == second.durationSeconds &&
    _sameMap(first.answers, second.answers) &&
    _sameSet(first.markedForReview, second.markedForReview);

bool _matchesResult(AttemptSubmission submission, ExamResult result) =>
    submission.exam.id == result.exam.id &&
    submission.durationSeconds == result.durationSeconds &&
    _sameMap(submission.answers, result.answers) &&
    _sameSet(submission.markedForReview, result.markedForReview);

bool _sameMap(Map<int, int> first, Map<int, int> second) =>
    first.length == second.length &&
    first.entries.every((entry) => second[entry.key] == entry.value);

bool _sameSet(Set<int> first, Set<int> second) =>
    first.length == second.length && first.every(second.contains);

Map<String, dynamic> _pendingToJson(PendingAttempt value) => {
  ..._submissionToJson(value.submission),
  'state': value.state.name,
  'attemptCount': value.attemptCount,
  'lastError': value.lastError,
  'nextAttemptAt': value.nextAttemptAt?.toIso8601String(),
};

PendingAttempt _pendingFromJson(Map<String, dynamic> json) => PendingAttempt(
  submission: _submissionFromJson(json),
  state: AttemptSyncState.values.firstWhere(
    (value) => value.name == json['state'],
    orElse: () => AttemptSyncState.pendingSync,
  ),
  attemptCount: json['attemptCount'] as int? ?? 0,
  lastError: json['lastError'] as String?,
  nextAttemptAt: DateTime.tryParse(json['nextAttemptAt'] as String? ?? ''),
);

Map<String, dynamic> _submissionToJson(AttemptSubmission value) => {
  'clientAttemptId': value.clientAttemptId,
  'exam': _examToJson(value.exam),
  'answers': value.answers.map((key, value) => MapEntry('$key', value)),
  'review': value.markedForReview.toList(),
  'durationSeconds': value.durationSeconds,
  'finishedAt': value.finishedAt.toIso8601String(),
};

AttemptSubmission _submissionFromJson(Map<String, dynamic> json) =>
    AttemptSubmission(
      clientAttemptId: json['clientAttemptId'] as String,
      exam: _examFromJson(Map<String, dynamic>.from(json['exam'] as Map)),
      answers: Map<String, dynamic>.from(
        json['answers'] as Map,
      ).map((key, value) => MapEntry(int.parse(key), value as int)),
      markedForReview: Set<int>.from(json['review'] as List? ?? const []),
      durationSeconds: json['durationSeconds'] as int,
      finishedAt: DateTime.parse(json['finishedAt'] as String),
    );

Map<String, dynamic> _examToJson(Exam exam) => {
  'id': exam.id,
  'isLocal': exam.isLocal,
  'category': exam.category,
  'title': exam.title,
  'description': exam.description,
  'author': exam.author,
  'durationMinutes': exam.durationMinutes,
  'attempts': exam.attempts,
  'sourceType': exam.sourceType.name,
  'sourceUrl': exam.sourceUrl,
  'questions': exam.questions
      .map(
        (question) => {
          'id': question.id,
          'topic': question.topic,
          'statement': question.statement,
          'options': question.options,
          'correctIndex': question.correctIndex,
        },
      )
      .toList(),
};

Exam _examFromJson(Map<String, dynamic> json) => Exam(
  id: json['id'] as String,
  isLocal: json['isLocal'] == true,
  category: json['category'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  author: json['author'] as String,
  durationMinutes: json['durationMinutes'] as int,
  attempts: json['attempts'] as int,
  sourceType: ExamSourceType.fromDatabase(json['sourceType']),
  sourceUrl: json['sourceUrl'] as String?,
  questions: List<dynamic>.from(json['questions'] as List)
      .map((item) {
        final question = Map<String, dynamic>.from(item as Map);
        return Question(
          id: question['id'] as String,
          topic: question['topic'] as String,
          statement: question['statement'] as String,
          options: List<String>.from(question['options'] as List),
          correctIndex: question['correctIndex'] as int?,
        );
      })
      .toList(growable: false),
);

Map<String, dynamic> _resultToJson(ExamResult result) => {
  ..._submissionToJson(
    AttemptSubmission(
      clientAttemptId: '',
      exam: result.exam,
      answers: result.answers,
      markedForReview: result.markedForReview,
      durationSeconds: result.durationSeconds,
      finishedAt: result.finishedAt,
    ),
  ),
};

ExamResult _resultFromJson(Map<String, dynamic> json) {
  final submission = _submissionFromJson(json);
  return ExamResult(
    exam: submission.exam,
    answers: submission.answers,
    markedForReview: submission.markedForReview,
    durationSeconds: submission.durationSeconds,
    finishedAt: submission.finishedAt,
  );
}
