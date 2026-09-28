import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/question_parser.dart';

void main() {
  const parser = QuestionParser();

  test('separa múltipla escolha com Questão e A-D', () {
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
    final questions = parser.parse(text);
    expect(questions, hasLength(2));
    expect(questions.first.statement, contains('capital'));
    expect(questions.first.options, hasLength(4));
    expect(questions.last.options[1], '4');
  });

  test('aceita numeração com zero à esquerda e cinco alternativas', () {
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
    final questions = parser.parse(source);
    expect(questions, hasLength(2));
    expect(questions.first.options, hasLength(5));
    expect(questions.last.statement, contains('Considere o texto'));
  });

  test('não trunca seis alternativas', () {
    const source = '''
QUESTÃO 12
Escolha a alternativa correta.
A) Uma.
B) Duas.
C) Três.
D) Quatro.
E) Cinco.
F) Seis.
''';
    final question = parser.parse(source).single;
    expect(question.options, hasLength(6));
    expect(question.warning, contains('6 alternativas'));
  });

  test('aceita variantes de marcador', () {
    const source = '''
QUESTÃO Nº 1: Escolha uma opção.
[A] Uma opção
[B] Outra opção
[C] Terceira opção
[D] Quarta opção

2) Outra questão?
a - sim
b - não
c - talvez
d - depende
''';
    final questions = parser.parse(source);
    expect(questions, hasLength(2));
    expect(questions.first.options, hasLength(4));
    expect(questions.last.options, hasLength(4));
  });

  test('não confunde números do enunciado com questões', () {
    const source = '''
QUESTÃO 1. Uma população de 25% cresceu em 2024 e percorreu 10 km.
A) Cresceu.
B) Diminuiu.
C) Permaneceu igual.
D) Não é possível concluir.

QUESTÃO 2. Qual resultado?
A) 1.
B) 2.
C) 3.
D) 4.
''';
    final questions = parser.parse(source);
    expect(questions, hasLength(2));
    expect(questions.first.statement, contains('25%'));
    expect(questions.first.statement, contains('2024'));
    expect(questions.first.statement, contains('10 km'));
  });

  test('reconhece formato Cebraspe como certo/errado', () {
    const source = '''
1. Julgue o item a seguir.
A licitude do objeto é requisito de validade do contrato.

2. Julgue o item seguinte.
A administração pública deve observar a legalidade.
''';
    final questions = parser.parse(source);
    expect(questions, hasLength(2));
    expect(questions.first.format, QuestionFormat.trueFalse);
    expect(questions.first.options, ['CERTO', 'ERRADO']);
  });

  test('reconhece assertiva sem fabricar alternativas', () {
    const source = '''
QUESTÃO 1
Situação hipotética: João comprou um imóvel.
Assertiva: o contrato deverá observar os requisitos legais.
''';
    final questions = parser.parse(source);
    expect(questions, hasLength(1));
    expect(questions.single.format, QuestionFormat.assertion);
    expect(questions.single.options, isEmpty);
    expect(questions.single.warning, contains('sem alternativas'));
  });

  test('reconhece itens Cebraspe sem pontuação após o número', () {
    const source = '''
Julgue os itens a seguir.
1 A primeira assertiva está correta.
2 A segunda assertiva está incorreta.
3 A terceira assertiva também deve ser julgada.
''';
    final questions = parser.parse(source);
    expect(questions, hasLength(3));
    expect(
      questions.every((q) => q.format == QuestionFormat.trueFalse),
      isTrue,
    );
    expect(questions.every((q) => q.options.length == 2), isTrue);
  });

  test('permite processar colunas separadas sem intercalá-las', () {
    final questions = parser.parseColumns([
      '''
QUESTÃO 1. Coluna esquerda.
A) A
B) B
C) C
D) D
''',
      '''
QUESTÃO 2. Coluna direita.
A) A
B) B
C) C
D) D
''',
    ]);
    expect(questions.map((q) => q.number), [1, 2]);
  });

  test('ignora bloco curto sem estrutura de questão', () {
    expect(parser.parse('Questão 1. Apenas texto'), isEmpty);
  });

  test('aceita Q1 e questão ordinal', () {
    const source = '''
Q1. Qual é a resposta?
A. Primeira
B. Segunda
C. Terceira
D. Quarta

2ª QUESTÃO - Qual é a próxima?
A: A
B: B
C: C
D: D
''';
    final questions = parser.parse(source);
    expect(questions, hasLength(2));
    expect(questions.map((q) => q.number), [1, 2]);
  });
}
