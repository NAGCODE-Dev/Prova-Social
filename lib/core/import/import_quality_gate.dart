import 'pdf_text_extractor.dart';
import 'import_diagnostic_event.dart';
import 'question_parser.dart';

enum ImportQualityStatus { good, review, retry }

class ImportQualityAssessment {
  const ImportQualityAssessment({
    required this.status,
    required this.parserConfidence,
    required this.ocrConfidence,
    required this.questionsNeedingReview,
    required this.questionsWithVariants,
    required this.unreadablePages,
    required this.numberingIssues,
    required this.diagnostics,
    required this.reasons,
  });

  final ImportQualityStatus status;
  final double? parserConfidence;
  final double? ocrConfidence;
  final int questionsNeedingReview;
  final int questionsWithVariants;
  final int unreadablePages;
  final int numberingIssues;
  final List<ImportDiagnosticEvent> diagnostics;
  final List<String> reasons;
}

/// Decides whether the extraction can be reviewed, needs a retry, or has no
/// structural warning. Questions below the auto-validation threshold remain
/// explicitly reviewable in the import editor.
class ImportQualityGate {
  const ImportQualityGate({
    this.reviewConfidenceThreshold = autoValidatedQuestionConfidence,
  });

  final double reviewConfidenceThreshold;

  void markNumberingIssues(List<ImportedQuestion> questions) {
    final flagged = <int>{};
    int? previousNumber;
    int? previousIndex;
    for (var index = 0; index < questions.length; index++) {
      final number = questions[index].number;
      if (number == null) continue;
      if ((previousNumber == null && number != 1) ||
          (previousNumber != null && number != previousNumber + 1) ||
          number <= 0) {
        flagged.add(index);
        if (previousNumber != null && number <= previousNumber) {
          flagged.add(previousIndex!);
        }
      }
      previousNumber = number;
      previousIndex = index;
    }
    for (final index in flagged) {
      final question = questions[index];
      const warning =
          'Numeração fora de sequência; confira se há questão ausente, duplicada ou fora de ordem.';
      if (question.warning == null) {
        question.warning = warning;
      } else if (!question.warning!.contains(warning)) {
        question.warning = '${question.warning} $warning';
      }
      question.reviewState = QuestionReviewState.needsAttention;
    }
  }

  ImportQualityAssessment assess(
    PdfExtractionResult extraction,
    List<ImportedQuestion> questions,
  ) {
    final unreadablePages = extraction.unreadablePages;
    final confidenceThreshold = reviewConfidenceThreshold.isFinite
        ? reviewConfidenceThreshold.clamp(0, 1).toDouble()
        : autoValidatedQuestionConfidence;
    final ocrScores = extraction.pages
        .where((page) => page.source == PdfPageTextSource.onDeviceOcr)
        .map((page) => page.confidence)
        .whereType<double>()
        .where((score) => score.isFinite)
        .map((score) => score.clamp(0, 1).toDouble())
        .toList(growable: false);
    final questionScores = questions
        .map((question) => question.confidence)
        .where((score) => score.isFinite)
        .map((score) => score.clamp(0, 1).toDouble())
        .toList(growable: false);
    final parserConfidence = questionScores.isEmpty
        ? null
        : questionScores.reduce((a, b) => a + b) / questionScores.length;
    final ocrConfidence = ocrScores.isEmpty
        ? null
        : ocrScores.reduce((a, b) => a + b) / ocrScores.length;
    final questionsNeedingReview = questions
        .where(
          (question) =>
              !question.confidence.isFinite ||
              question.confidence < confidenceThreshold ||
              question.warning != null,
        )
        .length;
    final questionsWithVariants = questions
        .where((question) => question.alternateVersions.isNotEmpty)
        .length;
    final numberingIssues = _countNumberingIssues(questions);
    final reasons = <String>[];
    if (extraction.pageCount == 0) {
      reasons.add('Nenhuma página foi extraída do arquivo.');
    }
    if (unreadablePages > 0) {
      reasons.add('$unreadablePages página(s) sem texto suficiente.');
    }
    if (extraction.pagesWithWarnings > 0) {
      reasons.add(
        '${extraction.pagesWithWarnings} página(s) com aviso de OCR.',
      );
    }
    if (questionsNeedingReview > 0) {
      reasons.add(
        '$questionsNeedingReview questão(ões) com estrutura incerta.',
      );
    }
    if (numberingIssues > 0) {
      reasons.add(
        'Sequência numérica inconsistente em $numberingIssues ponto(s); '
        'verificar questões ausentes, duplicadas ou fora de ordem.',
      );
    }

    final status =
        extraction.pageCount == 0 ||
            questions.isEmpty ||
            (extraction.pageCount > 0 &&
                unreadablePages == extraction.pageCount)
        ? ImportQualityStatus.retry
        : reasons.isNotEmpty
        ? ImportQualityStatus.review
        : ImportQualityStatus.good;
    final diagnostics = ImportDiagnosticEvent.collect(
      extraction: extraction,
      questions: questions,
      numberingIssues: numberingIssues,
      questionsNeedingReview: questionsNeedingReview,
      parserConfidence: parserConfidence,
    );
    return ImportQualityAssessment(
      status: status,
      parserConfidence: parserConfidence,
      ocrConfidence: ocrConfidence,
      questionsNeedingReview: questionsNeedingReview,
      questionsWithVariants: questionsWithVariants,
      unreadablePages: unreadablePages,
      numberingIssues: numberingIssues,
      diagnostics: diagnostics,
      reasons: List.unmodifiable(reasons),
    );
  }

  int _countNumberingIssues(List<ImportedQuestion> questions) {
    var issues = 0;
    int? previousNumber;
    for (final question in questions) {
      final number = question.number;
      if (number == null) continue;
      if (number <= 0) {
        issues++;
        previousNumber = number;
        continue;
      }
      if (previousNumber == null && number != 1) {
        issues++;
      } else if (previousNumber != null && number != previousNumber + 1) {
        issues++;
      }
      previousNumber = number;
    }
    return issues;
  }
}
