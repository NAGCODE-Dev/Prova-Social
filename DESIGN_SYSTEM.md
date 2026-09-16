# Study Surface — regras oficiais

## Princípios

- Uma ação principal por tela.
- Resposta visual imediata a todo toque.
- Cor tem significado e nunca é o único indicador de estado.
- Cards representam objetos independentes; nem todo conteúdo vira card.
- Durante a prova, a navegação social desaparece.
- Loading preserva a geometria do conteúdo com skeleton contextual.
- Movimento explica estado, respeita redução de animações e não bloqueia ações.

## Tokens

- Espaçamento: 4, 8, 16, 24, 32 e 48 px.
- Raios: 8, 12, 16 e 20 px.
- Marca: `#16A36A`.
- Fundo claro: `#F7F8F6`; fundo escuro: `#101311`.
- Movimento: 100, 180, 280 e 400 ms.

## Focus Mode

- Leitura limitada a 820 px.
- Cronômetro isolado para não reconstruir a questão.
- Navegador lateral no desktop e faixa horizontal no mobile.
- Barra de ações fixa no mobile.
- Estados respondida, em branco e revisar usam texto, ícone e borda.
- Entrega sempre abre uma revisão das pendências.

## PDF

Arquivo → identificação → processamento → revisão → publicação.

O app nunca inventa progresso: enquanto o extrator não estiver conectado, a
interface informa claramente esse estado. O PDF original não é distribuído;
JSON GZip e figuras otimizadas são os objetos consumidos pelo app.
