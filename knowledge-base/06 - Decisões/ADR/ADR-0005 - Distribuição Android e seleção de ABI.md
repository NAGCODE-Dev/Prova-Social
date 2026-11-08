---
tipo: adr
area: distribuição Android
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [.github/workflows/flutter-ci.yml, site/, android/, lib/core/update/]
sha: 2c62e309dc04e6d084b2dab2ccdb1f1a9ef0bb8d
confianca: alta
atualizado: 2026-11-08
---

# ADR-0005 — Distribuição Android e seleção de ABI

- Status: **proposto**
- Responsável pela aprovação: responsável pelo projeto

## Contexto

As releases `v0.7.4` e `v0.7.5` publicam apenas três APKs por ABI
(`arm64-v8a`, `armeabi-v7a`, `x86_64`) e o zip Web. O `AGENTS.md` §17 exige APK
universal assinado; ele não existe nas releases atuais.

O app nativo escolhe a ABI correta por `Build.SUPPORTED_ABIS` e tem fallback
para universal em releases antigas. O site, porém, procura primeiro um asset
`arm64-v8a` e o entrega a qualquer visitante; um aparelho 32-bit baixa o APK
errado e a instalação falha.

Tamanhos medidos: APK `arm64-v8a` com 82,1 MB; APK universal local com 248,1 MB.
A release também não publica checksums, SBOM nem valida tag × `pubspec.yaml` ×
changelog.

Evidência detalhada:
[[../../09 - Auditoria/Áreas/15 - CI-CD, releases, site, Web e PWA|Área 15 — CI/CD e distribuição]]
e [[../../09 - Auditoria/Áreas/17 - Dependências e manutenção|Área 17 — Dependências]].

## Decisão proposta

1. **Publicar os dois formatos:** APK universal assinado, exigido pelo
   `AGENTS.md`, e APKs por ABI para reduzir download.
2. **Site:** detectar ABI quando o navegador permitir; quando não for possível,
   mostrar escolha explícita e nunca servir `arm64-v8a` silenciosamente. O APK
   universal é o padrão quando existir.
3. **App:** manter a seleção por `SUPPORTED_ABIS` e o fallback para universal.
4. **Release:** validar tag, `pubspec.yaml` e changelog; anexar `.sha256` e SBOM;
   publicar os artefatos na mesma release.
5. **Tamanho:** medir o APK por ABI e o universal em cada release; tratar
   regressão de tamanho como requisito de produto, não curiosidade.

## Alternativas

| Alternativa | Por que não |
|---|---|
| Só APKs por ABI | Menor download, mas viola o `AGENTS.md` e deixa ABIs exóticas sem fallback. |
| Só APK universal | Compatível, mas 248 MB é inviável para parte do público e para conexão móvel. |
| Android App Bundle / Play Store | Resolve entrega por ABI, mas o produto distribui APK fora da loja e precisa de fallback direto. |
| Deixar o site como está | Entrega artefato incompatível e quebra a instalação em 32-bit. |

## Consequências e reversão

**Positivas:** instalação compatível em 32 e 64 bits; download menor para quem
escolhe a ABI; release verificável; site deixa de enganar o visitante.

**Negativas:** mais artefatos por release; armazenamento e tempo de build
maiores; o APK universal é pesado.

**Reversão:** a publicação é aditiva. Se o universal for descontinuado, o site
volta a exigir escolha explícita de ABI; nenhum dado de usuário depende do
formato do APK.

## Evidências e validação

- `.github/workflows/flutter-ci.yml` — publicação dos três APKs e do zip Web.
- `site/app.js:44-57` — seleção atual favorece `arm64-v8a`.
- `AGENTS.md` §17 — exige APK universal.
- Validação necessária: instalar universal e splits em aparelho 32-bit e 64-bit;
  testar o site com ABI desconhecida; conferir checksums; aprovação do
  responsável.
