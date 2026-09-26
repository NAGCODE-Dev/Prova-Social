import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/exam.dart';
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
  });
  final String id, title, category, source;
  final int durationMinutes;
  final int? year;
  final List<ImportedQuestion> questions;
  final bool pendingPublication;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'source': source,
    'durationMinutes': durationMinutes,
    'year': year,
    'pendingPublication': pendingPublication,
    'questions': questions
        .map(
          (q) => {
            'statement': q.statement,
            'options': q.options,
            'correctIndex': q.correctIndex,
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
          ),
        )
        .toList();
    if (questions.length > 500 ||
        questions.any(
          (q) =>
              q.options.length > 10 ||
              (q.correctIndex != null &&
                  (q.correctIndex! < 0 || q.correctIndex! >= q.options.length)),
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
      questions: questions,
    );
  }
  // Editing the question set starts a distinct attempt instead of restoring
  // answers against different alternatives.
  String get attemptExamId =>
      '$id-${sha256.convert(utf8.encode(jsonEncode(toJson()['questions'])))}';

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
  static Future<void> _tail = Future.value();
  Future<List<LocalExam>> load() async {
    await _tail;
    return _read(await SharedPreferences.getInstance());
  }

  List<LocalExam> _read(SharedPreferences prefs) {
    final raw = prefs.getString(key);
    if (raw == null) return [];
    try {
      return _decode(raw);
    } catch (_) {
      final backup = prefs.getString('${key}_backup');
      if (backup != null) return _decode(backup);
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
    final operation = _tail.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final items = _read(prefs);
      final previous = jsonEncode(items.map((e) => e.toJson()).toList());
      items.removeWhere((e) => e.id == snapshot.id);
      items.add(snapshot);
      final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
      if (utf8.encode(encoded).length > 4 * 1024 * 1024) {
        throw StateError(
          'Limite local de 4 MB atingido. Exporte suas provas antes de continuar.',
        );
      }
      if (!await prefs.setString('${key}_backup', previous) ||
          !await prefs.setString(key, encoded)) {
        throw StateError(
          'Não foi possível salvar no aparelho. Tente novamente.',
        );
      }
    });
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }
}
