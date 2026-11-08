# Prova Social — auditoria do estado atual

> **Documento histórico.** Escrito em 03/11/2026. Não é fonte vigente de requisitos nem retrato do estado atual. Para o estado vigente, consulte [`knowledge-base/00 - Central/Estado Atual.md`](knowledge-base/00%20-%20Central/Estado%20Atual.md) e [`knowledge-base/00 - Central/Hierarquia Documental.md`](knowledge-base/00%20-%20Central/Hierarquia%20Documental.md).

**Data:** 03/11/2026  
**Escopo:** leitura estática do repositório, documentação versionada, fluxo de
importação, armazenamento e tentativas, migrations/RLS, URLs, corpus local e
testes. O vault Obsidian indicado nas diretrizes não está montado neste
ambiente; decisões que existam somente nele não puderam ser verificadas.

Esta auditoria é uma fotografia do código, não uma afirmação de que o sistema
foi exercitado em produção. O worktree já continha alterações locais de UX e
pontuação quando a análise começou; elas foram preservadas.

## Resumo executivo

O projeto já tem uma base funcional para importar texto/PDF, revisar questões,
realizar provas offline, publicar provas estruturadas, servir páginas públicas
e proteger gabaritos com schema privado e RPC. Importação não é universal nem
visualmente validada: o parser é heurístico, a camada atual renderiza páginas
selecionadas para revisão, mas não compara sistematicamente a representação
visual com o texto extraído. Um runner local agora testa o mesmo parser em 46
PDFs; o corpus não traz ground truth anotado, e não há provas EPCAR/AFA.

As lacunas restantes de integridade incluem a falta de um total esperado
extraído de forma confiável, análise visual sistemática e cobertura de corpus
real diversificada. O quality gate já sinaliza duplicatas e estrutura
incompleta; resultados agora podem agregar erros do histórico local. O fluxo
reconhece um gabarito impresso quando possível e permite edição, mas não oferece
um passo final explícito que solicite e confirme um gabarito completo ou
parcial. Metadados de licença, autorização e remoção também não estão modelados.

## Estado por área

| Área | Estado | Evidência e limite |
|---|---|---|
| Extração de PDF | **Parcial** | `PdfTextExtractor` lê texto estruturado por página, ordena fragmentos por coordenadas, filtra cabeçalhos/rodapés e usa OCR seletivo. Limite de 500 páginas. OCR local Android/iOS; Web não dispõe desses motores. Ver `lib/core/import/pdf_text_extractor.dart` e `lib/core/import/ocr_service_*.dart`. |
| Parser de questões | **Parcial** | `QuestionParser` mantém páginas de origem, alternativas irregulares, formatos variados, versões de idioma e avisos para revisão. É heurístico e baseado em sinais estruturais; não garante segmentação de qualquer banca/layout e não preserva coordenadas por bloco na questão. Ver `lib/core/import/question_parser.dart`. |
| Quality gate | **Parcial; melhorias implementadas nesta execução** | Mede confiança, páginas ilegíveis, avisos OCR e sequência numérica; agora também sinaliza duplicatas e estruturas incompletas e compara a quantidade com um total informado pelo usuário, preservando esse total no documento importado. Diagnósticos não incluem texto privado. Ainda não descobre por si só o total esperado nem detecta conteúdo perdido sem uma referência externa. Ver `lib/core/import/import_quality_gate.dart`, `lib/core/import/import_diagnostic_event.dart` e `lib/features/publish/publish_page.dart`. |
| Análise visual | **Parcial** | O fluxo pode renderizar páginas inteiras selecionadas e associar materiais/imagens a questões. Não há detector geral de figuras vetoriais, regiões suspeitas ou recortes automáticos por coordenadas. Falha de OCR não substitui essa análise. Ver `PdfTextExtractor.renderPages`, `ImportedDocument` e o fluxo em `lib/features/publish/publish_page.dart`. |
| Revisão/gabarito importado | **Parcial** | O parser tenta ler gabarito impresso; a tela informa quando não encontra e permite revisão manual. Não há um passo dedicado de solicitação/confirmação final, estado explícito de gabarito parcial/anulado nem teste cobrindo o fluxo completo de revisão. |
| Corpus/benchmark | **Parcial; runner local implementado nesta execução** | `test/fixtures/import_corpus.json` mantém fixtures do app e `test/local_corpus_benchmark_test.dart` processa arquivos do corpus local, com hashes, status de licença, saída do quality gate e comparação por hash de documento. Foram processados 46 PDFs únicos, mas sem quantidade esperada anotada; não há precisão/recall mensurável, OCR nativo no runner Linux, cobertura militar nem baseline entre versões diferentes. |
| Questões erradas | **Parcial; revisão histórica local implementada nesta execução** | No resultado, uma segunda ação reúne questões erradas de tentativas concluídas locais, deduplica por prova/questão, prioriza recorrências e remove questões acertadas em tentativas posteriores. Há filtros por assunto/prova/período e limite de quantidade, com estados honestos quando não há dados suficientes. Continua limitado ao histórico deste aparelho e às questões com gabarito válido; não há sincronização agregada entre dispositivos. Ver `lib/core/review/wrong_question_practice_service.dart` e `lib/features/result/result_page.dart`. |
| Persistência de tentativas | **Parcial / base implementada** | Rascunhos são salvos localmente e a fila suporta tentativas offline, retry e resultados concluídos. Histórico reside em SharedPreferences e não foi verificada retenção/expiração para crescimento. Ver `lib/core/backend/attempt_draft_store.dart` e `attempt_sync_service.dart`. |
| Banco, RLS e gabarito | **Parcial / proteções presentes** | `private.question_keys` separa respostas; RPC de finalização corrige depois do envio. Migrations habilitam RLS e políticas por proprietário/visibilidade. Este checkout não prova qual migration está aplicada no projeto remoto atual; testes locais de banco/serviço real não foram executados nesta auditoria. |
| URLs públicas | **Parcial / rotas existentes** | Existem URLs por prova e questão, rotas Flutter, leitura pública sujeita à RLS e geração de páginas HTML/sitemap no site. A URL é baseada em UUID; ausência de login para conteúdo público depende da configuração remota/hosting. iOS Universal Links não estão configurados segundo `docs/URLS_COMPARTILHADAS_E_IMPORTACAO.md`. |
| Publicação/direitos | **Incompleto** | Há origem/tipo de fonte e URL; provas podem ser privadas/públicas. Não foram encontrados campos de licença/autorização, estado jurídico de redistribuição, denúncia/remoção ou trilha de despublicação. A origem informada não comprova permissão de republicação. |
| Arquivos/Storage | **Parcial** | Supabase Storage privado, metadados com hash, cache, limite de tamanho e políticas por usuário/prova; imagens podem ser vinculadas a questão. O PDF original não é o pacote padrão de entrega. Não há workflow de deduplicação global entre usuários nem infraestrutura R2 ativa. |
| Autenticação/navegação | **Parcial** | Auth Supabase e rotas de links existem; OAuth/deep links reais e retorno de intenção precisam de teste em aparelho/navegador e configuração externa. |
| UX desktop/importação | **Parcial** | Onboarding, navegação, editor e revisão de importação foram verificados por widget tests em dimensões/temas variados. Não houve inspeção visual em aparelhos, navegador real ou leitor de tela. |
| CI/testes | **Parcial, suíte Flutter local aprovada** | O workflow GitHub Actions contém gates Flutter e testes de Supabase. `flutter analyze` e `qa/run_tests.sh` passaram (296 testes; 1 benchmark opcional ignorado porque requer corpus local), e o benchmark foi executado à parte; isso não valida o CI remoto, o banco de produção nem o fluxo visual em dispositivos. |
| Observabilidade | **Parcial** | Existem diagnósticos estruturais locais e logs técnicos. Não há telemetria de saúde de produto integrada; o código explicitamente não envia os fingerprints sem consentimento. |

## Riscos prioritários

1. Questões perdidas podem não ser detectadas quando não há numeração contínua
   ou quantidade total confiável.
2. Fórmulas, tabelas, gráficos e diagramas vetoriais podem desaparecer da
   representação textual sem uma comparação visual sistemática.
3. Uma importação pode conter questão duplicada ou estruturalmente incompleta
   sem métrica específica para esses casos.
4. Provas publicadas não carregam informação verificável de permissão de
   redistribuição nem um fluxo de denúncia/remoção no modelo inspecionado.
5. A revisão histórica de erros agora existe localmente, mas não agrega
   tentativas sincronizadas entre dispositivos nem substitui um banco de questões
   estável por ID em todas as origens.
6. Fixtures de corpus não constituem, por si sós, evidência de qualidade para
   bancas/layouts não cobertos; PDFs reais exigem licença/autorização e fixtures
   locais não estão necessariamente presentes em todo runner.

## Incremento P0 implementado nesta execução

Sem substituir o parser nem criar um importador paralelo, o quality gate agora
normaliza o enunciado e as alternativas para identificar cópias exatas
duplicadas, marca todas as cópias para revisão e sinaliza estrutura objetiva
incompleta (enunciado ausente/curto, alternativas ausentes/vazias ou índice de
gabarito inválido). Questões discursivas válidas sem alternativas não são
classificadas como incompletas. Os motivos aparecem na avaliação de importação
já exibida pelo fluxo e os diagnósticos usam somente assinaturas estruturais.
Testes unitários verificam duplicatas, estrutura inválida e o caso discursivo.

A comparação com a quantidade esperada agora é opcional e usa um total
informado pela pessoa a partir do caderno, salvo como metadado de origem
`user`. O sistema não estima silenciosamente esse total. Análise visual geral e
benchmark amplo continuam pendentes por exigirem referências diversas,
metadados e validação humana.

## Incrementos seguintes

O resultado também pode montar uma prova local a partir de erros acumulados no
histórico: erros recorrentes têm prioridade, uma questão já acertada depois sai
da seleção, as cópias da mesma questão não são repetidas e a pessoa pode filtrar
por assunto, prova original e período e definir a quantidade. Questões em branco
não são tratadas como erros. A tentativa resultante permanece local.

O manifesto `test/fixtures/import_corpus.json` registra hash, procedência,
limites de uso, hash do parser e expectativas verificadas para o fixture
sintético e o benchmark VUNESP fornecido para QA local. A licença do benchmark
real não está verificada; a entrada não autoriza seu uso como conteúdo do
produto. EPICAR e outras bancas militares continuam sem fixture validada.

Na segunda fase foi executado o parser do app em 46 provas do corpus local
encontrado em `/home/nikolas/Corpus/prova-social-corpus`. O manifesto contém 68
registros (49 provas, 19 gabaritos; 3 entradas duplicadas) e não contém EPCAR,
AFA ou outra instituição militar prioritária. Foram detectadas 2.419 questões
candidatas, 474 para revisão e 181 incompletas; duas provas não produziram
questões. Nenhuma quantidade esperada estava anotada, então taxas de acerto não
podem ser calculadas. O runner, limites OCR/visual e resultados por instituição
estão em `SECOND_PHASE_REPORT.md`.

A auditoria encontrou e corrigiu uma chave de deduplicação histórica que incluía
a posição da questão e duplicava uma questão estável após reordenação da prova.
Não foram alteradas heurísticas do parser: sem referências de segmentação, isso
seria ajuste não validado e potencialmente específico.

## Referências

- `AGENTS.md` — diretrizes atuais do produto e definição de pronto.
- `docs/DIAGNOSTICO_ATUAL.md`, `docs/ROADMAP_EXECUCAO.md` —
  fotografias anteriores; seus resultados históricos não são tratados como
  prova desta execução.
- `docs/URLS_COMPARTILHADAS_E_IMPORTACAO.md` —
  rotas, deploy e limites conhecidos.
- `test/fixtures/README.md` — origem e limites dos arquivos de QA.
- `SECOND_PHASE_REPORT.md` — resultados do benchmark local e auditoria pós-fase.
