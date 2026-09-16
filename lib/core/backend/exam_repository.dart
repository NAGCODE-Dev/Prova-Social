import 'package:supabase_flutter/supabase_flutter.dart';

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
        .select('id,exam_id,position,topic,statement,options,created_at')
        .eq('exam_id', examId)
        .order('position');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveExam(String examId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Faça login para salvar provas.');
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
