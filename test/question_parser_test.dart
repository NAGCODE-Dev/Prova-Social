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

  test('aceita numeração isolada usada em vestibulares', () {
    const source = '''
01
Qual alternativa descreve corretamente o fenômeno apresentado?
(A) Primeira possibilidade.
(B) Segunda possibilidade.
(C) Terceira possibilidade.
(D) Quarta possibilidade.
(E) Quinta possibilidade.

02.
Considere o texto e selecione a resposta adequada.
A) Opção um.
B) Opção dois.
C) Opção três.
D) Opção quatro.
E) Opção cinco.
''';

    final questions = const QuestionParser().parse(source);

    expect(questions, hasLength(2));
    expect(questions.first.options, hasLength(5));
    expect(questions.last.statement, contains('Considere o texto'));
  });

  test('aceita questão sem travessão após o número', () {
    const source = '''
QUESTÃO 12
Um enunciado suficientemente longo para ser reconhecido.
A) Alternativa A.
B) Alternativa B.
C) Alternativa C.
D) Alternativa D.
''';

    final questions = const QuestionParser().parse(source);

    expect(questions, hasLength(1));
    expect(questions.single.options, hasLength(4));
  });
}
