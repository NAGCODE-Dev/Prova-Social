class ExamSourceDirectoryEntry {
  const ExamSourceDirectoryEntry({
    required this.name,
    required this.description,
    required this.domain,
  });

  final String name;
  final String description;
  final String domain;
  Uri searchUri(String query) => Uri.https('www.google.com', '/search', {
    'q':
        'site:$domain ${query.trim()} (prova OR caderno de questões) (gabarito OR concurso)',
  });
}

const examSourceDirectory = [
  ExamSourceDirectoryEntry(
    name: 'INEP',
    description: 'ENEM, Encceja e exames educacionais',
    domain: 'gov.br/inep',
  ),
  ExamSourceDirectoryEntry(
    name: 'Cebraspe',
    description: 'Concursos e avaliações organizados pelo Cebraspe',
    domain: 'cebraspe.org.br',
  ),
  ExamSourceDirectoryEntry(
    name: 'FGV Conhecimento',
    description: 'Concursos, exames e certificações da FGV',
    domain: 'conhecimento.fgv.br',
  ),
  ExamSourceDirectoryEntry(
    name: 'Fundação Carlos Chagas',
    description: 'Concursos e seleções organizados pela FCC',
    domain: 'concursosfcc.com.br',
  ),
  ExamSourceDirectoryEntry(
    name: 'VUNESP',
    description: 'Concursos, vestibulares e avaliações da Fundação VUNESP',
    domain: 'vunesp.com.br',
  ),
  ExamSourceDirectoryEntry(
    name: 'Instituto AOCP',
    description: 'Concursos organizados pelo Instituto AOCP',
    domain: 'institutoaocp.org.br',
  ),
];
