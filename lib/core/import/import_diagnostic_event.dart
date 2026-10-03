import 'package:crypto/crypto.dart';

import 'pdf_text_extractor.dart';
import 'question_parser.dart';

enum ImportFailureCode {
  unknownStructure,
  unreadablePage,
  inconsistentNumbering,
  uncertainQuestionStructure,
}

class ImportDiagnosticEvent {
  const ImportDiagnosticEvent({
    required this.parserVersion,
    required this.sourceType,
    required this.documentType,
    required this.failure,
    required this.pattern,
    required this.patternFingerprint,
    required this.confidence,
    required this.needsReview,
    this.regexRule,
  });

  static const currentParserVersion = 'pacer-v3';

  final String parserVersion;
  final String sourceType;
  final String documentType;
  final ImportFailureCode failure;
  final String pattern;
  final String patternFingerprint;
  final double? confidence;
  final bool needsReview;
  final String? regexRule;

  // This payload is structural only. The import flow must never transmit it;
  // any later telemetry upload requires an explicit, separately implemented
  // consent flow.
  Map<String, Object?> toJson() => {
    'parser_version': parserVersion,
    'source_type': sourceType,
    'document_type': documentType,
    'failure': failure.name,
    'pattern': pattern,
    'pattern_fingerprint': patternFingerprint,
    'confidence': confidence,
    'needs_review': needsReview,
    if (regexRule != null) 'regex_rule': regexRule,
  };

  static List<ImportDiagnosticEvent> collect({
    required PdfExtractionResult extraction,
    required List<ImportedQuestion> questions,
    required int numberingIssues,
    required int questionsNeedingReview,
    required double? parserConfidence,
  }) {
    final failures = <ImportFailureCode>[];
    if (questions.isEmpty &&
        extraction.text.trim().length >=
            PdfTextExtractor.minimumNativeTextLength) {
      failures.add(ImportFailureCode.unknownStructure);
    }
    if (extraction.unreadablePages > 0) {
      failures.add(ImportFailureCode.unreadablePage);
    }
    if (numberingIssues > 0) {
      failures.add(ImportFailureCode.inconsistentNumbering);
    }
    if (questionsNeedingReview > 0) {
      failures.add(ImportFailureCode.uncertainQuestionStructure);
    }
    if (failures.isEmpty) return const [];

    final structure = _structuralSignature(extraction);
    return List.unmodifiable([
      for (final failure in failures)
        ImportDiagnosticEvent(
          parserVersion: currentParserVersion,
          sourceType: 'private',
          documentType: 'exam',
          failure: failure,
          pattern: _patternId(failure),
          patternFingerprint: _fingerprint(failure, structure),
          confidence: parserConfidence,
          needsReview: true,
        ),
    ]);
  }

  static String _patternId(ImportFailureCode failure) => switch (failure) {
    ImportFailureCode.unknownStructure => 'UNKNOWN_STRUCTURE_V1',
    ImportFailureCode.unreadablePage => 'UNREADABLE_PAGE_V1',
    ImportFailureCode.inconsistentNumbering => 'QUESTION_SEQUENCE_V1',
    ImportFailureCode.uncertainQuestionStructure => 'QUESTION_STRUCTURE_V1',
  };

  static String _structuralSignature(PdfExtractionResult extraction) {
    final signature = StringBuffer();
    var remainingLines = 256;
    for (final page in extraction.pages) {
      signature.write('|P|');
      for (final line in page.text.split('\n')) {
        if (remainingLines == 0) break;
        final token = _lineType(line);
        if (token == null) continue;
        signature.write(token);
        remainingLines--;
      }
      if (remainingLines == 0) break;
    }
    return signature.toString();
  }

  static String? _lineType(String line) {
    final value = line.trim();
    if (value.isEmpty) return null;
    if (RegExp(
      r'^(?:quest(?:ão|ao)\s*(?:n[º°.]?\s*)?\d{1,4}|q\s*\d{1,4}|\d{1,4}\s*[ªº°]?\s*(?:quest(?:ão|ao))?)[\s.:)\-–—]*',
      caseSensitive: false,
    ).hasMatch(value)) {
      return 'Q;';
    }
    if (RegExp(
      r'^(?:\([A-E]\)|\[[A-E]\]|[A-E])\s*[.):\-–—]?\s+',
      caseSensitive: false,
    ).hasMatch(value)) {
      return 'O;';
    }
    if (RegExp(r'^\d{1,4}[.)]?\s*$').hasMatch(value)) return 'N;';
    return 'T;';
  }

  static String _fingerprint(
    ImportFailureCode failure,
    String structuralSignature,
  ) => sha256
      .convert(
        '$currentParserVersion|${failure.name}|$structuralSignature'.codeUnits,
      )
      .toString();
}
