import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/question_parser.dart';

void main() {
  test('separa questões numeradas e alternativas', () {
    const text = '''
Questão 1. Qual é a capital do Brasil?
(A) São Paulo
(B) Brasília
(C) Recife
(D) Curitiba

2 - Quanto é dois mais dois?
A) 3
B) 4
C) 5
D) 6
''';

    final questions = const QuestionParser().parse(text);

    expect(questions, hasLength(2));
    expect(questions.first.statement, contains('capital'));
    expect(questions.first.options, hasLength(4));
    expect(questions.last.options[1], '4');
  });

  test('ignora blocos que não possuem alternativas', () {
    final questions = const QuestionParser().parse('Questão 1. Apenas texto');
    expect(questions, isEmpty);
  });
}
