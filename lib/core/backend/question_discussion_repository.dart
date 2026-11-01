import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class QuestionComment {
  const QuestionComment({
    required this.id,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String authorName;
  final String body;
  final DateTime createdAt;
}

class TopicFollow {
  const TopicFollow({required this.topicId, required this.isFollowing});

  final int topicId;
  final bool isFollowing;
}

class QuestionDiscussionRepository {
  QuestionDiscussionRepository({
    SupabaseClient? client,
    String? Function()? currentUserId,
  }) : _client = client ?? Supabase.instance.client,
       _currentUserId = currentUserId ?? (() => _clientUserId(client));

  final SupabaseClient _client;
  final String? Function() _currentUserId;

  static String? _clientUserId(SupabaseClient? client) =>
      (client ?? Supabase.instance.client).auth.currentUser?.id;

  Future<List<QuestionComment>> comments(String questionId) async {
    final rows = await _client
        .from('question_comments')
        .select(
          'id,body,created_at,profiles!question_comments_author_id_fkey(display_name)',
        )
        .eq('question_id', questionId)
        .eq('status', 'visible')
        .order('created_at', ascending: true)
        .limit(100)
        .timeout(const Duration(seconds: 15));
    return List<Map<String, dynamic>>.from(rows)
        .map((row) {
          final profile = row['profiles'];
          final name = profile is Map<String, dynamic>
              ? profile['display_name'] as String?
              : null;
          return QuestionComment(
            id: row['id'] as String,
            authorName: name?.trim().isNotEmpty == true
                ? name!.trim()
                : 'Estudante',
            body: row['body'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
          );
        })
        .toList(growable: false);
  }

  Future<void> addComment(String questionId, String body) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw const AuthException('Entre na sua conta para comentar.');
    }
    final normalizedBody = body.trim();
    if (normalizedBody.isEmpty || normalizedBody.length > 2000) {
      throw ArgumentError.value(body, 'body', 'Use de 1 a 2000 caracteres.');
    }
    await _client
        .from('question_comments')
        .insert({
          'question_id': questionId,
          'author_id': userId,
          'body': normalizedBody,
          'status': 'visible',
        })
        .timeout(const Duration(seconds: 15));
  }

  Future<TopicFollow?> topicFollow(String topicName) async {
    final row = await _findTopic(topicName);
    if (row == null) return null;
    final topicId = (row['id'] as num).toInt();
    final userId = _currentUserId();
    if (userId == null) {
      return TopicFollow(topicId: topicId, isFollowing: false);
    }
    final follow = await _client
        .from('topic_follows')
        .select('topic_id')
        .eq('user_id', userId)
        .eq('topic_id', topicId)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    return TopicFollow(topicId: topicId, isFollowing: follow != null);
  }

  Future<void> setTopicFollow(String topicName, {required bool follow}) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw const AuthException('Entre na sua conta para acompanhar assuntos.');
    }
    final topic = await _findTopic(topicName);
    if (topic == null) {
      throw StateError('Este assunto não possui um tópico cadastrado.');
    }
    final topicId = (topic['id'] as num).toInt();
    if (follow) {
      await _client
          .from('topic_follows')
          .insert({'user_id': userId, 'topic_id': topicId})
          .timeout(const Duration(seconds: 15));
    } else {
      await _client
          .from('topic_follows')
          .delete()
          .eq('user_id', userId)
          .eq('topic_id', topicId)
          .timeout(const Duration(seconds: 15));
    }
  }

  Future<Map<String, dynamic>?> _findTopic(String name) => _client
      .from('topics')
      .select('id')
      .eq('name', name.trim())
      .maybeSingle()
      .timeout(const Duration(seconds: 15));
}
