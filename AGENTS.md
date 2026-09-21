# Prova Social — Diretrizes do produto e plano de desenvolvimento

Este arquivo é a fonte principal de contexto para qualquer agente que trabalhe neste repositório. Leia-o integralmente antes de planejar ou alterar código.

## 1. Visão do produto

O Prova Social é uma rede de questões e provas. O objeto central não é uma publicação genérica: é a questão. A plataforma deve permitir descobrir, importar, organizar, resolver, revisar e discutir provas e questões.

O ciclo principal é:

**Descobrir → Salvar → Fazer → Errar → Entender → Discutir → Melhorar → Refazer**

O aplicativo não deve parecer um dashboard corporativo nem uma landing page de IA. Deve parecer uma plataforma de estudos rápida, confiável, social e centrada na resolução de questões.

Proposta de valor em linguagem direta:

> Encontre ou importe uma prova, resolva no seu ritmo e descubra exatamente o que precisa estudar.

Uma função essencial é criar automaticamente uma nova prova somente com questões que o usuário errou, permitindo verificar se aprendeu após a revisão.

## 2. Princípios obrigatórios

1. Não usar conteúdo falso como se fosse real.
2. Não deixar listas, perfil, estatísticas ou provas demonstrativas hardcoded na experiência de produção.
3. Estados vazios devem ser honestos e úteis.
4. Login é opcional para explorar, pesquisar e experimentar conteúdo público.
5. Login é exigido apenas para ações persistentes ou sociais, como publicar, comentar, salvar na nuvem, seguir e sincronizar.
6. Ao iniciar uma prova, a rede social desaparece: entra o **Focus Mode**.
7. A procedência do conteúdo deve estar sempre visível.
8. O usuário nunca deve perder respostas por falha de conexão.
9. O aplicativo deve funcionar bem primeiro no celular e depois adaptar-se a telas maiores.
10. Toda interação deve responder imediatamente ao toque.
11. Acessibilidade, redução de movimento e conexão ruim são requisitos, não extras.
12. Não introduzir dependência de IA paga para o funcionamento estrutural do produto.
13. Não publicar, fazer commit, criar tag, release ou push sem autorização explícita do responsável pelo projeto.

## 3. Identidade visual — Study Surface

### Marca

- Nome exibido: **Prova Social**, sem underline.
- Package name e identificadores internos podem manter `prova_social` quando tecnicamente necessário.
- Símbolo: livro aberto com traços verdes/neon e borda arredondada.
- Nunca voltar ao ícone padrão do Flutter no Android, PWA, favicon ou Flutter Web.

### Tokens claros

- `background`: `#F7F8F6`
- `surface`: `#FFFFFF`
- `surfaceHover`: `#F1F4F1`
- `textPrimary`: `#171A18`
- `textSecondary`: `#68706B`
- `border`: `#E3E7E4`
- `brand`: `#16A36A`
- `brandHover`: `#12875A`
- `brandSoft`: `#E7F6EF`
- `warning`: `#E5A524`
- `danger`: `#DC4C4C`

### Tokens escuros

- `background`: `#101311`
- `surface`: `#181C19`
- `textPrimary`: `#F3F5F3`
- `border`: `#2A302C`

### Sistema

- Grid: `4 / 8 / 12 / 16 / 24 / 32 / 48 / 64`.
- Botões: 40–44 px.
- Inputs: 44–48 px.
- Alvos de toque: aproximadamente 48×48 px.
- Cards: raio de 12 px.
- Botões: raio de 8–10 px.
- Modais: raio de 16 px.
- Conteúdo geral desktop: máximo de 1200–1280 px.
- Leitura e prova: máximo de 760–840 px.
- Tipografia de interface: Inter, pesos 400/500/600/700, ou equivalente já adotada pelo projeto.
- Regra: **se tudo é card, nada é card**.
- Cor tem significado. Verde não deve ser usado aleatoriamente como decoração.

### Movimento

- Pressão de botão: 80–140 ms.
- Seleção de alternativa: 120–200 ms.
- Expansão: 180–280 ms.
- Troca de conteúdo: 200–300 ms.
- Transição de página: 250–400 ms.
- Preferir Flutter nativo: `AnimatedContainer`, `AnimatedOpacity`, `AnimatedSwitcher`, `AnimatedSize`, `TweenAnimationBuilder` e `Hero`.
- Respeitar `MediaQuery.disableAnimations`.
- Animação precisa explicar estado, origem, confirmação ou espera.

## 4. Navegação e estrutura

### Mobile

Navegação inferior compacta:

- Início
- Explorar
- Publicar
- Biblioteca
- Perfil

### Desktop

- Sidebar com aproximadamente 240 px.
- Mesmo modelo mental e mesmas rotas do mobile.

### Visitante

O visitante pode:

- ver onboarding;
- explorar e pesquisar;
- abrir conteúdo público;
- experimentar uma prova pública;
- usar recursos locais que não exijam conta.

Ao tentar ação autenticada, abrir uma tela/modal de login contextual e retornar à ação original depois da autenticação.

## 5. Onboarding, autenticação e inicialização

### Splash

- Livro da logo folheando enquanto a borda neon gira como indicador de carregamento.
- Curta, sem bloquear desnecessariamente.
- Respeitar redução de movimento.
- A inicialização deve aguardar apenas o mínimo necessário: configuração local, sessão e rota inicial.

### Onboarding

- Apresentação curta e visual, preferencialmente interativa.
- Mostrar o fluxo real do produto em vez de muito texto.
- Permitir pular.
- Nunca obrigar login para continuar.
- Pode usar demonstrações curtas das funções: encontrar, importar, resolver, revisar e discutir.

### Login

- E-mail/senha e Google via Supabase Auth.
- Corrigir deep link: confirmação e OAuth nunca devem terminar em `localhost` no aplicativo publicado.
- Android deve retornar ao app por URI configurada.
- Web deve retornar ao domínio oficial.
- Preservar a intenção anterior ao login.
- Não expor service role key no cliente. Apenas chave pública/anon/publishable pode estar no app.

## 6. Home, Explorar, Biblioteca e Perfil

### Home

A home serve para encontrar algo para fazer, não para contemplar métricas.

- saudação discreta;
- busca;
- continuar de onde parou;
- recomendações reais;
- assuntos seguidos;
- provas recentes;
- estado vazio quando não houver dados.

### Explorar

- Busca em destaque: “O que você quer estudar?”
- Filtros compactos por banca, concurso, disciplina, ano e tipo.
- Permitir seguir assuntos, bancas, concursos e disciplinas.
- Resultados em lista compacta, não cards gigantes.

### ExamListTile

Componente prioritário e reconhecível:

- imagem/brasão opcional;
- banca e procedência;
- título e ano;
- número de questões e duração;
- disciplinas resumidas;
- progresso apenas quando iniciado;
- estado: começar, continuar ou concluída;
- salvar;
- layout compacto adequado a uma lista.

### Biblioteca

- salvas;
- em andamento;
- concluídas;
- coleções;
- histórico;
- coleções personalizadas semelhantes a playlists.

### Perfil

- nome, avatar e bio curta;
- temas seguidos;
- atividade, salvos, publicados e coleções;
- estatísticas reais e discretas;
- sem gamificação infantil;
- perfil de visitante não deve inventar estatísticas.

## 7. Página da prova

Mostrar:

- título, ano, banca e instituição;
- quantidade de questões;
- duração sugerida ou oficial;
- número de realizações real, quando disponível;
- começar/continuar;
- salvar e compartilhar;
- descrição;
- fonte e procedência;
- comentários relacionados.

### SourceBadge

Estados obrigatórios:

- Fonte oficial
- Enviado pela comunidade
- Fonte não verificada

Guardar URL da fonte, autor/importador, data de publicação e metadados de rastreabilidade quando disponíveis.

## 8. Focus Mode — interface da prova

Esta é a interface mais importante do aplicativo.

### Requisitos

- Remover feed, notificações e distrações.
- Mostrar questão atual, total e progresso.
- Enunciado confortável e imagens preservadas.
- Alternativas claras e com resposta instantânea ao toque.
- Navegação anterior/próxima.
- Marcar para revisão.
- Navegador de questões no desktop e acesso compacto no mobile.
- Estados respondida, não respondida e revisão não podem depender apenas de cor.
- Persistir cada resposta localmente imediatamente.
- Sincronizar em segundo plano quando autenticado.
- Retomar exatamente do ponto salvo.

### Cronômetro configurável

Antes de iniciar, permitir configurar:

- tempo total, ligado/desligado;
- tempo por questão, ligado/desligado;
- exibição dos cronômetros.

Ao tocar no cronômetro visível:

- ocultar o valor;
- mostrar ícone de olho fechado/estado oculto;
- tocar novamente para revelar.

### Revisão

Ao tentar finalizar ou avançar de uma questão marcada/não respondida, abrir modal contextual com opções claras, por exemplo:

- voltar e responder;
- manter sem resposta e pular;
- escolher alternativa, quando aplicável.

Não interromper desnecessariamente quem já respondeu.

### Desempenho

- O cronômetro não pode reconstruir o enunciado inteiro a cada segundo.
- Separar widgets e observadores por responsabilidade.
- Usar listas preguiçosas.
- Parsing, OCR e compactação pesados devem sair da thread da interface.

## 9. Resultado e revisão inteligente

Priorizar informação útil:

- acertos/total;
- percentual;
- duração;
- erradas;
- em branco;
- marcadas para revisão;
- desempenho por disciplina;
- lista de questões para revisar.

Cada revisão deve mostrar:

- questão;
- resposta selecionada;
- resposta correta;
- explicação, se disponível;
- discussão da comunidade;
- procedência.

Oferecer ação para gerar uma **prova dos erros**, contendo questões erradas selecionadas por filtros, período, disciplina ou prova original. Depois da nova tentativa, comparar evolução sem inventar dados.

## 10. Importação e digitalização

### Fluxo ideal

1. Escolher PDF, imagens, câmera, JSON ou criação manual.
2. Iniciar extração automaticamente.
3. Mostrar progresso por etapas reais.
4. Extrair metadados do próprio arquivo.
5. Detectar layout e ordem de leitura.
6. Extrair texto nativo quando existir.
7. Aplicar OCR apenas às páginas/regiões necessárias.
8. Detectar questões e alternativas.
9. Relacionar imagens às questões.
10. Exibir revisão e indicar incertezas.
11. Configurar prova e gabarito.
12. Salvar como rascunho.
13. Publicar somente após confirmação.
14. Ao terminar, oferecer “Ir para a prova” e “Voltar ao início”.

### Loading da importação

Não usar apenas spinner genérico. Mostrar etapas como:

- Preparando arquivo
- Lendo páginas
- Identificando colunas
- Extraindo texto
- Aplicando OCR
- Detectando questões
- Associando imagens
- Validando estrutura

### OCR e PDF

O OCR produz texto bruto com informação de página e, sempre que possível, coordenadas dos blocos. O parser não pode depender apenas de uma expressão regular frágil.

Pipeline esperado:

1. Detectar se a página possui texto nativo suficiente.
2. Identificar uma ou duas colunas usando coordenadas e agrupamento horizontal.
3. Ordenar blocos coluna a coluna, de cima para baixo.
4. Remover cabeçalhos e rodapés repetidos sem apagar conteúdo legítimo.
5. Detectar candidatos a questão por múltiplas evidências:
   - número/identificador;
   - texto ou imagem associada;
   - conjunto de alternativas;
   - próximo identificador de questão;
   - continuidade espacial e entre páginas.
6. Detectar alternativas `A–E` e variações de marcação.
7. Tratar enunciados que continuam em outra coluna ou página.
8. Não interpretar sumário, instruções, texto-guia ou numeração de página como questão.
9. Calcular confiança por questão e por campo.
10. Levar casos incertos para revisão humana.

### Critério mínimo de qualidade

Usar uma prova real de 80 questões, incluindo layout de duas colunas, como fixture de validação permitida no repositório ou teste local. A importação só pode ser considerada resolvida quando:

- encontra a quantidade esperada;
- mantém a ordem correta;
- não transforma instruções em questões;
- preserva alternativas e imagens;
- permite correção manual antes de publicar;
- possui testes para regressões conhecidas.

### Discursivas

- Permitir importar e publicar questões discursivas.
- Não fingir correção objetiva automática.
- Armazenar resposta esperada, critérios/rubrica e resposta oficial quando disponíveis.
- Avaliação avançada de texto fica para fase posterior.

## 11. Imagens de provas

Na criação/revisão da prova, disponibilizar uma aba para:

- enviar imagem do aparelho;
- selecionar imagem já enviada;
- pesquisar imagem pública licenciada para uso;
- informar autoria, licença e URL de origem;
- recortar e confirmar antes de salvar.

Não baixar ou republicar imagens sem licença compatível. Criar inicialmente um banco pequeno e verificável, sem depender de scraping indiscriminado.

## 12. Questão como objeto social

Cada questão publicada deve possuir:

- ID estável;
- URL canônica;
- vínculo com prova, banca, ano e instituição;
- procedência;
- versão/revisão;
- discussão própria;
- respostas e estatísticas agregadas respeitando privacidade.

URLs públicas devem ser compartilháveis e indexáveis somente quando o conteúdo puder ser publicamente exibido de forma legítima.

## 13. Comunidades dinâmicas

Inspiradas em comunidades temáticas, mas criadas em torno de necessidades reais.

### Regra inicial

Quando duas ou mais pessoas distintas demonstrarem intenção semelhante sobre o mesmo assunto, prova ou questão, o sistema pode criar uma comunidade sugerida.

Não criar apenas pela coincidência literal de texto. Normalizar e agrupar por entidades, por exemplo:

- prova/instituição/ano;
- ID da questão;
- banca;
- disciplina e tópico;
- intenção da pergunta.

### Estados

- `suggested`: candidata criada pelo sistema;
- `active`: possui atividade suficiente;
- `dormant`: sem atividade recente, somente leitura;
- `archived`: arquivada/moderada;
- `reopened`: reativada por nova procura ou atividade.

Uma comunidade inativa não deve ser apagada automaticamente. Ela pode ficar somente leitura, continuar pesquisável e ser reaberta quando houver nova demanda.

### Proteções

- evitar duplicatas;
- fundir comunidades equivalentes com histórico preservado;
- rate limiting;
- denúncia e moderação;
- regras contra spam;
- critérios configuráveis de inatividade;
- não expor perguntas privadas sem consentimento.

## 14. Backend e dados

### Supabase

Usar Supabase para:

- Auth;
- Postgres;
- Row Level Security;
- dados sociais e acadêmicos;
- sincronização e metadados.

Toda tabela que contenha dados de usuário deve ter RLS coerente. As políticas devem impedir que um usuário leia ou altere dados privados de outro.

Entidades mínimas esperadas:

- profiles
- topics
- follows
- exams
- exam_versions
- questions
- alternatives
- answer_keys
- sources
- media
- collections
- collection_items
- attempts
- attempt_answers
- bookmarks
- posts/discussions
- comments
- community_candidates
- communities
- community_members
- reports

Não criar todas cegamente. Antes de migrations, inspecionar o schema existente, preservar dados e evoluir de forma incremental.

### Arquivos e compactação

- PDF é processado e convertido para modelo estruturado.
- Distribuir principalmente JSON e imagens otimizadas, não o PDF inteiro quando ele não for necessário.
- Compactar pacotes de conteúdo e verificar integridade por hash.
- Descompactar localmente com limites de tamanho e validação para evitar pacotes maliciosos.
- Cache local e download sob demanda.
- Deduplicar imagens por hash.
- P2P não é requisito da primeira versão funcional: conectividade, disponibilidade e segurança tornam um modelo exclusivamente P2P inadequado.
- Enquanto não houver R2, usar a infraestrutura realmente configurada; não deixar bindings quebrados ou código fingindo que um bucket existe.

## 15. Offline e sincronização

- Respostas salvas localmente a cada alteração.
- Provas iniciadas disponíveis offline quando baixadas.
- Fila de sincronização com repetição segura.
- Exibir “Salvo no aparelho”, “Sincronizando” e “Sincronizado”.
- Resolução explícita de conflitos.
- Entrega/finalização deve tolerar falha temporária de rede.

## 16. Skeletons e estados

O loading deve preservar o formato da página e explicar o que está sendo esperado.

- Skeleton de card parece card.
- Skeleton de questão mostra linhas e alternativas.
- Skeleton de perfil mostra avatar e textos.
- Skeleton de feed replica publicações.
- Shimmer discreto.
- Fade skeleton → conteúdo de aproximadamente 150–200 ms.
- Depois de espera longa, mostrar mensagem humana.
- Em falha, mostrar causa compreensível e “Tentar novamente”.
- Botões usam progresso no próprio botão.
- Operações com percentual conhecido usam barra de progresso.

## 17. Site oficial e distribuição

Domínio atual: `https://prova-social.pages.dev/`.

O site deve ser mobile-first, curto e demonstrável:

- linguagem humana e direta;
- pouco texto;
- simulador interativo do fluxo;
- explicar rapidamente importar → resolver → revisar → refazer erros;
- CTA para baixar APK;
- CTA para abrir Flutter Web;
- não instalar a landing page como se fosse o app;
- o PWA instalável é o Flutter Web em `/app/` ou rota oficial equivalente.

Cada build válida deve produzir:

- APK universal assinado;
- APKs por arquitetura quando úteis;
- Flutter Web;
- GitHub Release versionada;
- site atualizado apontando para os artefatos atuais.

O Flutter Web publicado deve usar ícones, manifest e favicon da marca Prova Social, nunca os padrões do Flutter.

## 18. Atualizações do aplicativo

- O app consulta releases do GitHub de forma resiliente e com timeout.
- Comparar versões semanticamente.
- Informar atualização disponível sem bloquear o usuário indevidamente.
- Direcionar para o APK correto ou página oficial.
- Não considerar prerelease como estável, salvo configuração explícita.
- Tratar ausência de internet e limites da API do GitHub.

## 19. CI/CD e versões

### Codemagic

O pipeline deve ser simples, determinístico e evitar trabalho duplicado.

Ordem recomendada:

1. preparar plataformas apenas quando ausentes;
2. configurar assinatura Android;
3. resolver dependências;
4. gerar ícones uma vez;
5. format check;
6. analyze;
7. testes;
8. build Android;
9. build Web;
10. publicar site somente quando credenciais Cloudflare estiverem disponíveis;
11. publicar GitHub Release apenas em tag/release prevista.

Regras:

- Não armazenar keystore, senhas ou tokens no Git.
- Referência de assinatura deve coincidir com a cadastrada no Codemagic.
- Grupos de ambiente precisam estar explicitamente importados pelo workflow.
- Falha opcional de publicação do site não deve apagar artefatos já gerados; separar responsabilidades quando possível.
- Evitar dois builds Android completos quando `--split-per-abi` ou cópia de artefatos puder resolver.
- Não gerar plataforma a cada build se os diretórios versionados estiverem corretos.
- Dependências devem ser compatíveis entre si e preferencialmente usar constraints justificadas, não pins arbitrários.

### Versionamento

- Usar SemVer: `MAJOR.MINOR.PATCH`.
- Atualizar `pubspec.yaml`, changelog e tag de maneira coerente.
- Nunca criar uma tag apenas para “forçar build” sem confirmar a versão.
- Não sobrescrever uma release publicada silenciosamente.

## 20. Segurança e privacidade

- Segredos somente em variáveis seguras do provedor.
- Validar upload por tipo real, tamanho, extensão, páginas e limites.
- Sanitizar texto e metadados.
- Limitar OCR e parsing para evitar abuso de recursos.
- URLs assinadas quando necessário.
- RLS testada.
- Logs não podem conter tokens, senha, respostas privadas ou conteúdo sensível.
- Conteúdo público/privado precisa ser decisão explícita.
- Não prometer que código web pode ser escondido por F12; proteger dados e operações no servidor.

## 21. Testes e definição de pronto

Uma funcionalidade não está pronta apenas por compilar.

Antes de declarar conclusão:

1. `dart format` sem alterações pendentes.
2. `flutter analyze` sem erros ou warnings tratados como falha no CI.
3. `flutter test` aprovado.
4. Testes unitários para parser, versão, compactação e regras críticas.
5. Testes de widget para Focus Mode, estados vazios e login contextual.
6. Testes de integração para importar → revisar → publicar → fazer → finalizar.
7. Verificação em mobile pequeno e desktop.
8. Verificação light/dark.
9. Verificação com fonte ampliada e redução de movimento.
10. Verificação offline e retomada.
11. Nenhum dado demonstrativo confundido com conteúdo real.
12. Diff revisado para arquivos gerados, segredos e regressões.

## 22. Ordem de execução recomendada

### P0 — Produto utilizável

1. Diagnosticar estado real do repositório, schema, CI e ambientes.
2. Remover hardcodes de produção e criar estados vazios reais.
3. Garantir navegação de visitante e login contextual.
4. Corrigir login Google/e-mail e deep links Android/Web.
5. Garantir leitura de provas reais do backend.
6. Tornar tentativa, respostas locais, retomada e resultado confiáveis.
7. Corrigir ícones e marca em Android, Web e PWA.

### P1 — Importação confiável

1. Reestruturar extração mantendo página e coordenadas.
2. Resolver duas colunas.
3. Implementar detector estrutural com confiança.
4. Criar revisão humana eficiente.
5. Validar contra prova real de 80 questões.
6. Suportar discursivas sem correção automática falsa.

### P2 — Experiência de prova

1. Refinar Focus Mode mobile-first.
2. Cronômetros configuráveis e ocultáveis.
3. Navegação/revisão clara.
4. Sincronização e offline.
5. Resultado e prova dos erros.

### P3 — Rede social útil

1. URLs e IDs de questões.
2. Discussões por questão.
3. Seguir assuntos.
4. Comunidades sugeridas, ciclo de vida e moderação.
5. Busca e descoberta reais.

### P4 — Distribuição

1. Simplificar Codemagic.
2. Releases automáticas por tag.
3. Atualização do site e Flutter Web.
4. Checagem de atualização no aplicativo.
5. Medir tamanho e desempenho do APK.

## 23. Forma de trabalho esperada do Codex

Antes de alterar:

1. Ler este arquivo.
2. Executar `git status`.
3. Inspecionar arquivos relevantes e mudanças existentes.
4. Não sobrescrever trabalho do usuário.
5. Confirmar a causa do problema com evidências.
6. Propor um lote pequeno e verificável.

Durante a alteração:

- Fazer mudanças incrementais.
- Reutilizar design system e componentes existentes.
- Não criar abstrações sem consumidor real.
- Não adicionar pacote quando Flutter/Dart já resolve adequadamente.
- Não mascarar erro de build desativando análise, testes, minificação ou segurança sem justificativa explícita.
- Não trocar arquitetura inteira para resolver erro localizado.

Ao finalizar:

1. Formatar.
2. Analisar.
3. Testar.
4. Mostrar arquivos alterados e resultado das verificações.
5. Explicar riscos e pendências reais.
6. Não afirmar que algo foi testado se não foi possível executar.
7. Não fazer commit/push/tag/release sem autorização.

## 24. Primeira tarefa ao receber este contexto

Não começar implementando tudo. Primeiro produzir um diagnóstico do estado atual, comparando o repositório com estas diretrizes. Classificar cada item como:

- funcional;
- parcial;
- ausente;
- quebrado;
- não verificável no ambiente atual.

Depois propor o próximo lote P0 com o menor conjunto de mudanças capaz de entregar uma melhoria completa e testável.
