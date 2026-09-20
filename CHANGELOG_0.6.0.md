# Prova Social 0.6.0

## Experiência inicial

- Onboarding em três telas com prévias das principais funções.
- Entrada como visitante sem conta obrigatória.
- Login solicitado somente para publicar, salvar ou sincronizar.

## Interface

- Nova marca com livro aberto em traço verde sobre fundo escuro.
- A marca oficial agora aparece no launcher, cabeçalhos e onboarding.
- Direção visual escura com verde luminoso, inspirada na referência aprovada.
- Provas exibidas em linhas compactas e escaneáveis.
- Opções de publicação transformadas em itens compactos.
- Seletor de PDF reduzido para aproveitar melhor telas pequenas.
- Perfil e cabeçalho usam dados reais da sessão.
- Estatísticas, progresso e nome demonstrativos removidos.

## Autenticação

- Confirmação por e-mail retorna para `provasocial://login-callback`.
- Nome Android alterado de `prova_social` para `Prova Social`.
- Permissão de internet incluída no manifesto Android release.

## Configuração externa necessária

Adicione `provasocial://login-callback` às Redirect URLs do Supabase seguindo
`GUIA_REDIRECT_LOGIN.md`.
