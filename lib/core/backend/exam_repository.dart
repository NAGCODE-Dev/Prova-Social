import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/exam.dart';

class ExamCatalogCursor {
  const ExamCatalogCursor({required this.createdAt, required this.id});

  final String createdAt;
  final String id;
}

class ExamCatalogPage {
  const ExamCatalogPage({
    required this.exams,
    required this.hasMore,
    this.nextCursor,
  });

  final List<Exam> exams;
  final bool hasMore;
  final ExamCatalogCursor? nextCursor;
}

class ExamRepository {
  ExamRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _examSelect =
      'id,title,description,category,source_name,source_type,source_url,year,'
      'duration_minutes,attempts_count,created_at,'
      'questions(id,exam_id,position,topic,statement,options,created_at)';

  Future<ExamCatalogPage> publishedExamPage({
    ExamCatalogCursor? after,
    int pageSize = 20,
  }) async {
    if (pageSize < 1 || pageSize > 100) {
      throw ArgumentError.value(
        pageSize,
        'pageSize',
        'Must be between 1 and 100.',
      );
    }

    var request = _client
        .from('exams')
        .select(_examSelect)
        .eq('status', 'published')
        .eq('is_public', true);
    if (after != null) {
      request = request.or(
        'created_at.lt.${after.createdAt},and('
        'created_at.eq.${after.createdAt},id.lt.${after.id})',
      );
    }
    final rows = List<Map<String, dynamic>>.from(
      await request
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .order('position', referencedTable: 'questions')
          .limit(pageSize + 1)
          .timeout(const Duration(seconds: 15)),
    );
    final hasMore = rows.length > pageSize;
    final pageRows = rows.take(pageSize).toList(growable: false);
    final exams = pageRows
        .map((row) => mapPublishedExam(row, _embeddedQuestions(row)))
        .toList(growable: false);
    final last = pageRows.isEmpty ? null : pageRows.last;
    return ExamCatalogPage(
      exams: exams,
      hasMore: hasMore,
      nextCursor: hasMore && last != null
          ? ExamCatalogCursor(
              createdAt: last['created_at'] as String,
              id: last['id'] as String,
            )
          : null,
    );
  }

  Future<List<Exam>> savedExamModels() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final rows = await _client
        .from('favorites')
        .select('exams($_examSelect)')
        .eq('user_id', user.id)
        .timeout(const Duration(seconds: 15));
    return List<Map<String, dynamic>>.from(rows)
        .map((favorite) => favorite['exams'])
        .whereType<Map>()
        .map((row) {
          final exam = Map<String, dynamic>.from(row);
          final nestedQuestions = _embeddedQuestions(exam);
          return mapPublishedExam(exam, nestedQuestions);
        })
        .toList(growable: false);
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
    final candidates = rows.values.toList()
      ..sort((first, second) {
        final firstDate = DateTime.tryParse(
          first['created_at'] as String? ?? '',
        );
        final secondDate = DateTime.tryParse(
          second['created_at'] as String? ?? '',
        );
        final byDate = (secondDate ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(firstDate ?? DateTime.fromMillisecondsSinceEpoch(0));
        return byDate == 0
            ? (second['id'] as String).compareTo(first['id'] as String)
            : byDate;
      });
    final selected = candidates.take(50).toList(growable: false);
    if (selected.isEmpty) return const [];
    final details = await _client
        .from('exams')
        .select(_examSelect)
        .inFilter('id', selected.map((row) => row['id'] as String).toList())
        .eq('status', 'published')
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .order('position', referencedTable: 'questions')
        .timeout(const Duration(seconds: 15));
    return List<Map<String, dynamic>>.from(details)
        .map((row) => mapPublishedExam(row, _embeddedQuestions(row)))
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _embeddedQuestions(
    Map<String, dynamic> row,
  ) => List<Map<String, dynamic>>.from(
    (row['questions'] as List<dynamic>? ?? const []).whereType<Map>(),
  );

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
    return List<Map<String, dynamic>>.from(rows)
        .map((row) => row['exam_id'] as String)
        .toSet();
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
