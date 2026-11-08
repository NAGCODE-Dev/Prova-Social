---
tipo: adr
area: versionamento de conteúdo
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/domain/models/exam.dart, lib/core/backend/attempt_draft_store.dart, lib/core/backend/attempt_sync_service.dart, lib/core/import/question_parser.dart, supabase/migrations/]
sha: 2c62e309dc04e6d084b2dab2ccdb1f1a9ef0bb8d
confianca: alta
atualizado: 2026-11-08
---

# ADR-0003 — Versionamento de conteúdo e vínculo da tentativa

- Status: **proposto**
- Responsável pela aprovação: responsável pelo projeto

## Contexto

A tentativa referencia apenas `exam.id`; as respostas são índices posicionais
(`Map<int,int>`), não IDs de questão. Editar ou reordenar a prova depois muda a
interpretação de uma tentativa antiga. O teste de caracterização mostra que a
mesma tentativa rende 2 acertos na ordem original e 0 na reordenada.

Hoje:

- `AttemptDraft` guarda `answers` por índice e `clientAttemptId`
  (`lib/core/backend/attempt_draft_store.dart:6-28`);
- a chave local é `attempt_draft_v1_$examId`
  (`attempt_draft_store.dart:72`);
- `ExamResult.toJson` grava `question: index + 1`
  (`lib/domain/models/exam.dart:215`);
- não existe `ContentVersion`, `Attempt` nem vínculo com a versão resolvida;
- `ImportedQuestionVersion` (`question_parser.dart:206`) é versão de enunciado
  dentro da importação, não versão de conteúdo publicado;
- o hash do benchmark identifica arquivos por caminho
  (`test/local_corpus_benchmark_test.dart:47`), não é versão de conteúdo.

Evidência detalhada:
[[../../03 - Domínios/Contratos de Domínio Alvo|Contratos C4 e C5]] e
[[../../09 - Auditoria/Áreas/06 - Tentativas, resultados e pontuação|Área 6 — Tentativas]].

## Decisão proposta

1. **Criar `ContentVersion`:** `contentVersionId`, `examId`, `revision`,
   `questionsHash` (enunciado + alternativas + ordem), `answerKeyHash`,
   `publishedAt`. Uma versão publicada é **imutável**.
2. **Nova publicação gera nova versão:** mudança de enunciado, alternativa,
   ordem ou gabarito cria revisão; não sobrescreve a versão anterior.
3. **Tentativa vinculada à versão:** `Attempt` guarda `contentVersionId`,
   `answers: Map<QuestionId, int?>`, `markedForReview: Set<QuestionId>` e
   `elapsedSeconds`.
4. **Retomada e resultado usam a versão:** o app carrega a versão resolvida, não
   apenas `examId`. Se a versão não existir, mostrar erro recuperável em vez de
   reinterpretar respostas.
5. **Migração de tentativas antigas:** converter índice posicional para
   `QuestionId` usando a ordem da versão conhecida no momento da migração.
   Tentativas sem versão identificável ficam somente leitura ou são marcadas
   como legado; não são apagadas silenciosamente.
6. **Hash separado:** `questionsHash` não inclui gabarito; `answerKeyHash` é
   independente para permitir corrigir gabarito sem fingir que o enunciado
   mudou.

## Alternativas

| Alternativa | Por que não |
|---|---|
| Continuar usando `examId` | Reordenar ou editar a prova reinterpreta respostas antigas. |
| Calcular hash só no resultado | Não vincula a tentativa no momento da resolução e não serve para retomada. |
| Versionar apenas o gabarito | O enunciado e as alternativas também mudam a interpretação. |
| Guardar uma cópia completa da prova em cada tentativa | Simples, mas duplica conteúdo e mídia; o hash/versão referenciada é mais barato. |
| Migrar tudo de uma vez e apagar o legado | Risco de perder tentativas; contraria a regra de migração reversível. |

## Consequências e reversão

**Positivas:** tentativas antigas continuam interpretáveis; comparação de
evolução tem referência estável; edição de conteúdo não reescreve o passado;
sincronização pode validar a versão entregue.

**Negativas:** mais uma entidade e migration; o app precisa lidar com versão
ausente; respostas passam de índice para `QuestionId`; testes de retomada
mudam.

**Reversão:** manter a leitura legada por uma versão. Se a migração falhar, o
app continua lendo o formato antigo e marca a tentativa como legado; a versão
nova fica aditiva.

## Evidências e validação

- `lib/core/backend/attempt_draft_store.dart:6-28,72` — respostas posicionais e
  chave por `examId`.
- `lib/domain/models/exam.dart:215` — serialização por índice.
- `test/draft_resume_characterization_test.dart` — retomada posicional
  congelada.
- Validação necessária: duas versões da mesma prova não se misturam; retomada
  após reordenação usa IDs estáveis; tentativa antiga migra ou fica legível;
  aprovação do responsável.
