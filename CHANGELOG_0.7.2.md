# Prova Social 0.7.2

## Importação de provas

- O parser e o controle de qualidade identificam melhor lacunas, duplicações e
  inversões na numeração e encaminham estruturas inconsistentes para revisão.
- Diagnósticos técnicos locais usam fingerprints estruturais sem armazenar nem
  transmitir o conteúdo da prova.
- Fixture sintético de duas colunas com 80 questões adicionado à regressão do
  importador.

## Distribuição

- A geração de lockfiles Android agora valida a resolução nativa usada pelo
  build de release, incluindo dependências Kotlin escolhidas por variantes.
- Builds Android assinados e o pacote Web são gerados pela pipeline de release
  para tags SemVer.
- A suíte Flutter prepara o módulo PDFium antes dos testes de importação em CI.
