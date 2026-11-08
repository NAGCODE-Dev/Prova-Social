---
tipo: sintese
area: refatoração global
status: PARCIAL
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/, test/, qa/, supabase/, .github/workflows/, site/, web/, pubspec.yaml, packages/paddleocr_android/, AGENTS.md]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Síntese da refatoração global

> **Atualização de 2026-11-08 (Lote 1):** a numeração duplicada do `AGENTS.md`,
> os banners dos relatórios históricos, o README e a hierarquia documental foram
> corrigidos. Consulte [[../00 - Central/Hierarquia Documental|Hierarquia
> Documental]] e [[Documentação e Divergências|Documentação e Divergências]].
> O diagnóstico abaixo permanece como evidência da auditoria de 2026-11-04.

## Resumo executivo

As **18 áreas** foram auditadas contra o código, os testes, o banco, o CI, o site
e a documentação no SHA `05a8fc1`. O resultado não é um caso de reescrita: é um
caso de **evolução com refatorações localizadas**. O núcleo de importação,
persistência local e sincronização tem substância real; o que falta é fechar
contratos de produto, alinhar identidade e documentação, destravar a esteira e
completar o que ainda não existe.

**Placar:** 16 áreas **EVOLUIR**, 2 áreas **REFATORAR** (Domínio e Supabase) e
nenhuma área **MANTER** ou **REESCREVER**. A média geral dos oito critérios é
**2,92/5**. Os pontos mais fortes são clareza (3,44), segurança (3,39) e
portabilidade (3,33); os mais fracos são aderência ao `AGENTS.md` (2,17),
robustez (2,39) e testes (2,56).

O achado mais urgente não é de produto: a **`main` está vermelha** por
formatação em três probes versionados, o que bloqueia `web-ci` e
`android-release`. Em seguida vêm as **duas verdades documentais** (o
`AGENTS.md` tem duas seções 15, o vault não está rastreado, o README promete
imagens e “modo de demonstração” inexistentes e não há `LICENSE`) e a
**identidade dividida** (app em `EmeraldColors #050907`, site/`AGENTS.md` em
`#101311`, sem Inter empacotada e sem `ExamListTile`).

A ordem proposta começa por **destravar a esteira**, depois **fixar a fonte
única de verdade e as decisões**, em seguida **fechar os contratos de domínio,
publicação e backend**, e só então avançar para Focus/offline, importação,
identidade, distribuição e social. Nenhuma etapa autoriza código por si só:
cada lote exige tarefa explícita e, quando muda arquitetura ou produto, um ADR
aprovado.

## Baseline verificada

| Medida | Resultado |
|---|---|
| SHA | `05a8fc1aab92d43f58ad7da8b24e710f9874d281` |
| Versão | `0.7.5+15` |
| `lib/` | 60 arquivos Dart; 19.113 linhas |
| Testes | 296 aprovados, 1 ignorado |
| `flutter analyze` | limpo |
| `dart format --set-exit-if-changed` | **exit 1** em 3 probes |
| CI no SHA | run `41760190392`, job `QA Completo`, passo `QA estático` falhou |
| APK arm64 | 82,1 MB |
| APK universal local | 248,1 MB |
| Release `v0.7.5` | 3 APKs por ABI + zip Web; sem APK universal |
| Site publicado | `/app/version.json` em `0.7.5+15`, build 96, 2026-11-01 |
| Vault no Git | 0 arquivos rastreados |
| Áreas auditadas | 18 de 18 |

Evidências detalhadas em [[../00 - Central/Estado Atual|Estado Atual]],
[[../05 - Qualidade/Validação Atual|Validação Atual]] e nas notas de área.

## Placar por área

Ordem dos critérios: correção / testes / acoplamento / clareza / segurança /
robustez / aderência / portabilidade.

| # | Área | Classificação | Notas | Achado principal |
|---:|---|---|---|---|
| 1 | [[Áreas/01 - Núcleo, inicialização, backend e atualizações\|Núcleo]] | EVOLUIR | 3/3/3/4/4/2/3/3 | Bootstrap e atualização funcionam; robustez e tratamento de falha limitados. |
| 2 | [[Áreas/02 - Domínio, modelos e regras\|Domínio]] | **REFATORAR** | 3/2/3/4/3/2/2/4 | Modelo não distingue discursiva, versão e gabarito com clareza suficiente. |
| 3 | [[Áreas/03 - Autenticação, visitante e deep links\|Autenticação]] | EVOLUIR | 3/2/3/4/3/2/2/3 | Visitante funciona; deep links e OAuth sem teste dedicado. |
| 4 | [[Áreas/04 - Catálogo, busca, feed, biblioteca e perfil\|Catálogo e listas]] | EVOLUIR | 3/2/2/4/4/2/2/4 | Home e busca usam componentes e hierarquias diferentes para a mesma prova. |
| 5 | [[Áreas/05 - Focus Mode, timer, navegação e finalização\|Focus Mode]] | EVOLUIR | 3/3/3/4/4/3/2/3 | A tela mais importante tem apenas 1 teste de widget. |
| 6 | [[Áreas/06 - Tentativas, resultados e pontuação\|Tentativas e resultados]] | EVOLUIR | 3/3/2/3/3/2/2/3 | Resultado funciona; pontuação e revisão ainda dependem de regras não centralizadas. |
| 7 | [[Áreas/07 - Persistência local, backups e provas locais\|Persistência local]] | EVOLUIR | 4/4/3/4/4/3/3/3 | Boa cobertura; JSON em SharedPreferences limita transação e migração. |
| 8 | [[Áreas/08 - Sincronização, offline, idempotência e conflitos\|Sincronização]] | EVOLUIR | 4/4/3/4/5/3/3/3 | Fila e idempotência boas; conflito e morte de processo não testados. |
| 9 | [[Áreas/09 - Importação, OCR, parser e quality gate\|Importação e OCR]] | EVOLUIR | 3/3/2/3/3/3/3/4 | Especificação fechada; câmera, feedback e validação de campo ausentes. |
| 10 | [[Áreas/10 - Publicação, pacotes, mídia e Storage\|Publicação e mídia]] | EVOLUIR | 3/2/3/4/4/3/2/4 | Publicação bloqueia discursivas e prova sem gabarito; Storage não testado. |
| 11 | [[Áreas/11 - Social, discussões, comunidades e denúncia\|Social e comunidades]] | EVOLUIR | 3/2/4/4/3/2/1/4 | Quase todo o contrato social do `AGENTS.md` está ausente. |
| 12 | [[Áreas/12 - Supabase, schema, RLS e RPCs\|Supabase e RLS]] | **REFATORAR** | 4/3/3/3/4/3/2/4 | RLS de tentativas boa; RLS social, Storage e publicação sem cobertura. |
| 13 | [[Áreas/13 - OCR Android, PaddleOCR e digitalização\|OCR Android]] | EVOLUIR | 3/2/3/3/3/2/2/3 | Motor funcional, mas sem timeout, health check, teste nativo e UI sem porcentagem. |
| 14 | [[Áreas/14 - Testes, QA e benchmark\|Testes e QA]] | EVOLUIR | 3/3/3/3/3/2/2/2 | Suíte ampla; sem integração, cobertura, goldens e benchmark com baseline. |
| 15 | [[Áreas/15 - CI-CD, releases, site, Web e PWA\|CI/CD e distribuição]] | EVOLUIR | 3/2/3/3/3/2/2/3 | Release sem APK universal; site entrega arm64 para todos. |
| 16 | [[Áreas/16 - Design system e componentes\|Design system]] | EVOLUIR | 3/2/3/3/3/3/2/3 | Tokens claros existem, mas o app é dark-only com paleta não documentada. |
| 17 | [[Áreas/17 - Dependências e manutenção\|Dependências]] | EVOLUIR | 3/2/3/3/2/2/2/3 | APK de 82 MB, pins sem justificativa, sem licença/SBOM. |
| 18 | [[Áreas/18 - Documentação e divergências código × docs\|Documentação]] | EVOLUIR | 3/2/3/2/3/2/2/4 | Acervo valioso, mas sem hierarquia, versionamento e verificação. |

## Achados transversais

Os achados abaixo cruzam mais de uma área. Eles são a justificativa para a
ordem dos lotes e para os ADRs.

### 1. A esteira está vermelha e não é portátil

- `dart format --set-exit-if-changed lib test tool packages` falha em
  `test/_corpus_bench_probe_test.dart`, `test/_corpus_detail_probe_test.dart` e
  `test/_corpus_probe_test.dart`.
- Os probes usam caminho absoluto (`/home/nikolas/Downloads/Provas`), não têm
  `skip` e imprimem texto de provas no log.
- O run `41760190392` falhou no `QA Completo`; `web-ci` e `android-release`
  dependem dele e não rodam.
- O schedule noturno ignora `qa-full`, então “passa” sem testar código.
- Os 4 testes do site passam localmente, mas não rodam no CI.

**Áreas afetadas:** 14, 15, 18. **Consequência:** nenhuma tag publica release
até o gate ser corrigido.

### 2. Existem duas ou três verdades documentais

- O `AGENTS.md` numera **duas seções 15** (“Offline e sincronização” e “Base de
  conhecimento do projeto”).
- O vault é chamado de “versionado”, mas `git ls-files knowledge-base` = 0 e não
  há `.gitignore` no vault.
- O `README.md` promete importação de **imagens** e “modo de demonstração” que
  não existem; diz “código aberto” sem `LICENSE`.
- O `DESIGN_SYSTEM.md` declara fundo escuro `#101311`, mas o app usa `#050907`.
- `DEPENDENCY_COMPATIBILITY.md` é da versão 0.5.0; o app está em 0.7.5+15.
- `AUDIT.md`, `IMPLEMENTATION_REPORT.md`, `SECOND_PHASE_REPORT.md` e
  `PROVA_SOCIAL_CONTEXT.md` competem com o vault sem banner de histórico.

**Áreas afetadas:** 15, 16, 17, 18. **Consequência:** leitor e agente escolhem
a fonte que confirma a hipótese, não a que descreve o código.

### 3. A identidade visual está dividida

- O app força `ThemeMode.dark` e usa `EmeraldColors` (`#050907`, `#101A15`,
  `#20D99A`); o site usa `#101311`; o `AGENTS.md` §3 define `#101311`,
  `#181C19`, `#F3F5F3`, `#2A302C`.
- A tipografia é `fontFamily: 'sans-serif'`, sem Inter empacotada; o site carrega
  Inter do Google Fonts.
- `ExamListTile` não existe: a home usa `ExamCard` e a busca usa `ListTile`, com
  informações e pesos diferentes.
- `StudySurface` aplica raio 18/24 em quase toda seção, contra o raio 12 e a
  regra “se tudo é card, nada é card”.
- Não há `Hero`, tema claro em uso, goldens ou teste de contraste no app.

**Áreas afetadas:** 4, 15, 16, 18. **Consequência:** a marca não é reconhecível
entre app, site, manifest e documento.

### 4. O domínio ainda não expressa o produto

- Não há distinção explícita entre questão objetiva e discursiva no modelo.
- A publicação exige alternativas e gabarito em todas as questões, bloqueando
  discursivas e prova objetiva sem gabarito.
- A tentativa não está vinculada de forma explícita à versão do conteúdo
  resolvido, o que impede comparar evolução com precisão.
- O tema/tópico e a procedência não têm um contrato único entre importação,
  publicação e catálogo.

**Áreas afetadas:** 2, 6, 9, 10, 12. **Consequência:** importação, publicação e
resultado não compartilham o mesmo contrato.

### 5. O fluxo crítico não tem teste ponta a ponta

- Não existe `integration_test/`.
- O `AGENTS.md` §21 pede importar → revisar → publicar → fazer → finalizar; não
  há um teste único que percorra esse caminho.
- Focus Mode tem 1 teste de responsividade e nenhum de seleção, timer, revisão,
  finalização ou retomada.
- Login contextual e OAuth/deep link não têm teste dedicado.

**Áreas afetadas:** 3, 5, 7, 8, 9, 10, 14. **Consequência:** uma regressão de
passagem entre camadas pode atravessar toda a suíte verde.

### 6. A base de offline é boa, mas o contrato não está fechado

- Persistência local, compressão, hash e migração de preferências têm testes.
- A fila de sincronização, retry e idempotência são o ponto mais forte do
  código.
- Faltam: teste de morte de processo, resolução explícita de conflito,
  armazenamento transacional e prova de retomada após crash.
- O armazenamento é JSON em `SharedPreferences`, o que limita transação,
  consulta e migração de schema.

**Áreas afetadas:** 7, 8, 14. **Consequência:** a promessa “o usuário nunca
perde respostas” ainda não está provada em falha real.

### 7. A importação está entre a especificação e a implementação

- P1.0 (PDF/JSON/manual), parser, gabarito, quality gate e revisão funcionam.
- 105 testes do scanner passam; VUNESP real passa com 80 questões e o sintético
  com 80 em duas colunas.
- Faltam câmera/galeria (P1.1), fila de feedback (P1.2), validação de campo
  (P1.3), publicação de discursivas e estados estruturais no lugar da
  porcentagem.
- O motor Paddle/ML Kit funciona, mas não tem timeout, health check, teste
  nativo nem UI sem porcentagem.
- O fixture VUNESP tem licença não verificada; o PDF ENEM não está versionado.

**Áreas afetadas:** 9, 13, 14, 17, 18. **Consequência:** o produto não pode
prometer importação por imagem nem medir precisão/recall.

### 8. O backend tem RLS boa no que é testado, mas cobertura estreita

- RLS e idempotência de tentativas são testadas em PGlite.
- Não há teste de RLS de `profiles`, `comments`, `bookmarks`, `collections`,
  `posts`, `communities`, `reports`, Storage e `publish_exam`.
- O PGlite aplica todas as migrations, mas só faz asserções sobre tentativas.
- `scripts/local_db_test.sh` cobre concorrência real, mas não roda no CI.

**Áreas afetadas:** 10, 11, 12, 14. **Consequência:** um erro de política pode
expor ou bloquear dados sem o CI perceber.

### 9. O contrato social está quase todo ausente

- O `AGENTS.md` §13 define comunidades sugeridas, estados, ciclo de vida,
  moderação e proteções.
- O código tem discussão por questão e comentários, mas não tem entidades,
  telas ou consultas de comunidade, denúncia ou moderação.
- O `README.md` reconhece que comunidades não existem; a aderência da área 11 é
  **1/5**.
- A RLS social e o Storage não são testados.

**Áreas afetadas:** 4, 10, 11, 12. **Consequência:** a “rede social” do produto
é hoje discussão por questão, não comunidade.

### 10. A distribuição não fecha o contrato

- O `AGENTS.md` §17 exige APK universal; as releases `v0.7.4` e `v0.7.5` têm só
  três APKs por ABI.
- O site escolhe `arm64-v8a` como padrão para qualquer visitante; um aparelho
  32-bit baixa APK incompatível.
- Não há checksums, SBOM, CSP, HSTS ou `frame-ancestors`.
- O workflow não compara tag com `pubspec.yaml` nem com changelog.
- O Flutter Web é compilado três vezes no mesmo push/tag.
- O APK arm64 tem 82 MB; o universal local tem 248 MB.

**Áreas afetadas:** 15, 17. **Consequência:** a release existe, mas não é
completa, verificável ou segura para todos os aparelhos.

### 11. A manutenção de dependências é reativa

- Dependabot cobre quatro ecossistemas e OSV/npm audit rodam no CI.
- Quatro dependências diretas e uma de desenvolvimento estão atrasadas;
  `pdfrx 2.6.6 → 2.11.0` é um salto relevante.
- Cinco pins exatos não têm justificativa (`crypto`, `file_picker`,
  `google_mlkit_text_recognition`, `http`, `image`).
- `android/app/build.gradle.kts` assina release com a chave **debug**; o CI
  patcheia o arquivo em tempo de build.
- O lockfile Gradle é gerado só no CI; as actions são fixadas por tag, não SHA.
- O notice do Paddle declara ONNX Runtime `1.21.1`; o build usa `1.31.1`.

**Áreas afetadas:** 13, 15, 17. **Consequência:** o build local não representa
o de produção e o artefato não é totalmente rastreável.

### 12. Acessibilidade e performance não são medidas

- Há 18 usos de `Semantics` e 1 teste de semântica.
- Não há teste de contraste, alvo de 48 px, foco por teclado, `textScaler` 1.3
  em todas as telas ou `disableAnimations` nas animações principais.
- O botão salvar do `ExamCard` tem 40 px.
- Não há medição de tempo/memória do OCR, do Focus ou do APK.

**Áreas afetadas:** 5, 13, 14, 16, 17. **Consequência:** o produto pode excluir
usuários e não tem orçamento de desempenho.

### 13. Licença e conteúdo de terceiros são ambíguos

- Não há `LICENSE` na raiz.
- O fixture VUNESP está versionado com `licenseStatus: not-verified` e
  `allowedForProductContent: false`.
- O PDF ENEM de 90 questões está no `.gitignore` e o teste é sempre pulado no
  CI.
- O notice do Paddle não cobre todo o app.
- Não há SBOM nem auditoria de licenças.

**Áreas afetadas:** 9, 14, 17, 18. **Consequência:** distribuição e contribuição
ficam juridicamente ambíguas.

## Princípios da refatoração

1. **Não reescrever o que já funciona.** Importação, persistência local e
   sincronização têm valor; preservar contratos e cobrir com testes de
   caracterização antes de extrair.
2. **Uma fonte de verdade por assunto.** `AGENTS.md` normativo, vault para
   estado/decisões, raiz como histórico. Nenhum documento “oficial” sem
   hierarquia.
3. **Esteira verde antes de qualquer redesign.** Um gate vermelho contamina
   qualquer conclusão sobre o resto.
4. **Contrato antes de tela.** Modelo de questão, versão, gabarito e publicação
   precisam estar fechados antes de Focus, catálogo e social.
5. **Teste do fluxo, não só da peça.** O critério de pronto do `AGENTS.md` §21
   exige importar → publicar → fazer → finalizar.
6. **Decisão explícita vira ADR.** Paleta, APK universal, persistência, câmera,
   licença e comunidade não podem ficar implícitas.
7. **Nenhum dado real sem autorização.** Fixtures, conteúdo de prova, segredos e
   dados de usuário não entram no vault nem no CI.
8. **Lote pequeno, reversível e mensurável.** Cada lote tem pré-condição,
   critério de saída e rollback.

## Ordem dos lotes

A ordem abaixo é de dependência, não de calendário. Um lote só começa quando o
anterior tiver critério de saída comprovado. Lotes de trilhas diferentes podem
correr em paralelo apenas quando não compartilham arquivo ou decisão.

| Lote | Foco | Áreas | Pré-requisito | Critério de saída |
|---:|---|---|---|---|
| 0 | Destravar a esteira | 14, 15, 18 | Autorização de código | `main` verde; probes portáveis; site testado no CI |
| 1 | Fonte única e decisões | 16, 17, 18 | Lote 0 | `AGENTS.md` sem numeração duplicada; vault versionado; ADRs de identidade, licença e distribuição |
| 2 | Contratos de domínio, publicação e backend | 2, 9, 10, 12 | Lote 1 | Modelo cobre objetiva/discursiva/sem gabarito; RLS social testada; migrations revisadas |
| 3 | Tentativa, Focus e offline | 5, 6, 7, 8, 14 | Lote 2 | Teste ponta a ponta; cada requisito do §8 com teste; retomada após crash |
| 4 | Importação e OCR | 9, 13, 14, 17 | Lote 2 | P1.1–P1.3; UI sem porcentagem; benchmark com ground truth e baseline |
| 5 | Identidade, listas e acessibilidade | 4, 15, 16 | Lote 1 | Paleta única; `ExamListTile`; breakpoints; goldens; contraste e alvo de 48 px |
| 6 | Distribuição e supply chain | 15, 17 | Lotes 0 e 1 | APK universal + checksums + SBOM; site por ABI; tag/changelog validados; CSP |
| 7 | Social e comunidades | 4, 11, 12 | Lotes 2 e 6 | Comunidades, denúncia, moderação e RLS com testes |
| 8 | Observabilidade e performance | 9, 13, 17 | Lotes 3, 4 e 6 | Baseline de tempo/memória/tamanho; alerta de regressão |

### Lote 0 — Destravar a esteira

- Formatar ou retirar da suíte os três probes; mover `test/_corpus_*` para
  `tool/` ou `test/manual/` com tag e `skip` quando o corpus não existir.
- Remover caminhos absolutos e impressão de conteúdo de prova no log.
- Rodar `qa-full` no schedule ou criar job noturno de testes.
- Incluir `node --test site/tests/site.test.cjs` no gate estático.
- **Saída:** `main` verde; `dart format` exit 0; suíte sem dependência de
  `/home/nikolas`; site testado em PR.

### Lote 1 — Fonte única e decisões

- [x] Corrigir a segunda seção 15 do `AGENTS.md` e definir a hierarquia documental.
- [x] Criar `.gitignore` no vault e versioná-lo com autorização.
- [x] Marcar documentos históricos da raiz com banner e índice do que está vigente.
- [x] Corrigir o README: remover imagens/demonstração ou implementá-las.
- [x] Decidir licença e adicionar `LICENSE` (ADR-0007 aceito: todos os direitos reservados).
- [ ] Registrar ADRs de paleta, distribuição, persistência, câmera e dependências;
      licença foi aceita (ADR-0007) e o vault tem proposta (ADR-0008).
- **Saída:** nenhuma contradição conhecida entre documento e código; toda
  decisão estrutural tem ADR.

### Lote 2 — Contratos de domínio, publicação e backend

- Definir no modelo: objetiva/discursiva, gabarito oficial/ausente, versão do
  conteúdo, tema/tópico e procedência.
- Vincular tentativa à versão exata do conteúdo resolvido.
- Publicação: discursiva publicável sem correção automática; objetiva sem
  gabarito só como rascunho/privada.
- Revisar migrations e RLS; ampliar PGlite para `profiles`, `posts`,
  `comments`, `bookmarks`, `collections`, `communities`, `reports`, Storage e
  `publish_exam`.
- **Saída:** contratos expressos em tipos e testes; usuário A não acessa dado
  privado de B; publicação oficial exige intenção explícita.

### Lote 3 — Tentativa, Focus e offline

- Teste de widget para seleção, persistência imediata, navegação, revisão,
  timer total/por questão, ocultar/revelar e modal de finalização.
- Teste de retomada após recriar o widget/processo.
- Teste de conflito e de entrega offline posterior.
- `integration_test/` com documento sintético pequeno percorrendo importar →
  revisar → publicar → fazer → finalizar.
- **Saída:** cada requisito do `AGENTS.md` §8 tem ao menos um teste nomeado; uma
  falha de rede não perde resposta.

### Lote 4 — Importação e OCR

- P1.1 câmera/galeria; P1.2 fila de feedback; P1.3 validação de campo.
- Remover porcentagem da UI; usar fazível/corrigível/não fazível.
- Permitir discursivas na importação e publicação sem correção automática.
- Timeout, health check e teste nativo do Paddle; teste de `MethodChannel`.
- Benchmark com ground truth autorizado, baseline de acurácia, tempo e memória.
- **Saída:** prova real de 80 questões sem instruções como questão; revisão
  humana eficiente; nenhuma métrica inventada.

### Lote 5 — Identidade, listas e acessibilidade

- ADR de paleta/tema; tokens únicos para app, site, manifest e ícones.
- Empacotar Inter ou declarar `system-ui` como decisão; completar `TextTheme`.
- Extrair `ExamListTile` e usá-lo em home, busca, biblioteca e perfil.
- Centralizar breakpoints; reduzir `StudySurface` a painel/destaque; cards com
  raio 12.
- Goldens de `ExamListTile`, `SourceBadge`, `Skeleton*`, alternativa e estados
  vazios; testes de contraste, alvo de 48 px e foco por teclado.
- **Saída:** uma identidade, um componente de lista, nenhum número mágico de
  largura e nenhuma mudança visual sem golden.

### Lote 6 — Distribuição e supply chain

- Publicar APK universal assinado além dos splits.
- Gerar `.sha256` e SBOM; anexar à release.
- Validar tag × `pubspec.yaml` × changelog; usar o changelog como corpo.
- Site: detectar ABI ou oferecer escolha manual; usar universal como padrão
  quando existir.
- CSP, HSTS, `Permissions-Policy` e `frame-ancestors`; auto-hospedar Inter ou
  remover a dependência externa.
- Reutilizar um único build Web entre QA, site e release.
- Orçamento de tamanho de APK e relatório por ABI.
- **Saída:** release completa, verificável e compatível com 32 e 64 bits.

### Lote 7 — Social e comunidades

- Modelar comunidades sugeridas, estados, ciclo de vida e fusão.
- Discussão por questão, denúncia, moderação e rate limiting.
- RLS social e Storage com testes.
- URLs canônicas e indexação apenas de conteúdo público legítimo.
- **Saída:** duas pessoas com intenção semelhante geram comunidade sugerida;
  comunidade inativa fica somente leitura e reabre; denúncia tem fluxo.

### Lote 8 — Observabilidade e performance

- Métricas agregadas sem conteúdo sensível.
- Baseline de tempo/memória do OCR e do Focus; alerta de regressão.
- Comparação Paddle vs ML Kit, escala de renderização e JPEG.
- Relatório de tamanho de APK por release.
- **Saída:** nenhuma regressão de performance passa sem issue; nenhum dado
  privado entra em telemetria.

## ADRs necessários

Os ADRs abaixo são **propostas**; nenhum foi aprovado nesta auditoria. O template
está em [[../Templates/ADR|Template de ADR]] e o índice de acompanhamento em
[[../06 - Decisões/ADR/README|ADRs propostos]].

| ID | Decisão | Áreas | Urgência |
|---|---|---|---|
| ADR-0001 | Paleta e tema: dark-only com `EmeraldColors` ou light+dark com tokens do `AGENTS.md` | 15, 16, 18 | Alta |
| ADR-0002 | Modelo de questão: objetiva/discursiva, gabarito e publicação | 2, 9, 10, 12 | Alta |
| ADR-0003 | Versionamento de conteúdo e vínculo da tentativa à versão resolvida | 2, 6, 12 | Alta |
| ADR-0004 | Persistência local: JSON/SharedPreferences vs SQLite transacional | 7, 8 | Alta |
| ADR-0005 | Distribuição Android: APK universal + splits e seleção de ABI no site | 15, 17 | Alta |
| ADR-0006 | Escopo de importação por câmera: implementar ou remover do README | 9, 13, 18 | Média |
| ADR-0007 | Licença do app e política de fixtures de terceiros | 9, 14, 17, 18 | Alta |
| ADR-0008 | Hierarquia documental e versionamento do vault | 18 | Alta |
| ADR-0009 | Política de dependências, pins e cadência de atualização | 17 | Média |
| ADR-0010 | Comunidades, moderação e ciclo de vida | 11, 12 | Média |
| ADR-0011 | Tamanho de APK, modelos sob demanda e componentes nativos | 13, 17 | Média |
| ADR-0012 | Acessibilidade, tema claro/escuro e meta de contraste | 14, 16 | Média |

## Riscos da execução

1. **Corrigir código antes de fechar contrato.** Refatorar Focus ou publicação
   sem ADR de domínio repete a dívida atual.
2. **Misturar documentação com release.** Um commit de docs não deve disparar
   tag nem publicar artefato.
3. **Migrar persistência sem fallback.** JSON em `SharedPreferences` pode
   perder respostas se a migração não for reversível.
4. **Publicar antes de testar RLS social.** Um erro de política pode expor
   comentários, denúncias ou dados privados.
5. **Correr para o social antes do domínio.** Comunidade em cima de modelo
   instável multiplica retrabalho.
6. **Redesenhar identidade sem decisão.** O app, o site e o `AGENTS.md` já
   divergem; uma terceira paleta pioraria.
7. **Aceitar APK de 82 MB como normal.** O público de concurseiros tem aparelho
   e conexão modestos; tamanho é requisito de produto.
8. **Tratar 296 testes verdes como pronto.** A distribuição de cobertura é
   desigual e o fluxo crítico não é coberto.
9. **Deixar o vault fora do Git.** A auditoria inteira pode ser perdida.
10. **Usar conteúdo de prova sem licença.** O fixture VUNESP não autoriza
    produto; o ENEM não está versionado.
11. **Automatizar decisão de produto.** Confiança, moderação e publicação
    exigem intenção explícita, não só score.
12. **Fazer refatoração big-bang.** Arquivos de 2.400 linhas convidam a
    reescrever; a regra é extrair uma responsabilidade por lote.

## Critérios de parada globais

- `flutter analyze` limpo e `dart format` exit 0.
- `flutter test` aprovado, com integração do fluxo crítico.
- `main` verde e release reproduzível.
- Nenhuma resposta perdida em offline, crash ou conflito.
- RLS testada para todo dado de usuário.
- Nenhum documento “oficial” contradiz o código sem banner ou ADR.
- Nenhum segredo, conteúdo privado ou prova sem licença no repositório.
- Toda decisão estrutural tem ADR com contexto, alternativas e validação.

## O que não foi verificado

- Estado do Supabase remoto, políticas aplicadas e dados reais.
- Execução em Android/iOS físico, emulador, navegador real e leitor de tela.
- Instalação de APK em aparelho 32-bit e 64-bit.
- Deploy Cloudflare e instalação do PWA nesta auditoria.
- Funcionamento do service worker e do fluxo de atualização com release real.
- Compatibilidade de `pdfrx 2.11` e `pdfium_flutter 0.4` com o código atual.
- Licença do PDF VUNESP e das demais fixtures.
- Ground truth autorizado para precisão/recall do parser e do OCR.
- Cobertura de linhas por arquivo.
- Desempenho e memória em aparelho de entrada.
- Renderização do vault no Obsidian após todas as alterações.
- Histórico Git do vault (se `workspace.json` já foi commitado em algum
  momento).

## Links

### Áreas

- [[Áreas/01 - Núcleo, inicialização, backend e atualizações|Área 1 — Núcleo]]
- [[Áreas/02 - Domínio, modelos e regras|Área 2 — Domínio]]
- [[Áreas/03 - Autenticação, visitante e deep links|Área 3 — Autenticação]]
- [[Áreas/04 - Catálogo, busca, feed, biblioteca e perfil|Área 4 — Catálogo]]
- [[Áreas/05 - Focus Mode, timer, navegação e finalização|Área 5 — Focus Mode]]
- [[Áreas/06 - Tentativas, resultados e pontuação|Área 6 — Tentativas]]
- [[Áreas/07 - Persistência local, backups e provas locais|Área 7 — Persistência]]
- [[Áreas/08 - Sincronização, offline, idempotência e conflitos|Área 8 — Sincronização]]
- [[Áreas/09 - Importação, OCR, parser e quality gate|Área 9 — Importação]]
- [[Áreas/10 - Publicação, pacotes, mídia e Storage|Área 10 — Publicação]]
- [[Áreas/11 - Social, discussões, comunidades e denúncia|Área 11 — Social]]
- [[Áreas/12 - Supabase, schema, RLS e RPCs|Área 12 — Supabase]]
- [[Áreas/13 - OCR Android, PaddleOCR e digitalização|Área 13 — OCR Android]]
- [[Áreas/14 - Testes, QA e benchmark|Área 14 — Testes]]
- [[Áreas/15 - CI-CD, releases, site, Web e PWA|Área 15 — CI/CD]]
- [[Áreas/16 - Design system e componentes|Área 16 — Design system]]
- [[Áreas/17 - Dependências e manutenção|Área 17 — Dependências]]
- [[Áreas/18 - Documentação e divergências código × docs|Área 18 — Documentação]]

### Notas centrais

- [[../00 - Central/Estado Atual|Estado Atual]]
- [[../00 - Central/Plano Mestre|Plano Mestre]]
- [[../00 - Central/Roadmap|Roadmap]]
- [[../00 - Central/Visão Geral|Visão Geral]]
- [[../08 - Agentes/Progresso|Progresso]]
- [[../05 - Qualidade/Validação Atual|Validação Atual]]
- [[Documentação e Divergências|Documentação e Divergências]]
- [[Áreas/Mapa das Áreas|Mapa das Áreas]]
- [[../02 - Arquitetura/Mapa de Módulos|Mapa de Módulos]]
- [[../Templates/ADR|Template de ADR]]

### Fonte normativa

- [AGENTS.md](../../AGENTS.md)
