# Diagnóstico atual

Data: 2026-09-21. Base: leitura estática do repositório em `main`. O estado implantado do Supabase, do Codemagic e do site não foi verificado.

| Área | Classificação | Evidência |
| --- | --- | --- |
| Navegação visitante e onboarding | Parcial | Cinco abas e acesso sem login; intenção após login nem sempre é retomada automaticamente. |
| Provas públicas, busca e biblioteca | Parcial | Leitura do Supabase e filtro local; biblioteca e filtros incompletos. |
| Procedência | Parcial após este lote | Schema possui tipo e URL; modelo e interface passam a exibir os três tipos, com fallback conservador e link HTTPS. Dados implantados não verificados. |
| Focus Mode, retomada e resultado | Parcial | Rascunho local e correção por RPC; gravação local não aguardada e entrega depende de rede. |
| Importação | Parcial | PDF, OCR e revisão existem; parser linear não resolve coordenadas e duas colunas. |
| Questão social e comunidades | Parcial / ausente | Há SQL auxiliar, sem fluxo completo de discussão ou comunidades no app. |
| Schema e RLS | Parcial; implantação não verificável | Migrations têm políticas e RPC; execução e testes no projeto real não confirmados. |
| Marca e distribuição | Parcial; publicação não verificável | Ativos e workflows existem; plataformas são geradas no CI. |
| CI e atualização | Parcial | CI recria plataformas, formata e compila Android duas vezes. |
| Testes | Parcial | Testes unitários existentes; faltam integração e verificação visual. Flutter e Dart indisponíveis neste ambiente. |

## Riscos imediatos

- Confirmar no Supabase implantado a presença de `source_type` e `source_url` antes de distribuir este cliente.
- Executar `dart format --output=none --set-exit-if-changed .`, `flutter analyze` e `flutter test` no Codemagic. Nenhum deles foi executado localmente.
- Conferir o link e os três badges em tela pequena, desktop e temas claro/escuro.
