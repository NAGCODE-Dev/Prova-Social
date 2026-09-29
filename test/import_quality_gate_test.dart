import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/import_quality_gate.dart';
import 'package:prova_social/core/import/ocr_router.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';
import 'package:prova_social/core/import/question_parser.dart';

PdfExtractionResult extraction({
  PdfPageTextSource source = PdfPageTextSource.nativeText,
  String text = 'A native page containing enough text to import.',
  double? confidence,
  String? warning,
}) => PdfExtractionResult(
  ocrAvailable: true,
  pages: [
    PdfPageExtraction(
      pageNumber: 1,
      nativeText: source == PdfPageTextSource.nativeText ? text : '',
      text: text,
      source: source,
      ocrAttempted: source == PdfPageTextSource.onDeviceOcr,
      route: source == PdfPageTextSource.nativeText
          ? OcrRoute.nativeText
          : source == PdfPageTextSource.onDeviceOcr
          ? OcrRoute.paddleOcr
          : OcrRoute.unavailable,
      routeReason: 'test',
      confidence: confidence,
      warning: warning,
    ),
  ],
);

ImportedQuestion question({double confidence = .95, String? warning}) =>
    ImportedQuestion(
      statement: 'A question with enough text?',
      options: const ['First option', 'Second option'],
      confidence: confidence,
      warning: warning,
    );

void main() {
  const gate = ImportQualityGate();

  test('marks clear structured extraction as good, still reviewable', () {
    final result = gate.assess(extraction(), [question()]);
    expect(result.status, ImportQualityStatus.good);
    expect(result.parserConfidence, .95);
    expect(result.questionsNeedingReview, 0);
  });

  test('routes low-confidence questions and OCR warnings to review', () {
    final result = gate.assess(
      extraction(
        source: PdfPageTextSource.onDeviceOcr,
        confidence: .61,
        warning: 'OCR incerto.',
      ),
      [question(confidence: .72, warning: 'Alternativas incertas.')],
    );
    expect(result.status, ImportQualityStatus.review);
    expect(result.ocrConfidence, .61);
    expect(result.questionsNeedingReview, 1);
    expect(result.reasons, hasLength(2));
  });

  test('requests retry when the parser finds no questions', () {
    final result = gate.assess(extraction(), const []);
    expect(result.status, ImportQualityStatus.retry);
    expect(result.parserConfidence, isNull);
  });
}
