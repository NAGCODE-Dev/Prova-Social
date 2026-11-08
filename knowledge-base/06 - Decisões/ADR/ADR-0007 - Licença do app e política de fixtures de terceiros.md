---
tipo: adr
area: licença e conteúdo de terceiros
status: ACEITO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [README.md, pubspec.yaml, test/fixtures/, packages/paddleocr_android/]
sha: 2c62e309dc04e6d084b2dab2ccdb1f1a9ef0bb8d
confianca: media
atualizado: 2026-11-08
---

# ADR-0007 — Licença do app e política de fixtures de terceiros

- Status: **aceito** em 2026-11-08
- Responsável pela aprovação: responsável pelo projeto

## Contexto

- No momento da auditoria não existia `LICENSE` na raiz.
- O `README.md` dizia “código aberto para fins educacionais”, o que não é uma
  licença e não define direitos de uso, cópia, modificação ou redistribuição.
- O fixture VUNESP está versionado com `licenseStatus: not-verified` e
  `allowedForProductContent: false`.
- O PDF ENEM não está versionado e o teste correspondente é pulado no CI.
- O notice do PaddleOCR não licencia o aplicativo inteiro.
- Não há SBOM nem auditoria de licenças de dependências.

Licença é decisão jurídica do responsável. Este ADR organiza as alternativas;
não escolhe uma licença aberta por conta própria.

## Decisão

Aprovada em 2026-11-08: adotar duas regras independentes.

1. **Licença do aplicativo:** **todos os direitos reservados**. O arquivo
   [`LICENSE`](../../../LICENSE) na raiz registra a decisão e substitui a
   afirmação anterior de “código aberto”. O titular indicado é “Prova Social”;
   se houver pessoa jurídica distinta, o aviso de copyright deve ser ajustado
   pelo responsável.
2. **Fixtures de terceiros:** nenhum PDF, imagem ou trecho de prova de terceiro
   entra no produto, no site ou em release sem licença/autorização documentada.
   Fixtures sem licença verificada permanecem apenas para QA local, quando o uso
   for permitido, e não autorizam conteúdo de produto. O padrão para o CI é
   fixture sintética ou gerada pelo próprio projeto.

## Alternativas de licença

| Alternativa | Efeito | Risco/observação |
|---|---|---|
| Todos os direitos reservados (**aceita**) | Ninguém usa, copia ou redistribui sem autorização | Fecha contribuição externa e distribuição por terceiros; é o padrão seguro até uma decisão diferente |
| MIT | Permissiva, permite uso comercial e forks | Precisa de titular e aviso de copyright; não protege marca |
| Apache-2.0 | Permissiva, com concessão explícita de patentes | Mais formal; exige NOTICE e identificação do titular |
| GPL-3.0 | Copyleft forte; derivados precisam abrir o código | Pode conflitar com componentes proprietários e com a distribuição atual |
| Dupla licença (ex.: AGPL + comercial) | Modelo de negócio | Exige assessoria jurídica e gestão de contribuições |

## Política de fixtures

- `test/fixtures/import_corpus.json` deve continuar registrando origem, hash,
  status de licença e `allowedForProductContent`.
- Fixture com `licenseStatus: not-verified` não pode ser promovida a conteúdo de
  produto nem usada para afirmar suporte a uma banca.
- Prova real usada em benchmark precisa de autorização de uso para teste.
- Documento sintético é o padrão para CI e para testes que precisam rodar em
  qualquer máquina.
- Nenhum arquivo de prova é copiado para `knowledge-base/` ou para o app sem
  autorização.

## Consequências e reversão

**Positivas:** remove a ambiguidade do README; impede redistribuição não
autorizada; deixa claro por que o fixture VUNESP não é conteúdo de produto.

**Negativas:** sem licença aberta, o projeto não recebe contribuições externas
nem pode ser usado por terceiros; a decisão comercial fica pendente.

**Reversão:** trocar de “todos os direitos reservados” para MIT/Apache exige
substituir o `LICENSE`, manter o aviso de copyright e revisar o README. A
política de fixtures é independente da licença do app e permanece válida em
qualquer cenário.

## Evidências e validação

- `LICENSE` criado na raiz com “todos os direitos reservados”.
- `README.md` declara a licença e aponta para o `LICENSE`.
- `test/fixtures/README.md` e `test/fixtures/import_corpus.json` registram os
  limites dos fixtures.
- `AGENTS.md` §10 e §20 exigem autorização e não prometem conteúdo de terceiros.
- Pendente: revisar notices de dependências e confirmar o titular legal do
  copyright; isso não bloqueia a decisão de manter os direitos reservados.
