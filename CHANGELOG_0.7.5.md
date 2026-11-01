# Prova Social 0.7.5

## Correções visuais

- A tela inicial não abre mais com fundo branco no aplicativo e no navegador.
  A porta de atualização pintava uma caixa da paleta clara por cima do fundo
  esmeralda, que é compartilhado por todas as telas.
- Splash e janela do Android usam a cor da marca também quando o sistema está
  em modo claro, com ícones da barra de status legíveis sobre o fundo escuro.
- Cartões, campos e botões do tema escuro foram normalizados para os mesmos
  tamanhos do tema claro e compactados no celular, onde ocupavam altura
  excessiva.

## Conta e navegação

- Sair da conta atualiza o perfil para visitante imediatamente, sem depender
  somente do evento assíncrono de autenticação, e informa quando a saída falha.
- "Agora não" fecha a tela de login quando ela é a primeira rota da pilha, em
  vez de não responder ao toque.
- Falhas no fluxo de estado de autenticação são registradas para diagnóstico.

## Web e distribuição

- O scaffold do Flutter Web passou a ser versionado com as cores da marca,
  `theme-color`, `manifest.json`, favicon e ícones PWA próprios, substituindo
  o azul padrão do Flutter nas páginas publicadas.

## Qualidade

- Testes de regressão cobrem o fundo da tela inicial, o rótulo de revisão com
  uma única questão errada e a idempotência do preparador Web, preservando o
  `base href` usado pelo deploy.
