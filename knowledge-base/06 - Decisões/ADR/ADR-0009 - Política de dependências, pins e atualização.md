---
tipo: adr
area: dependências e supply chain
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [pubspec.yaml, pubspec.lock, .github/dependabot.yml, .github/workflows/flutter-ci.yml, android/, packages/paddleocr_android/]
sha: 2c62e309dc04e6d084b2dab2ccdb1f1a9ef0bb8d
confianca: alta
atualizado: 2026-11-08
---

# ADR-0009 — Política de dependências, pins e atualização

- Status: **proposto**
- Responsável pela aprovação: responsável pelo projeto

## Contexto

O projeto tem higiene acima da média: `pubspec.lock` versionado, Dependabot para
quatro ecossistemas, auditoria npm e OSV no CI. Ainda assim:

- quatro dependências diretas e uma de desenvolvimento estão atrasadas;
- `pdfrx 2.6.6 → 2.11.0` é um salto relevante e forma par frágil com
  `pdfium_flutter 0.3.1 → 0.4.1`;
- cinco pins exatos não têm justificativa documentada;
- o lockfile Gradle do app não está no repositório;
- as GitHub Actions são fixadas por tag, não por SHA;
- não há SBOM nem inventário consolidado de licenças;
- o notice do Paddle declara ONNX Runtime `1.21.1`, mas o build usa `1.31.1`;
- o `android/app/build.gradle.kts` versionado assina release com chave debug e o
  CI patcheia o arquivo em tempo de build.

Evidência detalhada:
[[../../09 - Auditoria/Áreas/17 - Dependências e manutenção|Área 17 — Dependências]].

## Decisão proposta

1. **Constraints por padrão:** usar `^`/faixas compatíveis. Pin exato só com
   comentário no `pubspec.yaml` dizendo motivo, versão testada e data de revisão.
2. **Atualização:** Dependabot mensal para pub, Gradle do app, npm do QA e
   Actions; correções de segurança entram assim que possível. Agrupar upgrades
   relacionados (`pdfrx` + `pdfium_flutter`, ML Kit, Paddle).
3. **Validação:** nenhum upgrade nativo entra sem teste de importação, build
   Android e smoke no aparelho; `pdfrx`/`pdfium` exigem teste dedicado.
4. **Supply chain:** fixar Actions por SHA; versionar o lockfile Gradle do app;
   gerar SBOM e inventário de licenças por release; comparar o notice do Paddle
   com o artefato real.
5. **Assinatura:** remover a chave debug do arquivo versionado e usar segredo de
   CI; o build local não deve fingir que é release.
6. **Tamanho:** medir APK por ABI e universal em cada release e registrar a
   variação.

## Alternativas

| Alternativa | Por que não |
|---|---|
| Congelar tudo em pins exatos | Reproduzível no curto prazo, mas acumula CVE e impede correções; o problema atual é justamente pin sem justificativa. |
| Atualizar sempre para a última versão | Risco alto em `pdfrx`/`pdfium`, ML Kit e Paddle; quebra o fluxo de importação sem aviso. |
| Só Dependabot, sem política | Já é o estado atual; produz PRs sem critério de merge e mistura pins antigos com `^`. |
| Não gerar SBOM | Impede rastrear licenças e componentes nativos na release. |

## Consequências e reversão

**Positivas:** atualizações previsíveis; pins explicados; release rastreável;
menos risco de licença e de dependência nativa quebrada.

**Negativas:** exige disciplina de revisão mensal; SBOM e lockfile aumentam o
trabalho de release; upgrades de `pdfrx` podem exigir mudanças de código.

**Reversão:** a política é de processo. Um pin emergencial pode ser aplicado com
justificativa e data de revisão; a política não impede correção pontual.

## Evidências e validação

- `pubspec.yaml` — cinco pins exatos sem justificativa.
- `.github/dependabot.yml` — quatro ecossistemas, sem `android/app`.
- `.github/workflows/flutter-ci.yml` — actions por tag e patch de assinatura.
- `packages/paddleocr_android/` — notice divergente.
- Validação necessária: rodar `flutter pub outdated`, teste de upgrade de
  `pdfrx`/`pdfium`, gerar SBOM de teste e aprovar a política.
