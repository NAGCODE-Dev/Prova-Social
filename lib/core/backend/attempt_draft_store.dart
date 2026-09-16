import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AttemptDraft {
  const AttemptDraft({
    required this.answers,
    required this.review,
    required this.current,
    required this.elapsedSeconds,
  });

  final Map<int, int> answers;
  final Set<int> review;
  final int current;
  final int elapsedSeconds;
}

class AttemptDraftStore {
  const AttemptDraftStore();

  String _key(String examId) => 'attempt_draft_v1_$examId';

  Future<void> save(String examId, AttemptDraft draft) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(examId), jsonEncode({
      'answers': draft.answers.map((key, value) => MapEntry('$key', value)),
      'review': draft.review.toList(),
      'current': draft.current,
      'elapsedSeconds': draft.elapsedSeconds,
    }));
  }

  Future<AttemptDraft?> load(String examId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(examId));
    if (raw == null) return null;
    final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final answers = Map<String, dynamic>.from(json['answers'] as Map);
    return AttemptDraft(
      answers: answers.map((key, value) => MapEntry(int.parse(key), value as int)),
      review: Set<int>.from(json['review'] as List),
      current: json['current'] as int,
      elapsedSeconds: json['elapsedSeconds'] as int,
    );
  }

  Future<void> clear(String examId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(examId));
  }
}
