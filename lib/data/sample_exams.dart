import '../domain/models/exam.dart';

const sampleQuestions = <Question>[
  Question(
    topic: 'Língua Portuguesa',
    statement: 'Em uma notícia, qual elemento ajuda o leitor a identificar rapidamente o assunto principal?',
    options: ['A assinatura do autor', 'O título e o subtítulo', 'A quantidade de parágrafos', 'O nome do site'],
    correctIndex: 1,
  ),
  Question(
    topic: 'Matemática',
    statement: 'Um simulado tem 50 questões. Um candidato acertou 70% delas. Quantas questões ele acertou?',
    options: ['30', '32', '35', '40'],
    correctIndex: 2,
  ),
  Question(
    topic: 'História',
    statement: 'A Constituição brasileira atualmente em vigor foi promulgada em qual ano?',
    options: ['1964', '1985', '1988', '1992'],
    correctIndex: 2,
  ),
  Question(
    topic: 'Raciocínio Lógico',
    statement: 'Se todo aluno inscrito recebeu um código e Marina está inscrita, então é correto concluir que:',
    options: ['Marina criou um código', 'Marina recebeu um código', 'Todos os códigos são iguais', 'A inscrição foi cancelada'],
    correctIndex: 1,
  ),
  Question(
    topic: 'Informática',
    statement: 'Qual prática contribui mais diretamente para a segurança de uma conta on-line?',
    options: ['Reutilizar a mesma senha', 'Compartilhar o código de acesso', 'Ativar autenticação em dois fatores', 'Anotar a senha publicamente'],
    correctIndex: 2,
  ),
];

const sampleExams = <Exam>[
  Exam(id: 'pmesp-2024', category: 'Concursos', title: 'PMESP — Aluno-Oficial 2024', description: 'Simulado demonstrativo inspirado no formato da banca Vunesp.', author: 'Equipe Prova Social', durationMinutes: 12, attempts: 284, questions: sampleQuestions),
  Exam(id: 'enem-linguagens', category: 'ENEM', title: 'Linguagens: interpretação', description: 'Treino rápido de leitura, gêneros textuais e argumentação.', author: 'Ana Martins', durationMinutes: 10, attempts: 931, questions: sampleQuestions),
  Exam(id: 'mat-basica', category: 'Matemática', title: 'Fundamentos essenciais', description: 'Porcentagem, razão, média e resolução de problemas.', author: 'Prof. Carlos', durationMinutes: 15, attempts: 517, questions: sampleQuestions),
  Exam(id: 'hist-brasil', category: 'História', title: 'Brasil República', description: 'Questões sobre acontecimentos políticos e sociais do período.', author: 'Lucas Prado', durationMinutes: 10, attempts: 148, questions: sampleQuestions),
];
