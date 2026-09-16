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
  });

  final String id;
  final String category;
  final String title;
  final String description;
  final String author;
  final int durationMinutes;
  final int attempts;
  final List<Question> questions;
}

class Question {
  const Question({
    this.id = '',
    required this.topic,
    required this.statement,
    required this.options,
    required this.correctIndex,
  });

  final String id;
  final String topic;
  final String statement;
  final List<String> options;
  final int correctIndex;
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
      .where((index) => answers[index] == exam.questions[index].correctIndex)
      .length;

  int get scorePercent => (correct / exam.questions.length * 100).round();

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
            'isCorrect': selected == exam.questions[index].correctIndex,
            'markedForReview': markedForReview.contains(index),
          };
        }),
      };
}
