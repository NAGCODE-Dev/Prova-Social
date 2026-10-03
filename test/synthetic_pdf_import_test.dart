import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/import_quality_gate.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';
import 'package:prova_social/core/import/question_parser.dart';

void main() {
  test(
    'imports all 80 original synthetic questions from a two-column PDF',
    () async {
      final pdf = await File(
        'test/fixtures/synthetic_two_column_80_questions.pdf',
      ).readAsBytes();
      final extraction = await const PdfTextExtractor().extract(
        pdf,
        sourceName: 'synthetic_two_column_80_questions.pdf',
      );
      final questions = const QuestionParser().parse(extraction.text);
      final quality = const ImportQualityGate().assess(extraction, questions);

      expect(extraction.pageCount, 8);
      expect(extraction.unreadablePages, 0);
      expect(questions, hasLength(80));
      expect(questions.map((question) => question.number), [
        for (var number = 1; number <= 80; number++) number,
      ]);
      expect(
        questions.every((question) => question.options.length == 5),
        isTrue,
      );
      expect(
        questions.every((question) => question.statement.contains('n =')),
        isTrue,
      );
      expect(questions.map((question) => question.options[2]), [
        for (var number = 1; number <= 80; number++)
          'Código ${(3 * number + 2).toString().padLeft(3, '0')}',
      ]);
      expect(quality.status, ImportQualityStatus.good);
      expect(quality.questionsNeedingReview, 0);
    },
  );
}
