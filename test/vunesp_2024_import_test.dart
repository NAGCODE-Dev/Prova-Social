import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:prova_social/core/import/imported_document.dart';
import 'package:prova_social/core/import/import_quality_gate.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';
import 'package:prova_social/core/import/question_parser.dart';

void main() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.path,
      );

  test('imports the user-provided 2024 VUNESP exam structurally', () async {
    final bytes = await File('test/fixtures/vunesp_2024_pm_sp.pdf')
        .readAsBytes();
    final extraction = await const PdfTextExtractor().extract(
      bytes,
      sourceName: 'vunesp_2024_pm_sp.pdf',
    );
    final questions = const QuestionParser().parsePages(
      extraction.pages.map((page) => page.text).toList(growable: false),
    );
    const qualityGate = ImportQualityGate();
    qualityGate.markNumberingIssues(questions);
    final quality = qualityGate.assess(extraction, questions);

    expect(extraction.pageCount, 32);
    expect(extraction.pagesWithText, 32);
    expect(extraction.ocrPages, 0);
    expect(extraction.unreadablePages, 0);
    expect(questions, hasLength(80));
    expect(questions.every((question) => question.sourcePage != null), isTrue);
    expect(questions.map((question) => question.number), [
      for (var number = 1; number <= 80; number++) number,
    ]);

    final byNumber = {
      for (final question in questions) question.number: question,
    };
    expect(byNumber[49]!.options, ['-19.', '-7.', '1.', '8.', '20.']);
    expect(byNumber[49]!.warning, isNull);
    expect([
      for (var number = 39; number <= 44; number++)
        byNumber[number]!.alternateVersions.single.label,
    ], everyElement('Espanhol'));
    expect(byNumber[39]!.versionLabel, 'Inglês');

    for (final number in [53, 54, 79, 80]) {
      expect(byNumber[number]!.options, ['', '', '', '', '']);
      expect(
        byNumber[number]!.warning,
        contains('conteúdo visual não foi extraído'),
      );
    }
    final questionVisualSources = associateQuestionVisualSources(questions);
    expect(questionVisualSources, hasLength(4));
    for (final number in [53, 54, 79, 80]) {
      final question = byNumber[number]!;
      final media = questionVisualSources.singleWhere(
        (item) => item.questionId == question.id,
      );
      expect(question.supportingMaterialIds, contains(media.id));
      expect(media.raw['sourcePages'], question.sourcePages);
      expect(media.id, startsWith('question-visual-${question.id}'));
    }
    expect(byNumber[80]!.statement, isNot(contains('Texto 1')));
    expect(byNumber[80]!.statement, isNot(contains('RASCUNHO')));
    expect(byNumber[80]!.statement, isNot(contains('CLASSIFICAÇÃO PERIÓDICA')));
    expect(byNumber[53]!.sourcePages, [19]);
    expect(byNumber[54]!.sourcePages, [20]);
    expect(byNumber[79]!.sourcePages, [28, 29]);
    expect(byNumber[80]!.sourcePages, [29]);
    expect(extraction.pages[29].text, contains('REDAÇÃO'));
    expect(extraction.pages[30].text, contains('RASCUNHO'));
    expect(extraction.pages[31].text, contains('CLASSIFICAÇÃO'));
    expect(extraction.pages[31].text, contains('ÓDICA'));
    expect(quality.status, ImportQualityStatus.review);
    expect(quality.questionsNeedingReview, 4);

    final questionPages = byNumber.values
        .where((question) => question.warning != null)
        .expand((question) => question.sourcePages)
        .toSet();
    final referencePages = extraction.pages
        .where((page) {
          final text = page.text.toUpperCase();
          return text.contains('CLASSIFICAÇÃO') &&
              !text.contains('NO FINAL DESTE CADERNO');
        })
        .map((page) => page.pageNumber)
        .toSet();
    if (extraction.pages.any(
      (page) =>
          page.text.toUpperCase().contains('NO FINAL DESTE CADERNO') &&
          page.text.toUpperCase().contains('CLASSIFICAÇÃO'),
    )) {
      referencePages.add(extraction.pageCount);
    }
    final previews = await const PdfTextExtractor().renderPages(bytes, {
      ...questionPages,
      ...referencePages,
    });
    expect(questionPages, {19, 20, 28, 29});
    expect(referencePages, {32});
    expect(previews.keys.toSet(), {19, 20, 28, 29, 32});
    final totalPreviewBytes = previews.values.fold<int>(
      0,
      (sum, bytes) => sum + bytes.length,
    );
    expect(totalPreviewBytes, lessThan(600000));
    for (final preview in previews.values) {
      expect(preview.length, greaterThan(1000));
      expect(preview[0], 0xff);
      expect(preview[1], 0xd8);
      final decoded = image.decodeJpg(preview);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(1200));
      expect(decoded.height, lessThanOrEqualTo(1200));
    }
  });
}
