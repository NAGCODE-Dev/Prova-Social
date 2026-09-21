import '../../domain/models/exam.dart';

class AttemptSubmission {
  const AttemptSubmission({
    required this.clientAttemptId,
    required this.exam,
    required this.answers,
    required this.markedForReview,
    required this.durationSeconds,
    required this.finishedAt,
  });
  final String clientAttemptId;
  final Exam exam;
  final Map<int, int> answers;
  final Set<int> markedForReview;
  final int durationSeconds;
  final DateTime finishedAt;
}

class AttemptSubmissionException implements Exception {
  const AttemptSubmissionException({required this.message, required this.transient, this.cause});
  final String message;
  final bool transient;
  final Object? cause;
  @override
  String toString() => message;
}

abstract class AttemptSubmitter {
  Future<ExamResult> submit(AttemptSubmission submission);
}
