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

  test('preserva 80 questões sintéticas em ordem, sem perder alternativas', () {
    final source = List.generate(80, (index) {
      final number = index + 1;
      return '''
Questão $number. Enunciado de validação da questão número $number?
A) Primeira alternativa da questão $number.
B) Segunda alternativa da questão $number.
C) Terceira alternativa da questão $number.
D) Quarta alternativa da questão $number.
E) Quinta alternativa da questão $number.
''';
    }).join('\n');

    final questions = parser.parse(source);
    expect(questions, hasLength(80));
    expect(questions.map((question) => question.number), [
      for (var number = 1; number <= 80; number++) number,
    ]);
    expect(questions.every((question) => question.options.length == 5), isTrue);
  });

  test('agrupa trilhas paralelas de idioma sem descartar versões', () {
    String track(String heading, String prompt) =>
        '''
$heading
${List.generate(6, (index) {
          final number = index + 39;
          return '''
Questão $number. $prompt $number?
A) Opção A $number.
B) Opção B $number.
C) Opção C $number.
D) Opção D $number.
E) Opção E $number.
''';
        }).join('\n')}
''';
    final questions = parser.parse(
      'Leia o texto para responder às questões de\n39 a 44.\n'
      '${track('Língua Inglesa', 'What is the answer to')}\n'
      '${track('Língua Espanhola', '¿Cuál es la respuesta para')}',
    );

    expect(questions, hasLength(6));
    expect(questions.map((question) => question.number), [
      39,
      40,
      41,
      42,
      43,
      44,
    ]);
    expect(
      questions.every((question) => question.alternateVersions.length == 1),
      isTrue,
    );
    expect(questions.first.versionLabel, 'Inglês');
    expect(questions.first.alternateVersions.single.label, 'Espanhol');
    expect(questions.first.statement, contains('What is the answer'));
    expect(
      questions.first.alternateVersions.single.statement,
      contains('¿Cuál'),
    );
    questions.first.selectAlternateVersion(0);
    expect(questions.first.versionLabel, 'Espanhol');
    expect(questions.first.statement, contains('¿Cuál'));
    questions.first.selectAlternateVersion(0);
    expect(questions.first.versionLabel, 'Inglês');
    expect(questions.first.statement, contains('What is the answer'));
  });

  test('não agrupa um número duplicado isolado como versão paralela', () {
    const source = '''
Questão 1. Primeira pergunta válida?
A) Sim
B) Não

Questão 1. Outra pergunta válida?
A) Sim
B) Não
''';
    final questions = parser.parse(source);
    expect(questions, hasLength(2));
    expect(
      questions.every((question) => question.alternateVersions.isEmpty),
      isTrue,
    );
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

  test('preserva texto com marcador repetido sem criar alternativa falsa', () {
    const source = '''
QUESTÃO 12
Escolha a alternativa correta.
A) Uma.
B) Duas.
A) Continuação mal reconhecida de duas.
C) Três.
D) Quatro.
E) Cinco.
''';
    final question = parser.parse(source).single;

    expect(question.options, hasLength(5));
    expect(question.options[1], contains('A) Continuação'));
    expect(question.warning, contains('incompletos ou fora de ordem'));
    expect(question.confidence, lessThan(.95));
  });

  test('não interpreta numeração isolada sem sequência de alternativas', () {
    const source = '''
2024
Página 3
25 questões objetivas.
''';

    expect(parser.parse(source), isEmpty);
  });

  test('reconhece alternativas OCR sem pontuação no marcador', () {
    const source = '''
1
Considere os dados e assinale a conclusão correta.
A Primeira possibilidade.
B Segunda possibilidade.
C Terceira possibilidade.
D Quarta possibilidade.
''';

    final question = parser.parse(source).single;
    expect(question.number, 1);
    expect(question.options, hasLength(4));
    expect(question.options.first, 'Primeira possibilidade.');
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

  test('preserva bloco incerto para revisão humana', () {
    final question = parser.parse('Questão 1. Apenas texto').single;
    expect(question.number, 1);
    expect(question.statement, 'Apenas texto');
    expect(question.options, isEmpty);
    expect(question.format, QuestionFormat.unknown);
    expect(question.confidence, lessThan(.85));
    expect(question.warning, contains('Estrutura não reconhecida'));
  });

  test('mantém questão que atravessa quebra de página e ignora cabeçalho', () {
    const text = '''
INSTITUTO DE EXEMPLO — CADERNO DE PROVA
Página 4
Questão 18. Considere as informações apresentadas na primeira parte do
enunciado, que continua na página seguinte.
Página 5
INSTITUTO DE EXEMPLO — CADERNO DE PROVA
Assinale a alternativa correta.
A) Primeira alternativa.
B) Segunda alternativa.
C) Terceira alternativa.
D) Quarta alternativa.
''';
    final question = parser.parse(text).single;
    expect(question.number, 18);
    expect(question.statement, contains('continua na página seguinte'));
    expect(question.options, hasLength(4));
  });

  test('aceita alternativas acima de E e formatos V/F e assertiva', () {
    final six = parser.parse('''
Questão 1. Escolha uma opção adequada.
A) Um
B) Dois
C) Três
D) Quatro
E) Cinco
F) Seis
''').single;
    expect(six.options, hasLength(6));
    final vf = parser.parse('''
Julgue os itens seguintes.
1. O primeiro enunciado deve ser avaliado.
2. O segundo enunciado deve ser avaliado.
''');
    expect(vf, hasLength(2));
    expect(vf.every((q) => q.format == QuestionFormat.trueFalse), isTrue);
  });

  test('numerações de listas no enunciado não viram novas questões', () {
    final questions = parser.parse('''
Questão 18. Considere as etapas do procedimento:
1. Inicialize a variável com o valor informado.
2. Some os elementos da lista antes de prosseguir.
1º passo: confirme o resultado intermediário.
2º passo: compare com a condição descrita.
A) Resultado um.
B) Resultado dois.
C) Resultado três.
D) Resultado quatro.

Questão 19. Qual é a conclusão correta?
A) Conclusão um.
B) Conclusão dois.
C) Conclusão três.
D) Conclusão quatro.
''');

    expect(questions, hasLength(2));
    expect(questions.map((question) => question.number), [18, 19]);
    expect(questions.first.statement, contains('2º passo'));
    expect(questions.first.options, hasLength(4));
  });

  test('identifica questão discursiva sem fabricar alternativas', () {
    final question = parser
        .parse(
          'Questão 7. Explique a diferença entre os conceitos apresentados.',
        )
        .single;
    expect(question.format, QuestionFormat.openEnded);
    expect(question.options, isEmpty);
    expect(question.warning, contains('discursiva'));
  });

  test('preserva questão com alternativas que são apenas marcadores', () {
    final questions = parser.parse('''
53
Determine o valor indicado na figura.
(A)
(B)
(C)
(D)
(E)
54
''');

    expect(questions, hasLength(1));
    expect(questions.single.number, 53);
    expect(questions.single.format, QuestionFormat.unknown);
    expect(questions.single.warning, isNotNull);
  });

  test('não classifica prosa iniciada por artigo como alternativa', () {
    final question = parser.parse('''
Questão 1. A questão trata de um princípio importante.
A) Primeira alternativa
B) Segunda alternativa
C) Terceira alternativa
D) Quarta alternativa
''').single;

    expect(question.statement, startsWith('A questão trata'));
    expect(question.options, hasLength(4));
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
