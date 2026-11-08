---
tipo: adr
area: domínio de questão e publicação
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/domain/models/exam.dart, lib/core/import/, lib/core/backend/, lib/features/publish/, supabase/migrations/]
sha: 2c62e309dc04e6d084b2dab2ccdb1f1a9ef0bb8d
confianca: alta
atualizado: 2026-11-08
---

# ADR-0002 — Modelo de questão, gabarito e publicação

- Status: **proposto**
- Responsável pela aprovação: responsável pelo projeto

## Contexto

O modelo atual não expressa o produto:

- `Question` não tem `format`, `contentVersion` nem `provenance`
  (`lib/domain/models/exam.dart:68-94`);
- `correctIndex` mora dentro da questão pública, embora o banco já separe
  `private.question_keys`;
- `QuestionFormat` existe no parser, mas é descartado na borda
  (`digital_exam_service.dart:193-203`), e toda questão baixada volta como
  `reviewed`;
- a publicação exige alternativas e gabarito em todas as questões
  (`exam_publication_service.dart:45-59`), bloqueando discursivas e prova
  objetiva sem gabarito;
- `topic` vira `Geral` e `p_source_type` vira `community` na publicação
  (`exam_publication_service.dart:64,80`);
- a validação está duplicada na tela (`publish_page.dart:1317-1344`) e no
  serviço, com critérios diferentes;
- existem cinco definições de pontuação convivendo, seis contando
  `unanswered` (ver [[../../03 - Domínios/Modelo de Domínio Atual|Modelo de Domínio Atual]]).

O schema atual também bloqueia a correção: `public.questions` não tem coluna
`format` e impõe `jsonb_array_length(options) between 2 and 8`
(`202609210001_core.sql:45-47`). Discursiva com zero alternativas é rejeitada
pelo banco.

Evidência detalhada:
[[../../03 - Domínios/Contratos de Domínio Alvo|Contratos C1, C2, C3, C6 e C7]],
[[../../09 - Auditoria/Áreas/02 - Domínio, modelos e regras|Área 2 — Domínio]] e
[[../../09 - Auditoria/Áreas/10 - Publicação, pacotes, mídia e Storage|Área 10 — Publicação]].

## Decisão proposta

Adotar os contratos C1/C2/C3/C6 como tipos de domínio e uma única política de
publicação.

1. **`Question`** recebe `id` estável (`QuestionId`), `format`, `topicIds`,
   `media` como referências (sem `Uint8List`), `provenance` e `contentVersion`.
   `format` deixa de ser descartado na importação/download.
2. **`AnswerKey`** é uma entidade separada: `questionId`, `correctIndex?`,
   `source` (`official | community | unverified`) e `confirmedBy`. Ausência de
   gabarito é estado normal, não erro.
3. **`QuestionOutcome`** centraliza a regra: `correct`, `wrong`, `blank`,
   `unknownAnswer`, `excluded`. O denominador é
   `correct / (correct + wrong + blank)`; `unknownAnswer` e `excluded` ficam
   fora.
4. **`PublicationPolicy`** é a única fonte:
   - objetiva com gabarito confirmado e revisada → publicável;
   - objetiva sem gabarito confirmado → rascunho privado, não publicável;
   - discursiva (`openEnded`) → publicável sem correção automática;
   - `reviewState != reviewed` real → bloqueio;
   - `provenance == unverified` → exige confirmação explícita.
5. **Migration aditiva:** adicionar `format`, relaxar a restrição de
   alternativas para `openEnded`, manter `private.question_keys`, preservar
   `p_source_type` e `topic`. Não apagar colunas antigas antes de uma versão de
   compatibilidade.
6. **Borda de download:** não marcar `reviewed` automaticamente; preservar o
   estado de revisão e o formato recebidos.

## Alternativas

| Alternativa | Por que não |
|---|---|
| Manter o modelo atual e só ajustar a UI | A regra continua duplicada e o banco continua rejeitando discursiva. |
| Adicionar só um booleano `isOpenEnded` | Não resolve gabarito separado, versão, procedência nem estados de resultado. |
| Deixar `correctIndex` na `Question` | Expõe gabarito no conteúdo público e mantém a duplicação com `private.question_keys`. |
| Publicar discursiva com correção automática simulada | Viola a regra de não fingir correção objetiva. |
| Fazer a migration e o modelo em um único big-bang | Alto risco sobre importação, publicação e tentativas; contraria o strangler por fluxo. |

## Consequências e reversão

**Positivas:** um único contrato para importar, publicar, resolver e revisar;
discursiva deixa de ser cidadã de segunda classe; gabarito não vaza; resultado
tem denominador único; a tela e o serviço não podem mais divergir.

**Negativas:** exige migration e compatibilidade com dados antigos; os testes de
caracterização de pontuação vão mudar de forma deliberada; a UI de publicação e
resultado precisa ser ajustada em lote posterior.

**Reversão:** a migration é aditiva. Manter as colunas antigas e uma camada de
leitura permite voltar ao modelo anterior sem perder conteúdo. A separação de
`AnswerKey` é a mudança menos reversível; por isso ela vem com migração de dados
e testes antes de remover `correctIndex` do caminho público.

## Evidências e validação

- `lib/domain/models/exam.dart:68-94` — modelo sem formato/versão/procedência.
- `lib/core/import/question_parser.dart:252` — `QuestionFormat` já existe.
- `lib/core/backend/digital_exam_service.dart:193-203` — formato e revisão
  perdidos na borda.
- `lib/core/backend/exam_publication_service.dart:45-80` — validação duplicada,
  tópico e procedência apagados.
- `supabase/migrations/202609210001_core.sql:39-55` — schema e chave privada.
- `test/scoring_definitions_characterization_test.dart` — regras atuais
  congeladas; a mudança precisa ser deliberada.
- Validação necessária: 1 teste por formato; round-trip
  importação → rascunho → publicação → download → tentativa; prova de que
  `openEnded` passa e sem gabarito fica privada; aprovação do responsável.
