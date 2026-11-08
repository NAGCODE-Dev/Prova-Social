# Prova Social — relatório da segunda fase

> **Documento histórico.** Escrito em 03/11/2026. Não é fonte vigente de requisitos nem retrato do estado atual. Para o estado vigente, consulte [`knowledge-base/00 - Central/Estado Atual.md`](knowledge-base/00%20-%20Central/Estado%20Atual.md) e [`knowledge-base/00 - Central/Hierarquia Documental.md`](knowledge-base/00%20-%20Central/Hierarquia%20Documental.md).

**Data:** 03/11/2026  
**Escopo:** auditoria da primeira fase, verificação de UX/UI, teste do mesmo
parser do aplicativo no corpus local encontrado, benchmark reproduzível e
correção de uma falha de deduplicação no treino de erros. Não houve publicação
de conteúdo, upload, alteração do repositório externo do corpus ou acesso ao
Supabase remoto.

## Resumo executivo

- `flutter analyze` passou sem issues.
- `bash qa/run_tests.sh` passou: **296 testes passaram e 1 teste opcional foi
  ignorado** (benchmark local, que é executado separadamente com o caminho do
  corpus).
- O benchmark executou o mesmo `PdfTextExtractor` + `QuestionParser` +
  `ImportQualityGate` em **46 PDFs únicos de prova** do corpus disponível.
- O parser detectou 2.419 questões candidatas. Isso **não é uma taxa de
  precisão**: nenhum dos 46 documentos tem quantidade de referência anotada no
  manifesto. Duas provas não produziram questão alguma.
- O corpus encontrado não contém provas identificadas como EPCAR, AFA ou
  outras instituições militares prioritárias. Nenhuma prova foi baixada nesta
  fase; os portais oficiais tentados retornaram bloqueio/indisponibilidade, e
  não se tentou contornar isso.
- O achado de código corrigido foi a chave de deduplicação histórica incluir a
  posição da questão: uma questão com ID estável era duplicada quando a ordem
  mudava entre versões da prova. A chave agora usa prova + ID estável (ou hash
  do enunciado como fallback), coberta por teste.

## 1. Auditoria pós-implementação

Foram relidos [IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md) e
[AUDIT.md](AUDIT.md), e conferidos o código e os testes dos incrementos
anteriores:

- Onboarding desktop limitado a largura legível; “Continuar” avança e “Pular”
  continua disponível. Há testes de desktop e paisagem móvel em
  [onboarding_responsive_test.dart](test/onboarding_responsive_test.dart).
- Revisão de importação virtualiza a lista, mantém o cursor, explica questões
  incompletas e permite iniciar uma tentativa local com as questões utilizáveis
  sem obrigar publicação. Há testes em
  [navigation_editor_test.dart](test/ux/navigation_editor_test.dart).
- Resultado permite revisar a tentativa, repetir erros e gerar uma prova local
  baseada no histórico, com filtros e estado recuperável sem correspondências.
- O quality gate identifica duplicatas textuais, estruturas incompletas e
  divergência de quantidade quando a pessoa informa um total esperado.
- Os testes e o analyzer anteriores passaram. Nesta revisão, o corpus real
  revelou a fragilidade da chave histórica por posição; ela foi corrigida e
  testada em [wrong_question_practice_service_test.dart](test/wrong_question_practice_service_test.dart).

Não foi possível fazer validação visual em aparelhos, navegadores reais,
leitores de tela ou com o backend de produção neste ambiente. Widget tests não
substituem essa validação.

## 2. UX/UI

### Telas e fluxos inspecionados

- **Onboarding:** conteúdo limitado em desktop e navegação entre páginas.
- **Início e navegação:** abas compactas em mobile, sidebar em desktop, visitante,
  estados de catálogo vazio/erro e retomada de provas locais.
- **Modo Foco:** largura máxima do conteúdo de questão, navegador lateral em
  desktop, faixa compacta em mobile, estado de salvamento local e ações de
  questão.
- **Importação/editor:** revisão de uma questão por vez, confirmação manual,
  questões incompletas, salvamento local e recuperação após falha.
- **Resultado/revisão:** filtros, virtualização e início de prática histórica.

### Melhorias verificadas

As melhorias responsivas da primeira fase foram verificadas pelos testes de
widget existentes para desktop, telas pequenas, paisagem, temas claro/escuro e
texto ampliado. O editor longo também tem teste que navega até a questão 200 e
confere restauração do cursor. O resultado evita reconstruir toda a revisão
histórica para cada questão.

Nesta fase não foi aplicada uma reformulação visual ampla: não havia evidência
de screenshots/aparelhos ou teste de usuário que justificasse mudar a identidade
visual inteira. No fluxo existente, a pessoa pode reabrir os filtros quando a
seleção fica vazia; esse caminho tem teste de widget.

### Pendências de UX

- Avaliação visual real em celulares pequenos, tablets e desktop, com light/dark,
  fonte ampliada, teclado e leitor de tela.
- Percurso end-to-end autenticado de publicar/compartilhar e abrir URL pública.
- A cobertura de Focus Mode valida estrutura e navegação, mas não mede fadiga,
  contraste em condições reais nem legibilidade de gráficos/fórmulas em provas
  militares.

## 3. Parser universal e benchmark

### Método

O benchmark não cria parser por banca: chama o pipeline compartilhado do app
para cada documento elegível do manifesto. A execução é reprodutível por:

```sh
bash qa/run_corpus_benchmark.sh /home/nikolas/Corpus/prova-social-corpus
```

O teste verifica SHA-256 e limita caminhos ao diretório do corpus; processa
somente registros `downloaded` do tipo `prova`, deduplicados por hash. O relatório
local é escrito em `build/qa/corpus-benchmark.json`. Registra hash do parser e
fingerprint SHA-256 dos arquivos de extração, parsing e quality gate, além dos
metadados de fonte/direitos, contagens estruturais, avisos e duração. Um
relatório anterior só é aceito como baseline se tiver o fingerprint completo;
diferenças são calculadas por hash de documento.

O runner é Linux e **não carrega os motores nativos de OCR**. Portanto esta
medição cobre texto nativo do PDF, parser e quality gate; não mede a eficácia
do OCR Android/iOS. Também não há ground truth visual anotado.

### Resultado agregado

| Métrica | Resultado |
|---|---:|
| Registros no manifesto | 68 |
| Entradas marcadas como duplicadas no manifesto | 3 |
| PDFs únicos de prova processados | 46 |
| Questões candidatas detectadas | 2.419 |
| Documentos sem questão detectada | 2 |
| Questões sinalizadas para revisão | 474 |
| Questões com estrutura incompleta | 181 |
| Inconsistências de numeração | 27 |
| Duplicatas exatas de questão encontradas | 0 |
| Páginas sem texto utilizável no modo sem OCR | 54 |
| Questões com aviso de conteúdo visual | 6 |
| Documentos com total esperado anotado | 0 |
| Recall/precisão de quantidade | Não mensurável |
| Taxa de preservação visual | Não mensurável |
| Tempo de processamento na execução de verificação | 121,4 s |

`474 / 2.419` (19,6%) é apenas a fração de candidatos que o quality gate pede
para revisar neste runner. Não é erro do parser nem precisão medida. A qualidade
de segmentação não pode ser inferida sem resposta de referência.

### Resultados por instituição do corpus atual

| Instituição/banca | PDFs | Anos | Detectadas | Revisão | Incompletas | Páginas sem texto |
|---|---:|---|---:|---:|---:|---:|
| CEBRASPE | 6 | 2020, 2021, 2024 | 192 | 104 | 10 | 0 |
| FGV | 9 | 2023, 2026 | 563 | 18 | 4 | 20 |
| FUVEST | 7 | 2019, 2022, 2024–2026 | 305 | 88 | 61 | 34 |
| INEP | 6 | 2024–2025 | 540 | 30 | 17 | 0 |
| Quadrix | 18 | 2026 | 819 | 234 | 89 | 0 |
| **Total** | **46** | — | **2.419** | **474** | **181** | **54** |

Dois documentos sem saída foram identificados para triagem: `doc_60a4d6c8e9ea8526e6bb`
(CEBRASPE, 2021) e `doc_ed9d478661ea0fea1324` (FGV, 2023). Não houve alteração
direcionada a eles sem gabarito ou segmentação anotada, para evitar ajuste
específico e regressão silenciosa em outras bancas.

Foram feitas duas execuções consecutivas com fingerprint completo idêntico
(`0ea0f7586c9da987de9b59dd1aa7c54ca0a5f593877b1a2a683f6dc85f5c063e`).
As contagens foram estáveis e a segunda execução não apresentou diferenças em
nenhum documento. A primeira saída sem fingerprint não foi aceita como baseline.
Isso verifica repetibilidade, mas não representa comparação entre versões nem
evidência de melhoria/regressão do parser.

## 4. Corpus

### Caminho e estado encontrado

Os caminhos literais informados (`/home/nikolas/prova-social-corpus` e
`/home/nicolas/Prova-Social-Corpus`) não existiam. A busca limitada por pastas
próximas encontrou `/home/nikolas/Corpus/prova-social-corpus`. Esse repositório
externo contém dados locais e arquivos não rastreados no seu próprio Git; ele
foi inspecionado e processado somente para leitura, sem modificações.

- 68 registros: 49 provas e 19 gabaritos.
- 65 registros `downloaded` e 3 linhas `duplicate`.
- 69 PDFs presentes na árvore; 46 provas únicas passaram pelo parser do app.
- `datasets/raw`: aproximadamente 92 MB; `datasets/normalized`:
  aproximadamente 194 MB.
- Instituições/bancas encontradas: CEBRASPE, FGV, FUVEST, INEP e Quadrix.
- **EPCAR: 0; AFA: 0; demais instituições militares prioritárias: 0.**
- O manifesto indica download público, mas a redistribuição é desconhecida ou
  não permitida; download público não foi tratado como autorização de
  republicação.

### Fontes consultadas para EPCAR/AFA

Os endereços oficiais tentados não disponibilizaram os documentos neste
ambiente: páginas EPCAR/AFA em `www2.fab.mil.br` retornaram HTTP 403;
`www.fab.mil.br/ingresso` também retornou 403; `ingresso.fab.mil.br` falhou em
DNS/transporte; e a rota consultada em `gov.br/aeronautica` retornou 404. Os
resultados não justificam contornar bloqueios ou recorrer a espelhos não
verificados. **Nenhum arquivo foi baixado nesta fase.**

## 5. Regressões, correções e pendências

### Corrigido

- **Deduplicação de erro dependia de posição:** o mesmo ID de questão aparecia
  como duas questões quando a prova mudava de ordem entre tentativas. Removido o
  índice da chave lógica e adicionado teste de versões reordenadas.

### Ainda pendente

- Adquirir provas EPCAR/AFA e outras militares por fonte oficial acessível, com
  situação de direitos e metadados confirmados. O corpus atual não permite medir
  suporte a essas instituições.
- Adicionar ground truth autorizado para quantidade, ordem e segmentação antes
  de ajustar heurísticas ou declarar taxas de sucesso.
- Avaliar OCR nativo Android/iOS e adicionar fixtures de digitalizações
  autorizadas.
- Desenvolver análise visual e anotação de regiões de fórmulas/gráficos sem
  substituir a página original nem inventar preservação.
- Executar comparação entre versões do parser com baseline mantido e critério
  comum para todas as bancas.
- Fazer avaliação UX em dispositivos reais, acessibilidade e fluxos completos
  com backend/URLs públicas.

Nenhum PDF foi copiado para o aplicativo, nenhum arquivo foi enviado ao
Supabase, e não houve commit, push, tag ou release.
