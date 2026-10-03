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
    required this.unreadablePages,
    required this.numberingIssues,
    required this.diagnostics,
    required this.reasons,
  });

  final ImportQualityStatus status;
  final double? parserConfidence;
  final double? ocrConfidence;
  final int questionsNeedingReview;
  final int unreadablePages;
  final int numberingIssues;
  final List<ImportDiagnosticEvent> diagnostics;
  final List<String> reasons;
}

/// Decides whether the extraction can be reviewed, needs a retry, or has no
/// structural warning. A GOOD result still requires a person to review it.
class ImportQualityGate {
  const ImportQualityGate({this.reviewConfidenceThreshold = .85});

  final double reviewConfidenceThreshold;

  ImportQualityAssessment assess(
    PdfExtractionResult extraction,
    List<ImportedQuestion> questions,
  ) {
    final unreadablePages = extraction.unreadablePages;
    final ocrScores = extraction.pages
        .where((page) => page.source == PdfPageTextSource.onDeviceOcr)
        .map((page) => page.confidence)
        .whereType<double>()
        .where((score) => score.isFinite)
        .map((score) => score.clamp(0, 1).toDouble())
        .toList(growable: false);
    final parserConfidence = questions.isEmpty
        ? null
        : questions
                  .map((question) => question.confidence)
                  .reduce((a, b) => a + b) /
              questions.length;
    final ocrConfidence = ocrScores.isEmpty
        ? null
        : ocrScores.reduce((a, b) => a + b) / ocrScores.length;
    final questionsNeedingReview = questions
        .where(
          (question) =>
              question.confidence < reviewConfidenceThreshold ||
              question.warning != null,
        )
        .length;
    final numberingIssues = _countNumberingIssues(questions);
    final reasons = <String>[];
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
        continue;
      }
      if (previousNumber != null && number != previousNumber + 1) {
        issues++;
      }
      previousNumber = number;
    }
    return issues;
  }
}
