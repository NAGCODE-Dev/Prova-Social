import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:crypto/crypto.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/exam.dart';
import 'local_exam_payload_store.dart';
import '../import/question_parser.dart';

/// Local-only content. Authentication never changes its visibility.
class LocalExam {
  LocalExam({
    required this.id,
    required this.title,
    required this.category,
    required this.source,
    required this.durationMinutes,
    required this.questions,
    this.year,
    this.pendingPublication = false,
    this.reviewIndex = 0,
  });
  final String id, title, category, source;
  final int durationMinutes;
  final int? year;
  final List<ImportedQuestion> questions;
  final bool pendingPublication;
  final int reviewIndex;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'source': source,
    'durationMinutes': durationMinutes,
    'year': year,
    'pendingPublication': pendingPublication,
    'reviewIndex': reviewIndex,
    'questions': questions
        .map(
          (q) => {
            'statement': q.statement,
            'options': q.options,
            'correctIndex': q.correctIndex,
            'number': q.number,
            'format': q.format.name,
            'confidence': q.confidence,
            'warning': q.warning,
            'reviewState': q.reviewState.name,
            'versionLabel': q.versionLabel,
            'alternateVersions': q.alternateVersions
                .map((version) => version.toJson())
                .toList(),
          },
        )
        .toList(),
  };
  factory LocalExam.fromJson(Map<String, dynamic> data) {
    final questions = (data['questions'] as List)
        .map(
          (q) => ImportedQuestion(
            statement: q['statement'] as String,
            options: List<String>.from(q['options'] as List),
            correctIndex: q['correctIndex'] as int?,
            number: q['number'] as int?,
            format: QuestionFormat.values.firstWhere(
              (format) => format.name == q['format'],
              orElse: () => QuestionFormat.multipleChoice,
            ),
            confidence: ((q['confidence'] as num?)?.toDouble() ?? 1)
                .clamp(0, 1)
                .toDouble(),
            warning: q['warning'] as String?,
            reviewState: QuestionReviewState.values.firstWhere(
              (state) => state.name == q['reviewState'],
              orElse: () => QuestionReviewState.unreviewed,
            ),
            versionLabel: q['versionLabel'] as String? ?? 'Versão principal',
            alternateVersions: (q['alternateVersions'] as List? ?? const [])
                .map(
                  (version) => ImportedQuestionVersion.fromJson(
                    Map<String, dynamic>.from(version as Map),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
    if (questions.length > 500 ||
        questions.any(
          (q) =>
              q.options.length > 10 ||
              q.alternateVersions.length > 4 ||
              (q.correctIndex != null &&
                  (q.correctIndex! < 0 ||
                      q.correctIndex! >= q.options.length)) ||
              q.alternateVersions.any(
                (version) =>
                    version.options.length > 10 ||
                    (version.correctIndex != null &&
                        (version.correctIndex! < 0 ||
                            version.correctIndex! >= version.options.length)),
              ),
        )) {
      throw const FormatException('Estrutura de questões inválida.');
    }
    return LocalExam(
      id: data['id'] as String,
      title: data['title'] as String,
      category: data['category'] as String,
      source: data['source'] as String,
      durationMinutes: data['durationMinutes'] as int,
      year: data['year'] as int?,
      pendingPublication: data['pendingPublication'] == true,
      reviewIndex: ((data['reviewIndex'] as num?)?.toInt() ?? 0).clamp(
        0,
        questions.isEmpty ? 0 : questions.length - 1,
      ),
      questions: questions,
    );
  }
  // Editing the question set starts a distinct attempt instead of restoring
  // answers against different alternatives.
  String get attemptExamId =>
      '$id-${sha256.convert(utf8.encode(jsonEncode(questions.map((q) => {'statement': q.statement, 'options': q.options, 'correctIndex': q.correctIndex}).toList())))}';

  Exam get exam => Exam(
    id: attemptExamId,
    title: title,
    category: category,
    description: 'Prova privada salva neste aparelho.',
    author: source,
    durationMinutes: durationMinutes,
    attempts: 0,
    isLocal: true,
    questions: questions
        .asMap()
        .entries
        .map(
          (e) => Question(
            id: '$id-${e.key}',
            topic: category,
            statement: e.value.statement,
            options: e.value.options,
            correctIndex: e.value.correctIndex,
          ),
        )
        .toList(),
  );
}

class LocalExamStore {
  static const key = 'private_exams_v1';
  static Future<void>? _tail;
  static ExamPayloadStorage? storageOverride;
  final ExamPayloadStorage _storage;

  LocalExamStore({ExamPayloadStorage? storage})
    : _storage = storage ?? storageOverride ?? LocalExamPayloadStore();

  Future<List<LocalExam>> load() async {
    final tail = _tail;
    if (tail != null) await tail;
    final diskPayload = await _storage.read();
    final diskBackup = await _storage.readBackup();
    if (diskPayload != null) {
      return _decodeWithBackup(diskPayload, backup: diskBackup);
    }
    if (diskBackup != null) return _decodeWithBackup(diskBackup);

    final prefs = await SharedPreferences.getInstance();
    final legacyPayload = prefs.getString(key);
    if (legacyPayload == null) return [];
    final exams = _decodeWithBackup(
      legacyPayload,
      backup: prefs.getString('${key}_backup'),
    );
    final migratedPayload = jsonEncode(
      exams.map((exam) => exam.toJson()).toList(),
    );
    try {
      if (await _storage.migrate(migratedPayload)) {
        await prefs.remove(key);
        await prefs.remove('${key}_backup');
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[LOCAL_EXAM_MIGRATION] falhou; legado preservado: ${error.runtimeType}',
      );
      debugPrint('[LOCAL_EXAM_MIGRATION] stack: $stackTrace');
    }
    return exams;
  }

  List<LocalExam> _decodeWithBackup(String raw, {String? backup}) {
    try {
      return _decode(raw);
    } catch (error, stackTrace) {
      debugPrint(
        '[LOCAL_EXAM_READ] versão principal inválida: ${error.runtimeType}',
      );
      debugPrint('[LOCAL_EXAM_READ] stack: $stackTrace');
      if (backup != null) {
        try {
          return _decode(backup);
        } catch (backupError, backupStack) {
          debugPrint(
            '[LOCAL_EXAM_READ] backup inválido: ${backupError.runtimeType}',
          );
          debugPrint('[LOCAL_EXAM_READ] stack backup: $backupStack');
        }
      }
      throw const FormatException(
        'Não foi possível ler as provas locais. Os dados foram preservados.',
      );
    }
  }

  List<LocalExam> _decode(String raw) => (jsonDecode(raw) as List)
      .map((e) => LocalExam.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  Future<void> save(LocalExam exam) {
    // Snapshot before queueing: editing must not change an in-flight write.
    final snapshot = LocalExam.fromJson(
      jsonDecode(jsonEncode(exam.toJson())) as Map<String, dynamic>,
    );
    final previous = _tail;
    final operation = previous == null
        ? _saveSnapshot(snapshot)
        : previous.then((_) => _saveSnapshot(snapshot));
    final tail = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[LOCAL_SAVE_QUEUE] operação falhou: ${error.runtimeType}');
        debugPrint('[LOCAL_SAVE_QUEUE] stack: $stackTrace');
      },
    );
    _tail = tail;
    unawaited(
      tail.then((_) {
        if (identical(_tail, tail)) _tail = null;
      }),
    );
    return operation;
  }

  Future<void> _saveSnapshot(LocalExam snapshot) async {
    final diskPayload = await _storage.read();
    final diskBackup = await _storage.readBackup();
    final prefs =
        _storage.fileBacked && (diskPayload != null || diskBackup != null)
        ? null
        : await SharedPreferences.getInstance();
    final currentPayload =
        diskPayload ??
        prefs?.getString(key) ??
        diskBackup ??
        prefs?.getString('${key}_backup');
    final currentBackup = diskBackup ?? prefs?.getString('${key}_backup');
    final items = currentPayload == null
        ? <LocalExam>[]
        : _decodeWithBackup(currentPayload, backup: currentBackup);
    final validPrevious = jsonEncode(items.map((e) => e.toJson()).toList());
    items.removeWhere((e) => e.id == snapshot.id);
    items.add(snapshot);
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    final encodedBytes = utf8.encode(encoded).length;
    debugPrint(
      '[LOCAL_SAVE] questões=${snapshot.questions.length} bytes=$encodedBytes',
    );
    final saveOk = await _storage.write(encoded, backupPayload: validPrevious);
    if (!saveOk) {
      // Browser storage has no file-system implementation; retain the legacy
      // representation there, while keeping Android/iOS payloads in files.
      final preferences = prefs ?? await SharedPreferences.getInstance();
      final backupOk = await preferences.setString(
        '${key}_backup',
        validPrevious,
      );
      final preferencesOk = await preferences.setString(key, encoded);
      if (!backupOk || !preferencesOk) {
        throw StateError(
          'Não foi possível salvar no aparelho. Tente novamente.',
        );
      }
    } else {
      try {
        final preferences = prefs ?? await SharedPreferences.getInstance();
        await preferences.remove(key);
        await preferences.remove('${key}_backup');
      } catch (error, stackTrace) {
        debugPrint(
          '[LOCAL_EXAM_MIGRATION] arquivo salvo; limpeza de legado falhou: ${error.runtimeType}',
        );
        debugPrint('[LOCAL_EXAM_MIGRATION] stack: $stackTrace');
      }
    }
  }
}
