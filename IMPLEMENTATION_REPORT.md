# Prova Social — relatório da implementação

> **Documento histórico.** Escrito em 03/11/2026. Não é fonte vigente de requisitos nem retrato do estado atual. Para o estado vigente, consulte [`knowledge-base/00 - Central/Estado Atual.md`](knowledge-base/00%20-%20Central/Estado%20Atual.md) e [`knowledge-base/00 - Central/Hierarquia Documental.md`](knowledge-base/00%20-%20Central/Hierarquia%20Documental.md).

**Data:** 03/11/2026  
**Escopo entregue nesta continuação:** auditoria atualizada, quality gate de
importação, revisão histórica local dos erros e manifesto/regressão do fixture
sintético. O escopo amplo da solicitação não foi declarado concluído: os itens
pendentes abaixo são trabalho real, não funcionalidades presumidas.

## 1. Funcionalidades implementadas

- Criado `AUDIT.md` com classificação por área, evidências do código e riscos
  atuais. A base Obsidian especificada em `AGENTS.md` não está disponível neste
  ambiente; a auditoria não presume decisões que só existam nela.
- O `ImportQualityGate` agora identifica duplicatas exatas após normalização do
  enunciado e das alternativas. Todas as cópias são marcadas para revisão; o
  contador informa as ocorrências extras após a primeira.
- O quality gate identifica estrutura incompleta em questões objetivas:
  enunciado ausente/curto, alternativas insuficientes ou vazias, gabarito fora
  dos limites e formato desconhecido.
- Na tela de resultado da importação, a pessoa pode informar a quantidade
  esperada indicada no caderno. O sistema compara sem adivinhar, sinaliza falta
  ou excesso e salva o total e sua origem (`user`) nos metadados do documento.
- Questões discursivas (`openEnded`) sem alternativas continuam válidas e não
  são marcadas como incompletas por esse motivo.
- Os avisos específicos são anexados à questão e incluídos nos motivos que a
  tela de importação já apresenta. Foram adicionadas categorias diagnósticas
  estruturais, sem enviar conteúdo do documento.
- O resultado pode agregar erros de tentativas concluídas locais. A seleção
  prioriza erros recorrentes, remove duplicatas e questões acertadas em
  tentativas posteriores, ignora questões em branco e filtra por assunto, prova,
  período e quantidade. O botão só inicia quando a seleção atende à quantidade
  pedida; histórico vazio e seleção insuficiente têm estados explícitos, e os
  filtros continuam ajustáveis quando não há correspondências.
- Os fixtures sintético e VUNESP fornecido para QA ganharam manifesto com
  procedência, limites de uso, hashes SHA-256, hash do parser e expectativas de
  regressão. O status de licença do PDF VUNESP permanece não verificado; ambos
  continuam fora do conteúdo de produto.

O parser, o fluxo de extração e os serviços existentes foram evoluídos sem criar
um importador paralelo. Não houve alteração de comportamento da publicação ou
do gabarito privado. A prova histórica gerada é local; não sincroniza erros
entre aparelhos.

## 2. Arquivos criados e modificados

Criados:

- `AUDIT.md`
- `IMPLEMENTATION_REPORT.md`
- `lib/core/review/wrong_question_practice_service.dart`
- `test/wrong_question_practice_service_test.dart`
- `test/fixtures/import_corpus.json`

Modificados por este incremento:

- `lib/features/result/result_page.dart`
- `test/result_review_test.dart`
- `test/synthetic_pdf_import_test.dart`
- `lib/core/import/import_quality_gate.dart`
- `lib/core/import/import_diagnostic_event.dart`
- `lib/core/import/imported_document.dart`
- `lib/features/publish/publish_page.dart`
- `test/import_quality_gate_test.dart`
- `test/imported_document_test.dart`

O worktree já continha alterações locais de uma tarefa anterior de onboarding,
revisão da prova e pontuação. Elas foram preservadas, não reaplicadas nem
atribuídas a este incremento. São: `README.md`,
`lib/domain/models/exam.dart`,
`lib/features/onboarding/onboarding_page.dart`,
`lib/features/publish/publish_page.dart`,
`lib/features/result/result_page.dart`,
`test/exam_result_test.dart`,
`test/onboarding_responsive_test.dart` e
`test/ux/navigation_editor_test.dart`.

## 3. Banco de dados e migrations

Nenhuma tabela, política, RPC ou migration foi criada ou modificada. O código
existente separa `private.question_keys` do conteúdo público e usa políticas
RLS nas migrations inspecionadas; a aplicação dessas migrations no ambiente
remoto não foi verificada nesta execução.

## 4. Testes e verificações

- `flutter analyze` — aprovado, sem issues.
- `bash qa/run_tests.sh` — aprovado: **294 testes**.
- A suíte executou os testes do quality gate, parser, fixture sintética de 80
  questões, PDF VUNESP de 80 questões e caderno ENEM 2025 de 90 questões,
  disponíveis neste ambiente.
- `flutter test --reporter expanded --concurrency=1 test/import_quality_gate_test.dart`
  — aprovado: 12 testes.
- `flutter test --reporter expanded --concurrency=1 test/imported_document_test.dart`
  — aprovado: 3 testes, incluindo round-trip dos metadados esperados.
- `flutter test --reporter expanded --concurrency=1 test/wrong_question_practice_service_test.dart test/result_review_test.dart`
  — aprovado: 10 testes, incluindo priorização, deduplicação, correção
  posterior, filtros, estado sem correspondências e integração do resultado.
- `flutter test --reporter expanded --concurrency=1 test/synthetic_pdf_import_test.dart`
  — aprovado: 2 testes; hash do documento/parser e snapshot de 80 questões
  conferidos.
- `dart format --output=none --set-exit-if-changed` nos arquivos Dart deste
  incremento — aprovado.
- `git diff --check` — aprovado.

Esses resultados não equivalem a validação visual em aparelhos, CI remoto ou
backend Supabase de produção.

## 5. Problema encontrado e corrigido

Antes deste incremento, o quality gate considerava confiança, páginas ilegíveis,
avisos OCR e sequência numérica, mas não contava duplicatas textuais nem
estruturas inválidas de questões já detectadas. Agora esses casos aparecem como
revisão necessária e recebem avisos específicos.

## 6. Funcionalidades ainda pendentes

### P0

- Detector geral de conteúdo visual/vetorial, comparação entre extração e página
  renderizada, localização de regiões e recortes ligados à questão.
- Detecção automática de uma quantidade esperada confiável a partir do
  documento. Sem informar o total no fluxo, o sistema ainda não pode afirmar
  que detectou todas as questões perdidas; duplicatas e estrutura incompleta só
  avaliam o que o parser conseguiu produzir.
- Ampliar o manifesto de corpus para benchmarks reais autorizados de outras
  bancas/layouts, com origem/licença verificadas, snapshots versionados e
  comparação entre versões. O benchmark VUNESP existente tem licença não
  verificada e não certifica suporte a outras bancas.
- Passo explícito de solicitação/confirmação de gabarito completo ou parcial,
  incluindo anuladas e vínculo validado por identificador. O fluxo atual tenta
  reconhecer gabarito impresso e permite edição manual.

### P1

- URLs públicas estáveis por questão e prova existem, mas dependem de
  configuração de hospedagem, RLS e conteúdo realmente autorizado. Universal
  Links para iOS continuam pendentes conforme a documentação versionada.
- Modelagem e fluxo de direitos/permissões, denúncia, remoção, despublicação e
  histórico de moderação. Os metadados atuais de fonte não substituem licença
  ou autorização de redistribuição.
- Validação remota das migrations, políticas de Storage e proteção do gabarito
  em todos os fluxos públicos.

### P2

- Observabilidade operacional agregada e com consentimento explícito.
- Testes end-to-end completos em navegadores e aparelhos, além de verificação
  visual, offline, acessibilidade e cenários de erro de rede.

## 7. Dependências externas necessárias

Nenhuma dependência de código foi adicionada. Para os itens pendentes serão
necessários: documentos de benchmark cuja utilização para teste esteja
autorizada; uma fonte confiável para quantidades/metadados esperados; acesso a
ambiente Supabase isolado para validar migrations/RLS; e decisão jurídica e
operacional sobre licenças, publicação e remoção de conteúdo.

## 8. Riscos técnicos remanescentes

- O quality gate não detecta questões ausentes sem numeração ou total de
  referência; não afirmar completude de importação.
- A normalização detecta duplicatas exatas, não paráfrases nem questões
  intencionalmente repetidas com pequenas diferenças. A revisão humana continua
  necessária.
- PDFs de terceiros usados como benchmark requerem autorização/licença
  apropriada; presença local não comprova permissão de redistribuição.
- Configuração remota de RLS/Storage não foi verificada nesta execução.
- O vault de documentação indicado pelo projeto estava inacessível.

## 9. Próximos passos recomendados

1. Explorar extração conservadora do total esperado a partir de evidência clara
   no documento, mantendo a entrada manual como referência explícita e sem
   inventar totals a partir de heurísticas.
2. Expandir a revisão visual usando as páginas já renderizadas e os dados de
   coordenadas disponíveis, começando por candidatos suspeitos com aprovação
   humana.
3. Versionar resultados do corpus e adicionar uma rotina de comparação de
   regressão, preservando fixtures apenas com autorização.
4. Completar e validar o fluxo de revisão de gabarito, incluindo estado parcial
   e questões anuladas, após definir como persistir essa distinção sem confundir
   gabarito ausente com anulação.
5. Formalizar estados de licença/publicação e fluxo de remoção antes de ampliar
   o conteúdo público.

Não foi feito commit, push, tag, release ou alteração no backend remoto.
