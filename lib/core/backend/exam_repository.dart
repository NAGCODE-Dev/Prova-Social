import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/exam.dart';

class ExamRepository {
  ExamRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> publishedExams() async {
    final rows = await _client
        .from('exams')
        .select(
          'id,title,description,category,source_name,source_type,source_url,year,duration_minutes,attempts_count,created_at',
        )
        .eq('status', 'published')
        .eq('is_public', true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> questions(String examId) async {
    final rows = await _client
        .from('questions')
        .select('id,exam_id,position,topic,statement,options,created_at')
        .eq('exam_id', examId)
        .order('position');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Exam>> publishedExamModels() async {
    final rows = await publishedExams();
    return Future.wait(
      rows.map((row) async {
        final questionRows = await questions(row['id'] as String);
        return mapPublishedExam(row, questionRows);
      }),
    );
  }

  /// Separate ilike filters avoid interpolating input into PostgREST OR syntax.
  Future<List<Exam>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return [];
    final pattern =
        '%${value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    final groups = await Future.wait([
      for (final field in ['title', 'description', 'category', 'source_name'])
        _client
            .from('exams')
            .select()
            .eq('status', 'published')
            .eq('is_public', true)
            .ilike(field, pattern)
            .order('created_at', ascending: false)
            .limit(50),
    ]).timeout(const Duration(seconds: 15));
    final rows = <String, Map<String, dynamic>>{};
    for (final group in groups) {
      for (final row in group) {
        rows[row['id'] as String] = row;
      }
    }
    final topics = await _client
        .from('questions')
        .select('exams!inner(*)')
        .eq('exams.status', 'published')
        .eq('exams.is_public', true)
        .ilike('topic', pattern)
        .limit(50)
        .timeout(const Duration(seconds: 15));
    for (final topic in topics) {
      final row = Map<String, dynamic>.from(topic['exams'] as Map);
      rows[row['id'] as String] = row;
    }
    return Future.wait(
      rows.values.map(
        (row) async =>
            mapPublishedExam(row, await questions(row['id'] as String)),
      ),
    ).timeout(const Duration(seconds: 15));
  }

  static Exam mapPublishedExam(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> questionRows,
  ) => Exam(
    id: row['id'] as String,
    category: row['category'] as String,
    title: row['title'] as String,
    description: row['description'] as String,
    author: (row['source_name'] as String?)?.trim().isNotEmpty == true
        ? (row['source_name'] as String).trim()
        : 'Fonte não informada',
    durationMinutes: row['duration_minutes'] as int,
    attempts: row['attempts_count'] as int,
    sourceType: ExamSourceType.fromDatabase(row['source_type']),
    sourceUrl: row['source_url'] is String ? row['source_url'] as String : null,
    questions: questionRows.map((question) {
      final rawOptions = List<dynamic>.from(question['options'] as List);
      return Question(
        id: question['id'] as String,
        topic: (question['topic'] as String?) ?? 'Geral',
        statement: question['statement'] as String,
        options: rawOptions
            .map(
              (option) => option is Map
                  ? (option['text'] ?? '').toString()
                  : option.toString(),
            )
            .toList(),
        correctIndex: null,
      );
    }).toList(),
  );

  Future<Set<String>> savedExamIds() async {
    final user = _client.auth.currentUser;
    if (user == null) return {};
    final rows = await _client
        .from('favorites')
        .select('exam_id')
        .eq('user_id', user.id);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map((row) => row['exam_id'] as String).toSet();
  }

  Future<void> saveExam(String examId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Faça login para salvar provas.');
    }
    await _client.from('favorites').upsert({
      'user_id': user.id,
      'exam_id': examId,
    });
  }

  Future<void> removeSavedExam(String examId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('favorites')
        .delete()
        .eq('user_id', user.id)
        .eq('exam_id', examId);
  }
}
