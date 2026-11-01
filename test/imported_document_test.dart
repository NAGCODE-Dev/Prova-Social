import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/imported_document.dart';
import 'package:prova_social/core/import/question_parser.dart';
import 'package:prova_social/core/backend/local_exam_store.dart';
import 'package:prova_social/domain/models/exam.dart';

void main() {
  test('round trips page provenance, geometry, and question metadata', () {
    final source = ImportedDocument(
      metadata: const {
        'pageCount': 1,
        'languages': ['pt', 'en'],
      },
      pages: [
        ImportedDocumentPage(
          number: 1,
          text: 'Questão 1. Enunciado',
          nativeText: 'Questão 1. Enunciado',
          source: 'nativeText',
          previewBytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
          regions: [
            {
              'text': 'Questão 1.',
              'points': [
                {'x': 12.0, 'y': 18.0},
              ],
            },
          ],
        ),
      ],
      sections: const [
        ImportedSection(
          id: 'sec-1',
          title: 'Matemática',
          subject: 'Matemática',
          firstPage: 1,
          lastPage: 1,
          questionIds: ['q-1'],
        ),
      ],
      supportingMaterials: const [
        SupportingMaterial(
          id: 'mat-1',
          type: 'chart',
          questionId: 'q-1',
          page: 1,
          text: 'y = x + 1',
        ),
      ],
      questions: [
        ImportedQuestion(
          id: 'q-1',
          statement: 'Enunciado',
          options: const ['A', 'B', 'C', 'D', 'E', 'F'],
          number: 1,
          sourcePage: 1,
          sourcePosition: 12,
          subject: 'Matemática',
          language: 'pt',
          supportingMaterialIds: ['mat-1'],
          fieldConfidence: const {'statement': .91},
          warnings: ['Verificar gráfico'],
          confidence: .91,
          warning: 'Verificar gráfico',
        ),
      ],
    );

    final exam = LocalExam(
      id: 'exam-1',
      title: 'Fixture',
      category: 'Prova',
      source: 'Banca',
      durationMinutes: 60,
      questions: source.questions,
      importedDocument: source,
    );
    final restoredExam = LocalExam.fromJson(
      Map<String, dynamic>.from(exam.toJson()),
    );
    final restored = restoredExam.importedDocument!;

    expect(restored.id, source.id);
    expect(restored.pages.single.regions.single['text'], 'Questão 1.');
    expect(restored.pages.single.previewBytes, [0xff, 0xd8, 0xff, 0xd9]);
    expect(restored.sections.single.questionIds, ['q-1']);
    expect(restored.supportingMaterials.single.type, 'chart');
    expect(restored.supportingMaterials.single.questionId, 'q-1');
    expect(restored.questions.single.id, 'q-1');
    expect(restored.questions.single.sourcePages, [1]);
    expect(restored.questions.single.options, hasLength(6));
    expect(restored.questions.single.fieldConfidence['statement'], .91);
    expect(restored.questions.single.supportingMaterialIds, ['mat-1']);
    final withoutQuestion = restored.copyWith(questions: []);
    expect(withoutQuestion.supportingMaterials, isEmpty);
  });

  test('keeps legacy question JSON readable and creates a stable ID', () {
    final restored = ImportedQuestion.fromJson({
      'statement': 'Questão antiga',
      'options': ['Sim', 'Não'],
      'number': 2,
    });

    expect(restored.id, startsWith('q-0-2-'));
    expect(restored.warning, isNull);
    expect(restored.options, ['Sim', 'Não']);
  });

  test(
    'downloaded exams reopen offline with stable question and media IDs',
    () {
      final exam = LocalExam(
        id: 'remote-exam-1',
        title: 'Prova baixada',
        category: 'Conhecimentos gerais',
        source: 'Banca',
        durationMinutes: 60,
        downloaded: true,
        sourceType: ExamSourceType.official,
        questions: [
          ImportedQuestion(
            id: 'remote-question-1',
            statement: 'Questão com figura?',
            options: const ['A', 'B'],
            sourcePages: [1],
            confidence: 1,
          ),
        ],
        importedDocument: ImportedDocument(
          metadata: const {'offlinePackage': true},
          pages: [
            ImportedDocumentPage(
              number: 1,
              text: '',
              mediaAssetId: 'asset-1',
              mediaObjectKey: 'owner/media/figure.jpg',
              mediaMimeType: 'image/jpeg',
              mediaSha256: 'a' * 64,
              mediaAltText: 'Figura da questão',
              previewBytes: Uint8List.fromList([1, 2, 3]),
            ),
          ],
          questions: const [],
        ),
      );
      final restored = LocalExam.fromJson(
        Map<String, dynamic>.from(exam.toJson()),
      );
      final model = restored.exam;

      expect(restored.downloaded, isTrue);
      expect(model.isLocal, isFalse);
      expect(model.id, 'remote-exam-1');
      expect(model.questions.single.id, 'remote-question-1');
      expect(model.questions.single.media.single.id, 'asset-1');
      expect(model.questions.single.media.single.localBytes, [1, 2, 3]);
    },
  );
}
