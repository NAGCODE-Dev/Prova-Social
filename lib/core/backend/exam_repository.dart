import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/exam.dart';

class ExamRepository {
  ExamRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> publishedExams() async {
    final rows = await _client
        .from('exams')
        .select('id,title,description,category,source_name,source_type,year,duration_minutes,attempts_count,created_at')
        .eq('status', 'published')
        .eq('is_public', true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> questions(String examId) async {
    final rows = await _client
        .from('questions')
        .select('id,exam_id,position,topic,statement,options,correct_index,created_at')
        .eq('exam_id', examId)
        .order('position');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Exam>> publishedExamModels() async {
    final rows = await publishedExams();
    return Future.wait(rows.map((row) async {
      final questionRows = await questions(row['id'] as String);
      return Exam(
        id: row['id'] as String,
        category: row['category'] as String,
        title: row['title'] as String,
        description: row['description'] as String,
        author: (row['source_name'] as String?) ?? 'Comunidade',
        durationMinutes: row['duration_minutes'] as int,
        attempts: row['attempts_count'] as int,
        questions: questionRows.map((question) {
          final rawOptions = List<dynamic>.from(question['options'] as List);
          return Question(
            id: question['id'] as String,
            topic: (question['topic'] as String?) ?? 'Geral',
            statement: question['statement'] as String,
            options: rawOptions.map((option) => option is Map ? (option['text'] ?? '').toString() : option.toString()).toList(),
            correctIndex: question['correct_index'] as int,
          );
        }).toList(),
      );
    }));
  }

  Future<Set<String>> savedExamIds() async {
    final user = _client.auth.currentUser;
    if (user == null) return {};
    final rows = await _client.from('favorites').select('exam_id').eq('user_id', user.id);
    return List<Map<String, dynamic>>.from(rows).map((row) => row['exam_id'] as String).toSet();
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
