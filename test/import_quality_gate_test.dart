import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/import_diagnostic_event.dart';
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

ImportedQuestion question({
  double confidence = .95,
  String? warning,
  int? number,
}) => ImportedQuestion(
  statement: 'A question with enough text?',
  options: const ['First option', 'Second option'],
  confidence: confidence,
  warning: warning,
  number: number,
);

void main() {
  const gate = ImportQualityGate();

  test('marks clear structured extraction as good, still reviewable', () {
    final result = gate.assess(extraction(), [question()]);
    expect(result.status, ImportQualityStatus.good);
    expect(result.parserConfidence, .95);
    expect(result.questionsNeedingReview, 0);
    expect(result.numberingIssues, 0);
    expect(result.diagnostics, isEmpty);
  });

  test('routes gaps and out-of-order numbering to human review', () {
    final result = gate.assess(extraction(), [
      question(number: 1),
      question(number: 3),
      question(number: 2),
    ]);

    expect(result.status, ImportQualityStatus.review);
    expect(result.numberingIssues, 2);
    expect(result.reasons.single, contains('Sequência numérica inconsistente'));
    expect(
      result.diagnostics.map((event) => event.failure),
      contains(ImportFailureCode.inconsistentNumbering),
    );
  });

  test('creates a content-free diagnostic fingerprint for unknown structure', () {
    const privateText = '''
Material reservado para revisão interna.
Este texto confidencial não deve ser enviado.
Outra linha de conteúdo privado para diagnóstico.
''';
    const differentTextWithSameShape = '''
Documento protegido para avaliação manual.
Este conteúdo restrito permanece no dispositivo.
Mais uma linha particular para o diagnóstico.
''';

    ImportQualityAssessment assess(String text) => gate.assess(
      extraction(text: text),
      const [],
    );

    final first = assess(privateText).diagnostics.single;
    final second = assess(differentTextWithSameShape).diagnostics.single;
    final payload = first.toJson();

    expect(first.failure, ImportFailureCode.unknownStructure);
    expect(first.sourceType, 'private');
    expect(first.pattern, 'UNKNOWN_STRUCTURE_V1');
    expect(first.patternFingerprint, matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(first.patternFingerprint, second.patternFingerprint);
    expect(first.needsReview, isTrue);
    expect(payload, isNot(contains(privateText)));
    expect(payload.values, isNot(contains(privateText)));
    expect(payload.values, isNot(contains('reservado')));
    expect(payload.values, isNot(contains('confidencial')));
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
