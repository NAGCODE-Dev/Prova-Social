---
tipo: adr
area: persistência local
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/core/backend/, lib/features/quiz/, test/, web/]
sha: 2c62e309dc04e6d084b2dab2ccdb1f1a9ef0bb8d
confianca: alta
atualizado: 2026-11-08
---

# ADR-0004 — Persistência local transacional

- Status: **proposto**
- Responsável pela aprovação: responsável pelo projeto

## Contexto

A persistência local é uma das partes mais sólidas do app: provas locais usam
gzip + SHA-256, há migração do formato antigo, escrita serializada e testes de
corrida. Rascunhos, respostas e fila de sincronização, porém, vivem em JSON
dentro de `SharedPreferences`.

Limites medidos:

- não há transação entre rascunho, resposta e fila;
- um JSON corrompido pode esconder a tentativa;
- não há backup restaurável pelo usuário;
- no Web, `SharedPreferences` depende de quota do navegador;
- não há criptografia em repouso para prova privada, gabarito e respostas;
- a resposta é um índice posicional, não um ID estável de questão.

Evidência detalhada:
[[../../09 - Auditoria/Áreas/07 - Persistência local, backups e provas locais|Área 7 — Persistência]]
e [[../../09 - Auditoria/Áreas/08 - Sincronização, offline, idempotência e conflitos|Área 8 — Sincronização]].

## Decisão proposta

Adotar uma migração **em fases** para armazenamento transacional, sem big-bang:

1. **Camada de contrato primeiro:** extrair uma porta de persistência para
   tentativas/rascunhos/fila, com operações atômicas e versão de schema.
2. **Mobile:** usar SQLite transacional (implementação a escolher entre `drift`
   e `sqflite` no plano de execução) para tentativas, respostas, rascunhos e
   fila. Chaves e índices por `attemptId`, `examId` e `questionId`.
3. **Web:** manter um adaptador compatível com IndexedDB (por exemplo, o backend
   Web do `drift`) ou, até ele existir, manter JSON com escrita atômica,
   backup e tratamento explícito de quota. O contrato da porta não muda.
4. **Migração reversível:** ler o JSON legado, gravar no novo store, manter o
   legado por uma versão e só removê-lo após testes de retomada e rollback.
5. **Backup e corrupção:** exportar/importar pacote versionado, validar
   `schemaVersion`, preservar o último estado bom e nunca apagar a tentativa por
   falha de leitura.
6. **Privacidade:** decidir criptografia em repouso em ADR próprio; não
   prometer segurança que o armazenamento atual não oferece.

## Alternativas

| Alternativa | Por que não |
|---|---|
| Continuar só com JSON/SharedPreferences | Simples, mas não dá transação, consulta, migração estruturada nem proteção contra corrupção. |
| Migrar tudo de uma vez para SQLite | Alto risco sobre dados de tentativa; contraria a regra de migração reversível. |
| Usar apenas IndexedDB/Web | Não resolve o mobile nativo nem o offline do app. |
| Armazenar respostas apenas no servidor | Viola o requisito de não perder respostas offline e de funcionar como visitante. |
| Criptografar o JSON atual | Ajuda na privacidade, mas não resolve transação, corrupção e consulta. |

## Consequências e reversão

**Positivas:** respostas e fila sobrevivem a crash com atomicidade; consultas por
tentativa/questão; migração versionada; base para retomada e sincronização
confiáveis.

**Negativas:** nova dependência nativa; custo de migração e de testes em
Android/Web; necessidade de adaptador Web; risco de regressão se o legado for
removido cedo.

**Reversão:** manter o JSON legado por uma versão e uma flag de leitura. Se a
migração falhar, o app volta ao store antigo sem perder dados. A porta de
persistência permite trocar a implementação sem tocar nas telas.

## Evidências e validação

- `lib/core/backend/attempt_draft_store.dart` — JSON em `SharedPreferences`.
- `lib/core/backend/attempt_sync_service.dart` — fila e retry.
- `lib/core/backend/local_exam_store.dart` — gzip, hash e migração de formato.
- `test/draft_resume_characterization_test.dart` — retomada posicional.
- Validação necessária: teste de morte de processo, corrupção, migração e
  retomada; benchmark de tamanho/tempo; aprovação do responsável.
