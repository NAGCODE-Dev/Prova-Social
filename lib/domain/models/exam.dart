class Exam {
  const Exam({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.author,
    required this.durationMinutes,
    required this.attempts,
    required this.questions,
    this.sourceType = ExamSourceType.unverified,
    this.sourceUrl,
    this.isLocal = false,
  });

  final bool isLocal;
  final String id;
  final String category;
  final String title;
  final String description;
  final String author;
  final int durationMinutes;
  final int attempts;
  final List<Question> questions;
  final ExamSourceType sourceType;
  final String? sourceUrl;

  Uri? get safeSourceUrl {
    final uri = Uri.tryParse(sourceUrl?.trim() ?? '');
    return uri?.scheme == 'https' && uri!.host.isNotEmpty ? uri : null;
  }

  Exam copyWith({List<Question>? questions}) => Exam(
    id: id,
    isLocal: isLocal,
    category: category,
    title: title,
    description: description,
    author: author,
    durationMinutes: durationMinutes,
    attempts: attempts,
    questions: questions ?? this.questions,
    sourceType: sourceType,
    sourceUrl: sourceUrl,
  );
}

enum ExamSourceType {
  official,
  community,
  unverified;

  static ExamSourceType fromDatabase(Object? value) => switch (value) {
    'official' => official,
    'community' => community,
    _ => unverified,
  };
}

class Question {
  const Question({
    this.id = '',
    required this.topic,
    required this.statement,
    required this.options,
    this.correctIndex,
  });

  final String id;
  final String topic;
  final String statement;
  final List<String> options;
  final int? correctIndex;

  Question copyWith({int? correctIndex}) => Question(
    id: id,
    topic: topic,
    statement: statement,
    options: options,
    correctIndex: correctIndex ?? this.correctIndex,
  );
}

class ExamResult {
  const ExamResult({
    required this.exam,
    required this.answers,
    required this.markedForReview,
    required this.durationSeconds,
    required this.finishedAt,
  });

  final Exam exam;
  final Map<int, int> answers;
  final Set<int> markedForReview;
  final int durationSeconds;
  final DateTime finishedAt;

  int get correct => List.generate(exam.questions.length, (index) => index)
      .where(
        (index) =>
            exam.questions[index].correctIndex != null &&
            answers[index] == exam.questions[index].correctIndex,
      )
      .length;

  int get scorePercent => exam.questions.isEmpty
      ? 0
      : (correct / exam.questions.length * 100).round();

  List<int> get wrongQuestionIndices => [
    for (var index = 0; index < exam.questions.length; index++)
      if (answers[index] != null &&
          exam.questions[index].correctIndex != null &&
          answers[index] != exam.questions[index].correctIndex)
        index,
  ];

  int get unanswered => [
    for (var index = 0; index < exam.questions.length; index++)
      if (answers[index] == null) index,
  ].length;

  Map<String, ({int correct, int total})> get byTopic {
    final totals = <String, ({int correct, int total})>{};
    for (var index = 0; index < exam.questions.length; index++) {
      final question = exam.questions[index];
      if (question.topic.trim().isEmpty || question.correctIndex == null) {
        continue;
      }
      final previous = totals[question.topic] ?? (correct: 0, total: 0);
      totals[question.topic] = (
        correct:
            previous.correct +
            (answers[index] == question.correctIndex ? 1 : 0),
        total: previous.total + 1,
      );
    }
    return totals;
  }

  Map<String, Object?> toJson() => {
    'examId': exam.id,
    'examTitle': exam.title,
    'finishedAt': finishedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'total': exam.questions.length,
    'correct': correct,
    'scorePercent': scorePercent,
    'answers': List.generate(exam.questions.length, (index) {
      final selected = answers[index];
      return {
        'question': index + 1,
        'selected': selected,
        'correct': exam.questions[index].correctIndex,
        'isCorrect':
            exam.questions[index].correctIndex != null &&
            selected == exam.questions[index].correctIndex,
        'markedForReview': markedForReview.contains(index),
      };
    }),
  };
}
