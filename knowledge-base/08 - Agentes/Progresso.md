---
tipo: area
area: controle de auditoria
status: PARCIAL
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: []
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-05
---

# Progresso da auditoria e preparação

- **Lote 1 iniciado (2026-11-08):** trabalho em worktree separado
  (`lote1/fonte-unica`, base `2c62e30`), sem tocar no Lote 0. Correções:
  `AGENTS.md` §25, hierarquia documental, banners históricos, README sem
  promessas de imagens/demonstração. Licença definida como **todos os direitos
  reservados**, com `LICENSE` na raiz e ADR-0007 `aceito`. Foram criados como
  `proposto` os ADR-0001 (paleta), 0004 (persistência), 0005 (distribuição),
  0006 (câmera), 0008 (hierarquia/vault) e 0009 (dependências). Commit local
  criado; push bloqueado por falta de credencial do GitHub neste ambiente.
- **Fase atual:** Fase 2 do Plano Mestre — decisões e arquitetura, após a
  auditoria profunda das 18 áreas.
- **Vault:** funcionando em `knowledge-base/`, com configuração Obsidian mínima
  e sem plugins comunitários.
- **Fase 1:** **concluída** — baseline medida, 18 áreas auditadas, 18 notas,
  síntese global e comparação documental. Licença e ground truth continuam
  pendentes de decisão externa.
- **Áreas profundas concluídas:** **18 de 18**, com placar em
  [[../09 - Auditoria/Áreas/Mapa das Áreas|Mapa das Áreas]] e síntese em
  [[../09 - Auditoria/Síntese da Refatoração|Síntese da Refatoração]].
  Resultado: 16 **EVOLUIR**, 2 **REFATORAR** (Domínio e Supabase), nenhuma
  **MANTER** ou **REESCREVER**.
- **Síntese global (2026-11-04):** achados transversais, ordem de 9 lotes e 12
  ADRs propostos em [[../09 - Auditoria/Síntese da Refatoração|Síntese da
  Refatoração]]. O primeiro lote é destravar o CI; o segundo é fixar a fonte
  única de verdade; o terceiro é fechar domínio, publicação e RLS.
- **Achados abertos:** formatação de três probes; diretórios absolutos e
  conteúdo potencialmente sensível em stdout; persistência JSON em
  SharedPreferences; módulos extensos; OCR com limiar fixo; divergências de
  publicação; ausência de licença raiz; ground truth autorizado ausente,
  inclusive para o corpus militar.
- **Scanner (2026-11-04):** especificação fechada; implementação parcial. O
  caminho PDF/JSON/manual, parser, gabarito, quality gate e revisão funcionam.
  Faltam câmera/galeria, fila de feedback, publicação de discursivas, estados
  estruturais no lugar da porcentagem e validação de OCR em aparelho. 105 testes
  do scanner passaram; 1 foi ignorado por falta do PDF ENEM local. A VUNESP real
  passa com 80 questões/32 páginas e o ENEM 2025 exige 90 quando o arquivo está
  presente. O fixture VUNESP está versionado com licença não verificada e não
  pode virar conteúdo de produto.
- **Produto em conversa:** primeiro rascunho do fluxo de entrada/criação
  registrado em [[../01 - Produto/Fluxo de Entrada e Criação]]; não aprovado
  como especificação final. A revisão agora inclui comparação com página
  original, correção manual, decisões Válida/Inválida, fila de feedback do dono,
  aviso de e-mail com link seguro sem conteúdo da questão, envio após
  confirmação explícita de relatório com recorte da página (sem PDF inteiro,
  identidade de conta ou respostas da tentativa) e exportação JSON anônima.
  Página inteira consentida e demais imagens ficam em arquivos separados
  referenciados pelo JSON. A estrutura JSON v1 agora está especificada em
  [[../01 - Produto/Importação e OCR]].
  Supabase escolhido em princípio para metadados e recortes privados, condicionado
  à auditoria do schema e armazenamento configurados. Retenção definida: manter
  até o dono marcar como resolvido, apagar 90 dias depois.
  Sem consentimento do recorte, é possível oferecer texto/metadados com
  confirmação separada. O código atual usa scores heurísticos `.99`/`.80` não
  calibrados; a decisão é não exibir porcentagem nem excluir só por score.
  Usar critérios estruturais e mandar imagens/fórmulas essenciais ambíguas para
  revisão humana. A validação requer ground truth autorizado.
  Também foi registrado o fluxo da tentativa: visitante pode resolver local,
  contador/anel de tempo recolhível, botão Próxima, “Não sei” separado de erro
  confirmado, resultados por tema confiável e prática de erros agrupada pela
  prova original. Duração oficial indicada no PDF é aplicada automaticamente;
  se estiver ausente, a pessoa configura um tempo ou escolhe sem cronômetro; ela
  escolhe antes da prova se aquela tentativa permite pausar. Respostas são salvas
  no aparelho sem rede/login e a tentativa retoma no estado salvo. Apagar uma
  tentativa exige confirmação e remove respostas locais e sincronizadas; a prova
  na Biblioteca e a prova de erros permanecem como materiais independentes.
  Exclusão offline não deve reaparecer após sincronizar.
  “Não sei” fica separado de erro, não pontua e entra na prova de erros; ao
  finalizar, a pessoa decide se questões totalmente em branco também entram.
  Se houver questões excluídas da tentativa, exibir separadamente as válidas
  para resolver e as fora da prova para revisão.
  Decisão confirmada: ao zerar o cronômetro, finalizar a tentativa
  automaticamente e mostrar o resultado; na última questão, trocar o botão por
  “Finalizar prova”, permitindo concluir com aviso de itens em branco.
- **Resultado em conversa:** destaque central de acertos/total; menos da metade
  vermelho, metade laranja, mais da metade verde; resumo por áreas confiáveis e
  ação **Revisar prova**. O denominador confirmado inclui todas as questões
  válidas com gabarito confirmado; branco/“Não sei” não pontuam, mas aparecem
  separados, sem rótulo de erro. Decidido: IA local será opcional e
  experimental, apenas em aparelhos compatíveis; explicações oficiais/revisadas
  têm prioridade. Também anotada a intenção de receber prova e gabarito em
  entradas separadas. Decisão confirmada: prova objetiva sem gabarito
  confirmado pode ser salva e resolvida, mas sem pontuação; fica como rascunho
  privado e não pode ser publicada até a confirmação do gabarito, mantido
  privado para correção.
- **Revisão em conversa:** três filtros (acertadas, erradas, em branco), questão
  no mesmo formato da prova, explicação gerada localmente sob demanda ou pedido
  de ajuda ligado à questão como publicação/discussão social. Login é necessário
  para perguntar, responder e seguir. Ao sair da revisão, retornar ao início; Biblioteca
  exibe pontuação e Prova de revisão agrupada pela prova original. Decidido: a
  aba de círculo branco reúne sem resposta e “Não sei”, com rótulos distintos.
  Link próprio por questão (também prova e perfil), que abre no app ou na Web;
  compartilhar questão não publica prova. Refinado: visitante pode ler
  conteúdo público compartilhado; login exige-se para perguntar, responder e
  seguir. A pergunta pode exibir a conta ou “anônima”; só a própria pessoa e
  moderadores autorizados veem a identidade real. O fluxo desejado para resposta
  bloqueada mostra “Resposta não autorizada” e motivos, permitindo reenvio
  ilimitado até aprovação. Correção: PARSER é o scanner/normalizador de provas
  e questões, não o moderador de texto social. Respostas serão avaliadas por
  classificador dedicado no servidor; casos incertos e contestações vão a
  revisão humana. Se o serviço falhar, o texto permanece em rascunho. Conteúdo
  rejeitado é apagado após a decisão, mantendo resultado e motivo. Descoberta:
  **Perguntas a responder** é aba permanente da comunidade;
  **Para você** recomenda sobretudo provas com base nos interesses (incluindo
  novas edições) e intercala ocasionalmente perguntas relacionadas que a pessoa
  possa responder. Pergunta abre um fio coletivo de comentários; toque longo
  oferece responder à mensagem ou inserir uma referência/link navegável para
  ela. Decidido: respostas ficam aninhadas sob a mensagem a que respondem.
  Quem publica recebe aviso de novas respostas e pode silenciar/sair do
  acompanhamento; menções diretas (`@nome`) notificam mesmo com silêncio.
  Decidido: perfil no canto superior direito abre modal com seções de
  Notificações e Configurações em ordem escolhida pela pessoa; central no app
  e push, contador, aviso breve, até três itens visíveis e “Ver todas” para o
  restante. Abrir uma notificação marca como lida e navega ao conteúdo;
  contador = não lidas. Não lidas ficam destacadas/pulsantes, lidas ficam
  acinzentadas; respeitar redução de movimento e não depender apenas de cor.
  Aprovados canais e categorias independentes, período silencioso e silenciar
  conversa. Todas as categorias listadas começam ligadas e podem ser desligadas
  individualmente; pedidos para seguir perfil privado e decisões de pedidos
  enviados e itens de avatar desbloqueados também notificam e começam ligados.
  Futuras categorias começam desligadas até ativação.
  **Perfil/seguimento em conversa:** perfil mostra nome, @, bio e avatar
  personalizável não fotográfico; público por padrão; visitante de perfil
  privado só vê nome/@, avatar/bio, sem métricas ou restante do conteúdo.
  Métricas (provas publicadas, questões respondidas e respostas) têm controles
  público/privado individuais. Ações: seguir/deixar de seguir (imediato em
  perfil público, aprovação em perfil privado); pedidos privados vão para fila
  do perfil do dono e quem pediu vê “Solicitação pendente” enquanto aguarda.
  Aceite ativa o vínculo e notifica; recusa mostra “Solicitação recusada”.
  Nova tentativa após recusa: esperar uma semana. Também pode solicitar
  mensagem direta; destinatário aceita ou nega, e remetente recebe “Mensagem
  negada”. Pedidos negados: 1 semana para tentar de novo após primeira recusa,
  2 semanas após a segunda e bloqueio permanente após a terceira, só entre
  aquelas duas contas; destinatário pode iniciar/aceitar conversa. Recusas de
  três contas diferentes abrem investigação das mensagens e análise de possível
  suspensão temporária global, não automática. Duração definida caso a caso;
  notificar motivo e permitir contestação. Métricas do perfil confirmadas:
  provas concluídas, provas publicadas, questões respondidas e pessoas
  ajudadas, todas baseadas em atividade real e com controle de privacidade
  individual. Todas começam públicas por padrão; a pessoa pode tornar cada uma
  privada. “Pessoas ajudadas” conta pessoas únicas que tocam “Isso me ajudou”
  numa resposta; visualizações ou respostas enviadas não contam.
  Avatar: proposta de personagem colecionável ligado à jornada de estudos, com
  personalização por partes e itens cosméticos liberados por conquistas
  verificáveis; sem vantagens em provas. Primeira lista de seis marcos aprovada
  para refinamento: cinco marcos gerais (provas, questões, sequência e
  aprovação em simulado) e uma conquista militar temática opcional; alinhar com
  a regra contra gamificação infantil/pressão diária e
  usar arte original/licenciada. Decidido: a pessoa
  escolhe um avatar pronto e ajusta com as peças disponíveis no conjunto
  inicial; demais itens são desbloqueados por conquistas. Pode editar o avatar
  livremente, a qualquer momento e sem custo, com todos os itens desbloqueados.
  Direção visual confirmada: pixel art original, legível em tamanhos pequenos e
  sem aparência infantil.
  Catálogo inicial confirmado: 5 rostos, 10 cabelos, 10 roupas, 15 acessórios
  e 5 chapéus temáticos. Catálogo mostra itens bloqueados, requisito e progresso
  desde o início.
  Conquista libera item automaticamente e gera aviso pelos canais habilitados.
  Lista inicial aprovada para refinamento: cinco conquistas gerais e uma
  temática militar opcional. Navegar/explorar conta como atividade para
  sequência; 24 horas sem atividade reiniciam a sequência, sem retirar itens já
  conquistados. Lembrete transparente após 24 horas inativas: ligado por padrão
  e desligável; enviado uma vez por período de inatividade,
  até a pessoa voltar a ter atividade e ficar inativa novamente. Nunca afirmar
  prova nova sem novidade real. Confirmado: 24 horas completas desde a última
  atividade, não a virada da data; horários/data exibidos no fuso local do
  dispositivo. A conquista de sete dias exige atividade ao longo de sete
  períodos consecutivos de 24 horas.
  Taxonomia confirmada: banca, concurso/instituição, disciplina/tópico e temas
  são campos distintos; temas usam múltipla seleção. Lista inicial ampla
  registrada no fluxo. Novos temas podem ser sugeridos e precisam de aprovação
  da equipe; sinônimos são aliases de um tema canônico, não opções duplicadas.
  URL da fonte obrigatória para declarar fonte oficial; opcional para envio
  comunitário ou fonte não verificada.
  Chat aceito vira conversa privada comum. Compartilhar prova abre folha do
  aparelho com WhatsApp/Prova Social; opção interna mostra amigos, envia link e
  permite responder em particular pelo chat, se destinatário tiver acesso.
  Definido: amigo é seguimento mútuo ou conversa direta aceita. Link não concede
  acesso: prova privada/local indisponível deve orientar o dono a compartilhar
  de forma autorizada, sem mudar privacidade. Questões herdam a privacidade da
  prova e não podem ser publicadas individualmente para contorná-la.
  Moderação social usa classificador dedicado no servidor, separado do PARSER;
  casos incertos vão a revisão humana. Respostas rejeitadas podem ser
  contestadas para revisão; continuam não publicadas até aprovação. Se o serviço
  falhar, manter rascunho não publicado e pedir nova tentativa, sem tratar falha
  técnica como violação. O texto fica acessível enquanto a revisão está
  pendente; depois da decisão, apagar o conteúdo e manter apenas resultado e
  motivo. A fila fica disponível ao dono e a moderadores designados; a identidade
  do autor fica oculta por padrão, com revelação apenas quando necessária e
  autorizada. Aprovação humana retorna ao autor para confirmação antes da
  publicação; rejeição informa motivo e permite corrigir e reenviar. Aprovação
  pendente expira em 7 dias e o texto é apagado sem publicação.
  Respostas publicadas ficam com contador de denúncias distintas (“1 de 3”,
  “2 de 3”) e só são ocultadas ao atingir três pessoas; denúncia repetida pela
  mesma conta não aumenta a contagem. Revisão humana mede falsos bloqueios e
  violações que passaram; curtidas e “Isso me ajudou” medem utilidade, não são
  rótulos automáticos de segurança. Em revisão sem violação,
  restaurar e avisar quem denunciou e quem perguntou sobre aquela questão; se
  houver violação, remover da visualização, informar motivo e permitir
  edição/reenvio pela verificação normal.
  Motivos de denúncia: ofensa/assédio/discriminação, palavrão/linguagem
  inadequada, spam/propaganda, não resposta/conteúdo sem sentido e exposição de
  dados pessoais. Denúncia de boa-fé não gera punição; abuso deliberado e
  repetido pode restringir a função até revisão humana.
- **Dispositivos de referência para explicação local:** notebook “Inspirion 15”
  e celular “C85”, nomes conforme informados pelo responsável. Confirmar modelos
  e configurações exatos antes de definir testes reproduzíveis.
- **Digitalização:** questão objetiva sem questão/alternativas encontradas, ou
  sem fórmula/imagem necessária recuperada, fica fora da prova para correção;
  erro pequeno de texto que pode ser corrigido manualmente é recuperável.
  Feedback inclui tipo da falha, página e questão completas, texto extraído,
  tentativa/correção manual e imagem da página mediante confirmação; não inclui
  PDF completo nem identidade por padrão. Após a correção, avisar a pessoa para
  tentar de novo; fechar o caso se funcionar.
- **Prova de revisão:** ao acertar, remover automaticamente da fila pendente,
  mas preservar em histórico de questões resolvidas para revisão posterior; a
  pessoa pode marcar que ainda quer revisar a questão.
- **Procedência da explicação:** identificar resposta oficial e sua fonte,
  resposta escrita por pessoa ou resposta gerada por IA; deixar claro o que foi
  gerado e o que veio de contribuição humana/oficial.
- **Lote 0 executado localmente (2026-11-05):** probes movidos para
  `test/manual/corpus_*.dart` (sem `_test`, corpus por
  `PROVA_SOCIAL_PROVAS_DIR`/`PROVA_SOCIAL_CORPUS_ROOT`, relatórios em
  `build/qa/probes/`, runner `qa/run_corpus_probes.sh`); nenhum caminho
  `/home/nikolas` em `test/ tool/ qa/ scripts/ site/ web/ .github/`;
  `node --test site/tests/site.test.cjs` entrou no `qa/run_static.sh`; `qa-full`
  voltou a rodar em `schedule` (`flutter-ci.yml:134`). Gate local verde:
  format exit 0, `qa/run_static.sh` exit 0, `flutter test` com 290 aprovados + 1
  ignorado. **Correção de registro:** a primeira medição do gate usou
  `qa/run_static.sh | tail` e leu o `$?` do `tail`; o `flutter analyze` estava com
  1 issue (`test/manual/corpus_probe.dart:182`), causada pela própria mudança do
  probe, e foi corrigida depois (`46eb9a0`).
- **Conteúdo de design acumulado (2026-11-05):** a Fase 2 tinha auditoria profunda
  mas nenhum insumo de engenharia — `Fluxos Principais` tinha 38 linhas dizendo
  que as fronteiras não tinham sido validadas. Foram medidas e escritas 7 notas:
  [[../03 - Domínios/Modelo de Domínio Atual]],
  [[../03 - Domínios/Contratos de Domínio Alvo]] (C1–C7),
  [[../04 - Infraestrutura/Inventário de Persistência e Dados]],
  [[../02 - Arquitetura/Mapa de Dependências]],
  [[../02 - Arquitetura/Fluxos Reais]],
  [[../01 - Produto/Inventário de Telas e Cobertura]] e
  [[../05 - Qualidade/Critério de Prontidão para Refatoração Global]].
  Veredito do gate na época: **já dá para desenhar o app novo; ainda não dá para
  executar a refatoração global**, porque faltavam ADR-0002/0003/0004 aceitos,
  testes de caracterização, `integration_test/` do fluxo do §21, schema
  reproduzível em migrations e o vault commitado (`git ls-files knowledge-base`
  era 0; hoje é 76).
  Achados novos que não estavam em nenhuma nota de área: `QuestionFormat` já
  existe em `question_parser.dart:252` e é **descartado** na borda
  (`digital_exam_service.dart:193-203`, que ainda força `reviewState: reviewed`);
  há **4–5 definições de pontuação** convivendo, inclusive `result_page.dart:280`
  contando branco como "revisar"; 4 tabelas lidas pelo app (`topics`,
  `topic_follows`, `question_comments`, `content_files`) só existem em SQL solto
  que nenhum script aplica; `media_assets` e `exam_media` estão definidos **nas
  duas** trilhas; o gabarito mora dentro do mesmo JSON do enunciado no aparelho
  (`local_exam_store.dart:120`); não há tabela de rotas — 34
  `MaterialPageRoute` em 9 arquivos, e a `onGenerateRoute` de `app.dart:36-43` só
  atende deep link; 4 destinos são classes privadas inalcançáveis em teste; e a
  tabela `public.questions` não tem coluna `format` e impõe
  `jsonb_array_length(options) between 2 and 8`
  (`202609210001_core.sql:39-50`) — **discursiva não cabe no schema atual**,
  qualquer que seja o modelo Dart.
- **Lote 0 e vault no Git do fork (2026-11-05):** quatro commits em
  `NAGC-Student/main` — `27403be` (probes portáveis + site no gate + `qa-full` no
  schedule), `eebb2b0` (vault: 76 arquivos versionados, `AGENTS.md` §25 apontando
  para `knowledge-base/`), `46eb9a0` (fix do analyzer) e `ff3be0c`
  (caracterização). `git push upstream main` retornou **403**: `NAGC-Student` não
  tem escrita em `NAGCODE-Dev`, e o fork não registra nenhum run de Actions — o
  caminho para o baseline verde é PR, como nos #16–#18. Diagnóstico dos runs no
  upstream: o push do PR #18 caiu em "QA estático" por `dart format` nos probes
  (corrigido por `27403be`) e o schedule de 2026-11-05 caiu antes, em "Resolver
  dependências Android", por **504 do JetBrains Releases** ao baixar
  `kotlin-compiler-embeddable-2.2.21.jar` — transitório, e o QA Completo nem
  chegou a rodar.
- **Caracterização escrita (2026-11-05, `ff3be0c`):** 23 expectativas em 3
  arquivos, todas sobre o código de `05a8fc1` e sem decisão de produto.
  Pontuação (`test/scoring_definitions_characterization_test.dart`): uma
  tentativa de 5 questões rende `correct` 2, `correctableCount` 3, `scorePercent`
  67, `wrongQuestionIndices` 1, `unanswered` 2, `byTopic.total` 3, "Revisar" 3 e
  `total` 5 — os quatro primeiros aparecem juntos na mesma tela; gabarito fora do
  intervalo leva `scorePercent` a 150; o `score_percent` do servidor é descartado
  pelo cliente; gabarito remoto fora de `options` recusa a entrega inteira.
  Publicação (`test/publication_characterization_test.dart`): `openEnded` aceito
  pelo parser é rejeitado antes de qualquer RPC; uma questão inválida reprova a
  prova toda; `topic` vira `Geral`; `p_source_type` é sempre `community`; a URL de
  origem troca a RPC; a prova volta como publicada mesmo com o pacote digital
  falhando. Rascunho (`test/draft_resume_characterization_test.dart`): respostas
  são índices posicionais, então a mesma tentativa gravada rende 2 corretas na
  ordem original e 0 na reordenada; índice além do novo tamanho desaparece sem
  aviso; o `clientAttemptId` é preservado na retomada e a fila recusa payload
  diferente sob o mesmo ID.
- **Régua de qualidade e auditoria medida (2026-11-05):** nova etapa da Fase 2 —
  pesquisar o cânone (SOLID nas fontes primárias, Clean Code verificável,
  Ousterhout, princípios de componente, canon de teste de Feathers) e aplicar ao
  `lib/`. Duas notas:
  [[../05 - Qualidade/Critérios de Qualidade de Código]] (normativa, 10 regras de
  porta, cada regra com *como verificar*) e
  [[../05 - Qualidade/Auditoria de Clean Code e SOLID medida]] (dívida com
  `arquivo:linha`). Medidas novas: as 111 regras já habilitadas dão **0**
  diagnósticos — a dívida está toda no que ferramenta nenhuma vê; com 33 regras de
  arquitetura extras, **901** (796 de documentação de widget, 105 reais: 51 `catch`
  sem `on`, 8 futuros descartados, 8 IO lento em async, 6 `Map` cru, 4 atribuições
  de parâmetro); **2 ciclos** de import (`quiz↔result` e
  `publish→home→auth→publish`), o que corrige a leitura anterior de que "o problema
  não é ciclo"; amplificação de mudança **7,03 arquivos/commit** (máx. 32) nos 40
  últimos commits de `lib/`; 4 portas no `lib/` inteiro (3 `abstract class` + 1
  `abstract interface class`) contra 8 serviços com default concreto, 214 classes
  com 60 dentro dos 4 arquivos de tela. A config de
  lints foi **restaurada** depois da medição (`git status` limpo; ativá-las na
  esteira é mudança de gate e pede aval). A nota
  [[../02 - Arquitetura/Mapa de Dependências]] ganhou a seção "Ciclos — correção
  desta nota".
- **Próxima fase técnica — strangler, não big-bang:** a refatoração *global* de uma
  vez continua descartada (risco 12 da
  [[../09 - Auditoria/Síntese da Refatoração|Síntese]]); o movimento certo é construir
  a camada nova ao lado da velha e migrar um fluxo por vez, removendo o código
  antigo só quando o novo cobre. Ordem por custo, não por elegância: **(1)** PR do
  fork para `NAGCODE-Dev/main` fechar o baseline verde; **(2)** ADR-0002/0003/0004
  aceitos — são a especificação do schema, e o schema é o primeiro deliverable
  porque `questions` não tem `format`, força 2–8 alternativas e não tem coluna de
  versão; **(3)** promover o SQL solto (`prova_social_backend_v1.sql`,
  `content_delivery_v1.sql`, `digitalization_v1.sql`) a migrations e colocar
  `scripts/local_db_test.sh` no CI; **(4)** caracterizar o que falta — validação de
  publicação na tela e uma rede que sobreviva à extração de controller de
  `QuizPage`; **(5)** Domain/Application + ports com injeção real e o fluxo
  importar→revisar→publicar atravessando primeiro; **(6)** um fluxo por vez
  (tentativa, rascunho, sync, consumo, discussão); **(7)** tabela de rotas e quebra
  das telas gigantes por último. Micro-refatorar `lib/core/import/` já é seguro
  hoje: 7 arestas, um consumidor, fan-in 0 a partir dele, 105 testes. A
  especificação do scanner continua fechada, mas a implementação é parcial: só
  depois dos contratos de domínio e RLS entram UI de confiança, discursivas,
  câmera/galeria e fila de feedback. Preparar ground truth autorizado antes de
  medir precisão/recall. Não enviar dados de prova nesta etapa.

## Limites de origem

O caminho de vault antigo listado no `AGENTS.md` não está montado neste
ambiente. Nenhum conteúdo do repositório antigo de documentação foi copiado ou
presumido; esta base foi montada a partir do `AGENTS.md`, do Plano Mestre
fornecido, do código e dos relatórios versionados.
