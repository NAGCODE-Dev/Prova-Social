import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:crypto/crypto.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/exam.dart';
import 'content_package_service.dart';
import 'local_exam_payload_store.dart';
import '../import/question_parser.dart';
import '../import/imported_document.dart';

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
    this.sourceUrl,
    this.pendingPublication = false,
    this.reviewIndex = 0,
    this.importedDocument,
    this.downloaded = false,
    this.sourceType = ExamSourceType.unverified,
  });
  final String id, title, category, source;
  final int durationMinutes;
  final int? year;
  final String? sourceUrl;
  final List<ImportedQuestion> questions;
  final bool pendingPublication;
  final int reviewIndex;
  final ImportedDocument? importedDocument;
  final bool downloaded;
  final ExamSourceType sourceType;
  int get offlineImageBytes =>
      importedDocument?.pages.fold<int>(
        0,
        (total, page) => total + (page.previewBytes?.length ?? 0),
      ) ??
      0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'source': source,
    'sourceUrl': sourceUrl,
    'durationMinutes': durationMinutes,
    'year': year,
    'pendingPublication': pendingPublication,
    'downloaded': downloaded,
    'sourceType': sourceType.name,
    'reviewIndex': reviewIndex,
    if (importedDocument != null)
      'importedDocument': importedDocument!.toJson(),
    'questions': questions
        .asMap()
        .entries
        .map((entry) => entry.value.toJson(entry.key))
        .toList(),
  };
  factory LocalExam.fromJson(Map<String, dynamic> data) {
    final questions = (data['questions'] as List)
        .map(
          (q) => ImportedQuestion.fromJson(Map<String, dynamic>.from(q as Map)),
        )
        .toList();
    if (questions.length > 500 ||
        questions.any(
          (q) =>
              q.options.length > 100 ||
              q.alternateVersions.length > 4 ||
              (q.correctIndex != null &&
                  (q.correctIndex! < 0 ||
                      q.correctIndex! >= q.options.length)) ||
              q.alternateVersions.any(
                (version) =>
                    version.options.length > 100 ||
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
      sourceUrl: data['sourceUrl'] as String?,
      durationMinutes: data['durationMinutes'] as int,
      year: data['year'] as int?,
      pendingPublication: data['pendingPublication'] == true,
      downloaded: data['downloaded'] == true,
      sourceType: ExamSourceType.fromDatabase(data['sourceType']),
      reviewIndex: ((data['reviewIndex'] as num?)?.toInt() ?? 0).clamp(
        0,
        questions.isEmpty ? 0 : questions.length - 1,
      ),
      questions: questions,
      importedDocument: data['importedDocument'] is Map
          ? ImportedDocument.fromJson(
              Map<String, dynamic>.from(data['importedDocument'] as Map),
            )
          : null,
    );
  }
  // Editing the question set starts a distinct attempt instead of restoring
  // answers against different alternatives.
  String get attemptExamId =>
      '$id-${sha256.convert(utf8.encode(jsonEncode(questions.map((q) => {'statement': q.statement, 'options': q.options, 'correctIndex': q.correctIndex}).toList())))}';

  Exam get exam => Exam(
    id: downloaded ? id : attemptExamId,
    sourceUrl: sourceUrl,
    title: title,
    category: category,
    description: 'Prova privada salva neste aparelho.',
    author: source,
    sourceType: sourceType,
    durationMinutes: durationMinutes,
    attempts: 0,
    isLocal: !downloaded,
    questions: questions
        .asMap()
        .entries
        .map(
          (e) => Question(
            id: downloaded ? e.value.id : '$id-${e.key}',
            topic: category,
            statement: e.value.statement,
            options: e.value.options,
            correctIndex: e.value.correctIndex,
            media: [
              if (downloaded && importedDocument != null)
                for (final number in e.value.sourcePages)
                  for (final page in importedDocument!.pages)
                    if (page.number == number && page.previewBytes != null)
                      QuestionMedia(
                        id: page.mediaAssetId ?? '$id-media-$number',
                        objectKey: page.mediaObjectKey ?? '',
                        mimeType: page.mediaMimeType ?? 'image/jpeg',
                        sha256: page.mediaSha256 ?? '',
                        altText: page.mediaAltText ?? '',
                        localBytes: page.previewBytes,
                      ),
            ],
          ),
        )
        .toList(),
  );
}

class ActiveAttemptDownloadException implements Exception {
  const ActiveAttemptDownloadException();

  @override
  String toString() =>
      'Conclua a tentativa ativa antes de remover as imagens offline.';
}

class LocalExamStore {
  static const key = 'private_exams_v1';
  static const _compressedPrefix = 'PSGZ1|';
  static final _packages = ContentPackageService();
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
    final migratedPayload = _encode(exams);
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

  List<LocalExam> _decode(String raw) {
    dynamic decoded;
    if (raw.startsWith(_compressedPrefix)) {
      final parts = raw.split('|');
      if (parts.length != 3 || parts[1].length != 64) {
        throw const FormatException('Pacote local inválido.');
      }
      final bytes = base64Decode(parts[2]);
      if (sha256.convert(bytes).toString() != parts[1]) {
        throw const FormatException('Integridade do pacote local inválida.');
      }
      decoded = _packages.open(bytes)['exams'];
    } else {
      // Read existing plain JSON libraries and upgrade them on the next save.
      decoded = jsonDecode(raw);
    }
    if (decoded is! List) {
      throw const FormatException('Biblioteca local inválida.');
    }
    return decoded
        .map((e) => LocalExam.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  String _encode(Iterable<LocalExam> exams) {
    final values = exams.map((exam) => exam.toJson()).toList(growable: false);
    final json = jsonEncode(values);
    final package = _packages.create({'schemaVersion': 1, 'exams': values});
    final compressed =
        '$_compressedPrefix${package.sha256}|${base64Encode(package.bytes)}';
    return compressed.length < json.length ? compressed : json;
  }

  Future<void> save(LocalExam exam) {
    // Snapshot before queueing: editing must not change an in-flight write.
    final snapshot = LocalExam.fromJson(
      jsonDecode(jsonEncode(exam.toJson())) as Map<String, dynamic>,
    );
    return _serialize(() => _saveSnapshot(snapshot), 'LOCAL_SAVE_QUEUE');
  }

  Future<bool> removeDownloaded(
    String id, {
    Set<String> activeExamIds = const {},
  }) => _serialize(
    () => _removeDownloaded(id, activeExamIds: activeExamIds),
    'LOCAL_REMOVE_QUEUE',
  );

  Future<T> _serialize<T>(Future<T> Function() operation, String logTag) {
    final previous = _tail;
    final running = previous == null
        ? operation()
        : previous.then((_) => operation());
    final tail = running.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        if (error is ActiveAttemptDownloadException) return;
        debugPrint('[$logTag] operação falhou: ${error.runtimeType}');
        debugPrint('[$logTag] stack: $stackTrace');
      },
    );
    _tail = tail;
    unawaited(
      tail.then((_) {
        if (identical(_tail, tail)) _tail = null;
      }),
    );
    return running;
  }

  Future<bool> _removeDownloaded(
    String id, {
    required Set<String> activeExamIds,
  }) async {
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
    if (currentPayload == null) return false;
    final currentBackup = diskBackup ?? prefs?.getString('${key}_backup');
    final items = _decodeWithBackup(currentPayload, backup: currentBackup);
    final target = items.where((exam) => exam.id == id).firstOrNull;
    if (target == null || !target.downloaded) return false;
    if (activeExamIds.contains(id)) {
      throw const ActiveAttemptDownloadException();
    }

    final validPrevious = _encode(items);
    items.removeWhere((exam) => exam.id == id && exam.downloaded);
    final encoded = _encode(items);
    final saveOk = await _storage.write(encoded, backupPayload: validPrevious);
    if (!saveOk) {
      final preferences = prefs ?? await SharedPreferences.getInstance();
      final backupOk = await preferences.setString(
        '${key}_backup',
        validPrevious,
      );
      final preferencesOk = await preferences.setString(key, encoded);
      if (!backupOk || !preferencesOk) {
        throw StateError(
          'Não foi possível remover o download do aparelho. Tente novamente.',
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
    return true;
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
    final validPrevious = _encode(items);
    items.removeWhere((e) => e.id == snapshot.id);
    items.add(snapshot);
    final rawBytes = utf8
        .encode(jsonEncode(items.map((e) => e.toJson()).toList()))
        .length;
    final encoded = _encode(items);
    final encodedBytes = utf8.encode(encoded).length;
    debugPrint(
      '[LOCAL_SAVE] questões=${snapshot.questions.length} armazenado=$encodedBytes json=$rawBytes',
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
