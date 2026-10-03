# PROVA SOCIAL — CONTEXTO DO PROJETO

> Documento raiz de contexto técnico, produto, arquitetura e roadmap.
> Atualizado em 27/09/2026.

---

## 1. Visão do produto

**Prova Social** é uma plataforma mobile-first para digitalizar, organizar, resolver e compartilhar provas e questões.

A ideia central não é apenas oferecer um banco de questões. O produto conecta o documento original à experiência completa de estudo:

**prova física/PDF → digitalização/OCR → estruturação → revisão → publicação → resolução → tentativa → retomada/offline → sincronização → resultado → histórico**

### Princípio central

> **Preservar a prova e preservar a trajetória de quem estudou com ela.**

O produto deve permitir que uma prova que originalmente existia apenas em papel ou PDF se torne um conteúdo estruturado e reutilizável, sem perder sua origem, enquanto as tentativas e resultados do estudante formam um histórico contínuo.

---

## 2. Estado atual resumido

O projeto já ultrapassou a ideia de um simples protótipo ou banco de questões.

Há uma base funcional envolvendo:

- autenticação;
- onboarding;
- catálogo público;
- busca;
- favoritos;
- biblioteca;
- provas locais;
- importação de PDF;
- OCR;
- parser de questões;
- revisão antes da publicação;
- publicação comunitária;
- proveniência;
- execução de provas;
- marcação para revisão;
- salvamento de rascunho;
- retomada;
- submissão offline;
- sincronização;
- tentativas;
- proteção contra duplicidade/idempotência;
- resultados detalhados;
- desempenho por tópico;
- pacotes JSON compactados;
- SHA-256;
- mídia estruturada;
- backup local;
- QA automatizado;
- atualização por GitHub Releases.

O diferencial não está em uma única funcionalidade, mas na integração dessas partes.

---

# 3. Proposta de valor

## Para quem possui uma prova

Transformar uma prova física ou um documento existente em um conteúdo digital estruturado e reutilizável.

## Para quem estuda

Resolver provas, acompanhar tentativas, identificar desempenho e preservar sua evolução.

## Para a comunidade

Compartilhar provas e materiais de estudo que podem ser encontrados, salvos e resolvidos por outras pessoas.

## Para o produto

Criar uma base de conteúdo estruturado que possa evoluir para busca, estatísticas, organização, dúvidas e recursos sociais sem depender de um formato único de documento.

---

# 4. Diferencial de preservação

A preservação possui duas dimensões.

### 4.1 Preservação do documento

A prova deixa de depender exclusivamente do PDF ou da folha física original.

Fluxo previsto:

**foto/scan/PDF → OCR → estrutura → revisão → prova digital**

O documento original e seus elementos de mídia devem permanecer associados quando necessário.

### 4.2 Preservação da trajetória

A plataforma também preserva:

- provas realizadas;
- respostas;
- acertos e erros;
- questões não respondidas;
- marcações para revisão;
- tentativas;
- resultados;
- desempenho por tópico;
- progresso.

Assim, o conteúdo não termina quando o estudante envia a prova.

---

# 5. Arquitetura de conteúdo

Uma prova digital pode ser representada como um pacote estruturado.

Fluxo atual:

**payload JSON → UTF-8 → GZip → SHA-256 → armazenamento → download → descompressão → JSON**

O pacote possui metadados como:

- `sha256`;
- tamanho comprimido;
- tamanho descomprimido;
- `examId`;
- `schemaVersion`;
- referência aos arquivos de questões;
- índice de mídia.

### Armazenamento

O projeto possui infraestrutura para:

- Supabase Storage;
- bucket privado `exam-content`;
- metadados em `content_files`;
- políticas RLS;
- possibilidade arquitetural de provider `supabase_storage` ou `cloudflare_r2`.

### Cache

O `ContentDeliveryRepository` mantém cache em memória para pacotes já baixados durante a execução.

> Não assumir cache persistente em disco sem verificar implementação específica.

### Integridade

SHA-256 é utilizado para identificar/verificar o conteúdo comprimido.

---

# 6. Digitalização e OCR

A digitalização é uma das portas de entrada do produto.

## Fluxo

1. Usuário fornece PDF/imagem.
2. Páginas podem ser renderizadas.
3. OCR extrai texto.
4. O texto é normalizado.
5. `QuestionParser` identifica questões e alternativas.
6. Questões são transformadas em estruturas editáveis.
7. Usuário revisa/corrige.
8. Conteúdo validado pode ser publicado ou utilizado.

### OCR

Existe implementação nativa para Android/iOS usando reconhecimento de texto.

### Parser

O parser reconhece padrões como:

- `Questão N`;
- `Questao N`;
- numeração de questões;
- alternativas A–E;
- blocos de enunciado.

A normalização reduz diferenças de espaçamento e quebras de linha.

### Regra importante

OCR não é considerado infalível.

A revisão humana continua sendo parte importante do fluxo, especialmente para provas com layouts incomuns, imagens, tabelas ou formatação complexa.

---

# 7. Provas estruturadas

O domínio possui modelos para:

- prova;
- questão;
- alternativas;
- tópico;
- resultado;
- origem/proveniência.

Uma questão possui estrutura própria em vez de ser apenas texto bruto.

Isso permite:

- resolução;
- correção;
- busca por tópico;
- estatísticas;
- histórico;
- publicação;
- reutilização.

---

# 8. Proveniência

As provas possuem informações de origem.

Tipos existentes:

- `official`;
- `community`;
- `unverified`.

Também existe `sourceUrl`.

URLs de origem aceitas pelo modelo são restritas a HTTPS.

A interface possui indicação de origem/proveniência.

Objetivo: deixar claro ao estudante de onde o conteúdo veio, sem confundir material oficial com conteúdo comunitário.

---

# 9. Catálogo e busca

O catálogo público pode ser explorado sem login.

A busca considera informações como:

- título;
- descrição;
- categoria;
- fonte;
- nome da fonte;
- tópico das questões.

Características observadas:

- debounce de aproximadamente 350 ms;
- proteção contra resultados fora de ordem;
- limite de consulta;
- estados de carregamento;
- estados vazios;
- tratamento de erro;
- possibilidade de retry.

---

# 10. Biblioteca

A Biblioteca funciona como um hub do estado de estudo.

Pode reunir:

- provas salvas;
- provas locais;
- provas iniciadas;
- tentativas pendentes;
- resultados concluídos.

Favoritos são persistidos por meio da estrutura `favorites`.

A biblioteca, portanto, não é apenas uma coleção de PDFs: ela representa parte da trajetória do estudante.

---

# 11. Execução de provas

O fluxo de resolução inclui:

- seleção de respostas;
- navegação;
- marcação para revisão;
- saída com salvamento;
- retomada;
- finalização;
- submissão;
- resultado.

O estado da prova pode ser preservado para que o estudante continue posteriormente.

---

# 12. Offline e sincronização

Há suporte para fluxo de tentativa com possibilidade de trabalho offline.

Arquitetura observada:

**draft → attempt → pending sync → sync → result**

Componentes relacionados incluem:

- `AttemptDraftStore`;
- `AttemptSyncService`;
- `AttemptRepository`;
- `AttemptSubmission`.

Também existe mecanismo de `clientAttemptId` para reduzir risco de duplicação em reenvios.

Existe migração relacionada à idempotência; a implantação efetiva no ambiente remoto deve ser validada separadamente.

---

# 13. Integridade das tentativas

O sistema valida dados recebidos antes de aceitar uma tentativa/resultados.

As validações incluem elementos como:

- IDs;
- quantidade de questões;
- índices;
- respostas;
- marcações;
- contagens.

Objetivo: não aceitar cegamente uma resposta ou resultado inconsistente.

---

# 14. Resultados

O modelo de resultado contempla:

- total de questões;
- acertos;
- percentual;
- erros;
- não respondidas;
- tempo;
- data de finalização;
- respostas selecionadas;
- respostas corretas;
- marcações de revisão;
- desempenho por tópico.

O método `byTopic` permite agrupar desempenho por assunto.

Isso cria uma base para recursos futuros de análise de desempenho.

---

# 15. Persistência local

Provas privadas locais possuem armazenamento próprio.

O `LocalExamStore`:

- serializa dados em JSON;
- utiliza armazenamento local;
- mantém backup;
- valida estrutura;
- possui limites de tamanho;
- tenta recuperar dados por backup quando necessário.

Há proteção contra estruturas inválidas, incluindo limites de quantidade de questões/opções.

---

# 16. Publicação comunitária

O fluxo de publicação passa por validação.

Antes de publicar, o sistema verifica condições como:

- existência de questões;
- tamanho mínimo do enunciado;
- quantidade de alternativas;
- índice correto válido.

A publicação utiliza uma operação de backend/RPC.

O conceito é:

**importar → revisar → corrigir → validar → publicar**

A intenção é evitar que o conteúdo bruto do OCR seja imediatamente tratado como prova definitiva.

---

# 17. Navegação principal

A estrutura observada possui:

- **Início**
- **Explorar**
- **Publicar**
- **Biblioteca**
- **Perfil**

Há adaptação de navegação para diferentes larguras:

- navegação inferior no mobile;
- sidebar/top bar em telas maiores.

---

# 18. Autenticação

O projeto utiliza autenticação integrada ao backend.

O catálogo pode ser acessado sem conta em partes que não exigem dados pessoais.

Operações como salvar conteúdo e publicar exigem autenticação quando necessário.

A interface acompanha mudanças de estado de autenticação.

---

# 19. QA e CI

O projeto possui automação relacionada a:

- análise estática;
- testes Flutter;
- testes específicos de conteúdo;
- testes de draft;
- testes offline;
- testes de proveniência;
- CI/CD;
- builds Android.

Testes existentes verificam, entre outras coisas:

- compressão/restauração de conteúdo;
- integridade SHA-256;
- estrutura de provas;
- saída/retomada;
- submissão offline;
- proveniência.

---

# 20. Atualização do aplicativo

Existe código relacionado à verificação/atualização através de GitHub Releases.

A estratégia permite separar a distribuição do aplicativo do conteúdo armazenado no backend.

---

# 21. Design system

### Cores principais

**Verde**
`#16A36A`

### Light

- `#F7F8F6`
- `#FFFFFF`
- `#171A18`
- `#68706B`
- `#E3E7E4`

### Dark

- `#101311`
- `#181C19`
- `#F3F5F3`
- `#2A302C`

### Estados

- Amber: `#E5A524`
- Danger: `#DC4C4C`

Evitar:

- azul genérico como identidade principal;
- gradientes roxo/“AI”;
- excesso de texto;
- estética genérica de banco de questões.

Direção visual:

- limpa;
- funcional;
- mobile-first;
- minimalista;
- cards expansíveis;
- skeleton loading;
- botão `+` central;
- navegação simples.

---

# 22. Identidade

Direção de logo:

**verde da marca + livro aberto**

Existe preferência por uma versão que também funcione bem sobre fundo preto.

A identidade deve comunicar estudo/documento sem parecer uma plataforma genérica de IA.

---

# 23. Comunidade — estado atual

A base de publicação e descoberta comunitária já existe.

### Já observado

- catálogo público;
- publicação;
- busca;
- favoritos;
- origem da prova.

### Ainda não localizado como sistema independente

- dúvidas sociais completas;
- respostas/interações em dúvidas;
- destaque/boost de dúvidas;
- perfil social completo;
- sistema de verificação de perfil;
- moderação social completa;
- notificações sociais.

Esses itens não devem ser considerados implementados apenas por existirem modelos ou planos relacionados.

---

# 24. Monetização — direção planejada

Modelo pensado:

### Gratuito

Acesso ao núcleo do produto.

### Plus

Hipótese anteriormente considerada:

**R$ 7,90/mês**

Possíveis recursos:

- estatísticas avançadas;
- filtros e organização avançados;
- destaques;
- OCR/importação avançada;
- ausência de anúncios.

### Microtransações

Podem existir recursos pontuais relacionados a visibilidade/destaque.

Importante: qualquer monetização deve preservar transparência e não prejudicar o funcionamento básico do produto.

Os recursos de Plus, microtransações e anúncios ainda não devem ser marcados como implementados sem evidência no código/ambiente.

---

# 25. Privacidade e segurança

Princípios:

- conteúdo privado deve permanecer privado;
- RLS no backend;
- bucket privado para conteúdo protegido;
- permissões por proprietário;
- leitura pública condicionada quando o exame é público/publicado;
- URLs de origem seguras;
- validação de dados;
- rate limiting/moderação quando aplicável;
- logs e tratamento de erros.

Segurança é parte da arquitetura, não apenas uma etapa posterior.

---

# 26. O que diferencia o produto

Os diferenciais mais importantes atualmente são a combinação:

### 1. Digitalização de documentos reais

Uma prova física pode entrar no ecossistema.

### 2. Conteúdo estruturado

A prova não precisa permanecer presa ao PDF.

### 3. Preservação

Documento + questões + mídia + histórico podem formar uma continuidade.

### 4. Histórico de estudo

A tentativa não desaparece depois que a prova termina.

### 5. Offline

O fluxo de estudo pode continuar mesmo com conectividade limitada.

### 6. Comunidade

O conteúdo pode ser compartilhado e descoberto.

### 7. Proveniência

O usuário pode distinguir origem oficial, comunitária e não verificada.

### 8. Arquitetura modular

Conteúdo, mídia, tentativas e resultados possuem responsabilidades separadas.

---

# 27. O verdadeiro diferencial estrutural

O Prova Social não deve ser descrito apenas como:

> “um app para fazer provas”.

Uma descrição mais fiel à arquitetura atual é:

> **Uma plataforma que transforma provas em conteúdo digital estruturado e preserva a trajetória de estudo construída sobre elas.**

O diferencial está no ciclo:

**documento → conteúdo → estudo → tentativa → resultado → histórico**

Esse ciclo conecta duas coisas que normalmente ficam separadas:

**o documento que a pessoa estudou** e **a história do que ela fez com aquele documento**.

---

# 28. Definição de v1

A v1 deve ser considerada “praticamente operável” quando uma pessoa real conseguir:

1. instalar o aplicativo;
2. criar/importar uma prova;
3. digitalizar ou importar conteúdo;
4. revisar/corrigir;
5. salvar/publicar quando aplicável;
6. encontrar uma prova;
7. resolver;
8. pausar;
9. retomar;
10. finalizar;
11. receber resultado;
12. consultar histórico;
13. consultar desempenho;
14. utilizar recursos comunitários disponíveis;
15. fazer tudo isso sem intervenção do desenvolvedor.

A v1 não deve depender de telas falsas, dados mockados ou botões sem função.

---

# 29. Roadmap conceitual

## V1 — núcleo operável

Foco:

- conteúdo;
- digitalização;
- resolução;
- histórico;
- biblioteca;
- comunidade básica;
- persistência;
- segurança;
- QA.

## V1.x — refinamento

Foco:

- UX;
- performance;
- pesquisa;
- organização;
- melhorias no OCR;
- melhorias offline;
- observabilidade;
- moderação;
- confiabilidade.

## Fases posteriores

Possibilidades:

- dúvidas sociais;
- perfis;
- verificação;
- notificações;
- estatísticas avançadas;
- monetização;
- recursos sociais;
- escala de conteúdo.

---

# 30. Regras de classificação de estado

Usar os seguintes marcadores na documentação:

- `[IDEIA]` — apenas conceito.
- `[PLANEJADO]` — decidido para desenvolvimento futuro.
- `[EM DESENVOLVIMENTO]` — implementação em andamento.
- `[IMPLEMENTADO]` — existe no código.
- `[VALIDADO]` — implementação testada/verificada.
- `[PRODUÇÃO]` — funcionamento confirmado no ambiente de produção.

Não usar `[PRODUÇÃO]` apenas porque algo existe no repositório.

---

# 31. Mapa atual de capacidades

| Área | Estado observado |
|---|---|
| Auth | `[IMPLEMENTADO]` |
| Onboarding | `[IMPLEMENTADO]` |
| Catálogo público | `[IMPLEMENTADO]` |
| Busca | `[IMPLEMENTADO]` |
| Busca por tópico | `[IMPLEMENTADO]` |
| Favoritos | `[IMPLEMENTADO]` |
| Biblioteca | `[IMPLEMENTADO]` |
| Provas locais | `[IMPLEMENTADO]` |
| Importação PDF | `[IMPLEMENTADO]` |
| OCR | `[IMPLEMENTADO]` |
| Parser de questões | `[IMPLEMENTADO]` |
| Revisão antes da publicação | `[IMPLEMENTADO]` |
| Publicação comunitária | `[IMPLEMENTADO]` |
| Proveniência | `[IMPLEMENTADO]` |
| Execução de prova | `[IMPLEMENTADO]` |
| Marcar para revisão | `[IMPLEMENTADO]` |
| Salvar rascunho | `[IMPLEMENTADO]` |
| Retomar prova | `[IMPLEMENTADO]` |
| Submissão offline | `[IMPLEMENTADO]` |
| Retry/sync | `[IMPLEMENTADO]` |
| Idempotência | `[IMPLEMENTADO]` no código/migração |
| Resultado detalhado | `[IMPLEMENTADO]` |
| Resultado por tópico | `[IMPLEMENTADO]` no domínio |
| JSON/GZip | `[IMPLEMENTADO]` |
| SHA-256 | `[IMPLEMENTADO]` |
| Mídia estruturada | `[IMPLEMENTADO]` |
| Backup local | `[IMPLEMENTADO]` |
| QA automatizado | `[IMPLEMENTADO]` |
| Atualização por Releases | `[IMPLEMENTADO]` |
| Dúvidas sociais completas | `[NÃO LOCALIZADO]` |
| Perfil social completo | `[NÃO LOCALIZADO]` |
| Verificação de perfil | `[NÃO LOCALIZADO]` |
| Moderação social completa | `[NÃO LOCALIZADO]` |
| Plus | `[PLANEJADO]` |
| Microtransações | `[PLANEJADO]` |
| Anúncios | `[PLANEJADO]` |
| Notificações | `[PLANEJADO]` |

---

# 32. Pontos que ainda precisam de validação

A existência de código não significa automaticamente funcionamento completo em produção.

Devem ser confirmados separadamente:

- migrations aplicadas no projeto Supabase real;
- RLS efetivamente ativo;
- storage configurado;
- permissões de produção;
- sincronização real em diferentes condições de rede;
- idempotência no backend implantado;
- limites reais de armazenamento;
- atualização por GitHub Releases no aplicativo distribuído;
- performance do OCR em aparelhos reais;
- compatibilidade com layouts variados de provas;
- recuperação em caso de corrupção/interrupção;
- comportamento com grande volume de conteúdo.

---

# 33. Riscos de produto

## Complexidade

Quanto mais recursos forem adicionados, maior o risco de a experiência principal ficar difícil.

## OCR

OCR pode falhar em:

- tabelas;
- imagens;
- colunas;
- fórmulas;
- layouts incomuns;
- documentos de baixa qualidade.

A revisão manual precisa continuar simples.

## Conteúdo comunitário

Quanto maior a comunidade, maior a necessidade de:

- moderação;
- denúncias;
- controle de spam;
- proveniência;
- permissões.

## Infraestrutura

A separação entre conteúdo, mídia, tentativas e histórico aumenta flexibilidade, mas também exige observabilidade e testes.

---

# 34. Métricas importantes

Não medir apenas downloads.

Métricas úteis:

- provas importadas;
- taxa de conclusão da digitalização;
- tempo entre importação e primeira resolução;
- provas resolvidas;
- tentativas por usuário;
- taxa de retomada;
- taxa de submissão offline sincronizada;
- buscas realizadas;
- provas salvas;
- publicações;
- erros de OCR corrigidos;
- questões resolvidas;
- retenção;
- uso da biblioteca.

Uma métrica particularmente importante:

**documento digitalizado → primeira tentativa**

Ela mede se a principal proposta do produto realmente leva o usuário ao estudo.

---

# 35. Análise das capacidades já presentes — 27/09/2026

A inspeção do projeto mostrou que diversas capacidades que poderiam parecer “diferenciais futuros” já possuem base concreta.

## A. Prova como pacote estruturado

O conteúdo possui:

- JSON;
- compressão GZip;
- hash SHA-256;
- metadata;
- manifesto;
- arquivo de questões;
- referências de mídia.

Isso transforma a prova em um pacote de dados versionável/transportável.

## B. Mídia associada à questão

A infraestrutura possui `media_assets` e `exam_media`.

Isso permite associar imagens e outros elementos à posição/questão, em vez de tratar tudo como um único arquivo.

## C. Retomada e preservação offline

O sistema possui drafts, armazenamento local, tentativa pendente e sincronização.

Isso permite que o estado de estudo tenha continuidade.

## D. Proteção contra duplicidade

`clientAttemptId` e a infraestrutura de tentativa fornecem uma base para evitar que reenvios gerem múltiplas tentativas indevidas.

## E. Validação da correção recebida

O repositório de tentativas valida estruturas recebidas antes de aceitá-las.

## F. Preservação local

`LocalExamStore` possui backup e recuperação quando a leitura principal falha.

## G. Proveniência

A prova possui origem explícita e URL de fonte segura.

## H. Atualização

Há mecanismo relacionado a GitHub Releases para atualização do aplicativo.

## I. QA

O projeto já possui automação e testes cobrindo partes importantes do ciclo.

---

# 36. Diagnóstico de produto

A maior força atual não está em adicionar uma funcionalidade isolada.

Está na integração:

> **documento → digitalização → estrutura → revisão → publicação → resolução → tentativa → sincronização → resultado → histórico**

Isso significa que o próximo salto de qualidade deve priorizar:

1. experiência do primeiro uso;
2. confiabilidade;
3. OCR em cenários reais;
4. velocidade;
5. clareza da interface;
6. recuperação de erros;
7. conteúdo comunitário;
8. moderação;
9. análise de desempenho.

Adicionar tecnologia por adicionar não deve ser o objetivo.

---

# 37. Pergunta central para validar o produto

O principal teste de produto deve ser:

> **Uma pessoa que nunca viu o Prova Social consegue pegar uma prova física/PDF, digitalizá-la, revisar o resultado e começar a estudar sem precisar que o desenvolvedor explique o sistema?**

E, no outro lado:

> **Uma pessoa consegue encontrar uma prova, resolver, ver o resultado e voltar depois sem precisar entender a arquitetura por trás dela?**

Se os dois fluxos forem naturais, a infraestrutura existente passa a funcionar como uma vantagem real de produto.

---

# 38. Princípio de desenvolvimento

Priorizar:

**funcionalidade real > arquitetura desnecessária**

**experiência real > quantidade de telas**

**dados preservados > aparência**

**confiabilidade > novidade**

**conteúdo estruturado > PDF isolado**

**histórico de estudo > resultado descartável**

---

# 39. Frase de posicionamento interno

> **O Prova Social preserva tanto a prova quanto a trajetória de quem estudou com ela.**

Essa frase resume a conexão entre digitalização, conteúdo estruturado, resolução e histórico.

---

# 40. Nota de manutenção deste arquivo

Este documento é o contexto raiz do projeto.

Sempre que uma análise importante do produto, arquitetura, funcionalidades, roadmap ou estado de implementação for concluída, atualizar este arquivo antes de considerar o contexto encerrado.

Não marcar uma funcionalidade como `[VALIDADO]` ou `[PRODUÇÃO]` sem evidência correspondente.

Última atualização: **27/09/2026**.
