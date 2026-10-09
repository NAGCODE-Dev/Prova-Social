import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/exam_metadata_suggester.dart';

void main() {
  test('suggests title and year from the first page header', () {
    final result = suggestExamMetadata(
      fileName: 'arquivo.pdf',
      firstPageText:
          'CONCURSO PÚBLICO 2024\nProva de Analista Judiciário\nQuestão 1',
    );

    expect(result.title, 'CONCURSO PÚBLICO 2024');
    expect(result.year, 2024);
  });

  test('falls back to a readable PDF filename', () {
    final result = suggestExamMetadata(
      fileName: 'enem-2023-caderno-amarelo.pdf',
      firstPageText: 'Página 1\nQuestão 1',
    );

    expect(result.title, 'enem 2023 caderno amarelo');
    expect(result.year, 2023);
  });
}
