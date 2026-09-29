import 'pdf_text_extractor.dart';
import 'question_parser.dart';

enum ImportQualityStatus { good, review, retry }

class ImportQualityAssessment {
  const ImportQualityAssessment({
    required this.status,
    required this.parserConfidence,
    required this.ocrConfidence,
    required this.questionsNeedingReview,
    required this.unreadablePages,
    required this.reasons,
  });

  final ImportQualityStatus status;
  final double? parserConfidence;
  final double? ocrConfidence;
  final int questionsNeedingReview;
  final int unreadablePages;
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

    final status =
        questions.isEmpty ||
            (extraction.pageCount > 0 &&
                unreadablePages == extraction.pageCount)
        ? ImportQualityStatus.retry
        : reasons.isNotEmpty
        ? ImportQualityStatus.review
        : ImportQualityStatus.good;
    return ImportQualityAssessment(
      status: status,
      parserConfidence: parserConfidence,
      ocrConfidence: ocrConfidence,
      questionsNeedingReview: questionsNeedingReview,
      unreadablePages: unreadablePages,
      reasons: List.unmodifiable(reasons),
    );
  }
}
