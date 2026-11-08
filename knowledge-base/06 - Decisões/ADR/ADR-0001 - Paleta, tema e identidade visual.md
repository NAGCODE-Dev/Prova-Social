---
tipo: adr
area: identidade visual
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/core/theme/, lib/app.dart, site/, AGENTS.md, DESIGN_SYSTEM.md]
sha: 2c62e309dc04e6d084b2dab2ccdb1f1a9ef0bb8d
confianca: alta
atualizado: 2026-11-08
---

# ADR-0001 — Paleta, tema e identidade visual

- Status: **proposto**
- Responsável pela aprovação: responsável pelo projeto

## Contexto

A identidade está dividida em três lugares:

- o app força `ThemeMode.dark` (`lib/app.dart:23`) e usa `EmeraldColors`
  (`#050907`, `#101A15`, `#20D99A`) em 113 referências;
- o `AGENTS.md` §3 define tokens escuros `#101311`, `#181C19`, `#F3F5F3`,
  `#2A302C` e tokens claros;
- o site usa `#101311` e carrega Inter do Google Fonts.

O tema claro existe em `AppTheme.light`, mas é código morto. `AppColors` tem 36
referências contra 113 de `EmeraldColors`. A tipografia é `sans-serif`, sem
Inter empacotada. O `StudySurface` usa raio 18/24 em quase toda seção, contra a
regra de 12 px e “se tudo é card, nada é card”. O `ExamListTile` prioritário do
`AGENTS.md` §6 não existe; home e busca usam componentes diferentes.

Evidência detalhada:
[[../../09 - Auditoria/Áreas/16 - Design system e componentes|Área 16 — Design system]].

## Decisão proposta

1. **Paleta canônica:** adotar `EmeraldColors` como a identidade escura real do
   app, porque ela já é a paleta efetiva e evita reescrever 113 referências sem
   ganho de produto. Atualizar o `AGENTS.md` §3 e o site para os mesmos valores.
2. **Tema claro:** manter os tokens claros do `AGENTS.md` como base do
   `AppTheme.light` e implementar a escolha de tema em fase posterior. O app
   continua **dark-first**, não dark-only por acidente.
3. **Tipografia:** empacotar Inter ou declarar formalmente `system-ui` como
   decisão. Não manter `fontFamily: 'sans-serif'` como valor implícito.
4. **Componentes:** `ExamListTile` passa a ser o único componente de lista de
   prova em home, busca, biblioteca e perfil. Cards de seção usam raio 12;
   `StudySurface` fica restrito a painel/destaque.
5. **Acessibilidade:** contraste, alvo de 48 px e `textScaler` entram no
   critério de aceite da mudança de tema (ADR-0012).

## Alternativas

| Alternativa | Por que não |
|---|---|
| Migrar o app para os tokens do `AGENTS.md` | Alinha ao documento, mas troca a identidade visual efetiva e exige revisar 113 usos; o ganho precisa ser provado com goldens e teste de contraste. |
| Manter dark-only e documentar | Menos trabalho, mas mantém o tema claro como código morto e não resolve a divergência com o site. |
| Criar uma terceira paleta | Aumenta a divergência; o problema atual é justamente não haver uma fonte única. |
| Deixar a decisão para o redesign | A dívida continua enquanto Focus, catálogo e site evoluem sobre cores diferentes. |

## Consequências e reversão

**Positivas:** uma identidade reconhecível entre app, site, manifest e ícones;
menos cores hardcoded; tema claro deixa de ser código morto; listas de prova
consistentes.

**Negativas:** atualizar `AGENTS.md` é mudança na fonte normativa; o site e os
ícones precisam ser alinhados; empacotar Inter aumenta o artefato.

**Reversão:** a paleta é uma camada de tokens. Se a decisão mudar, basta trocar
os valores em `EmeraldColors`/`AppColors` e regenerar goldens; nenhum dado ou
contrato de domínio depende disso.

## Evidências e validação

- `lib/app.dart:20-23` — `AppTheme.light` existe, mas `ThemeMode.dark` é fixo.
- `lib/core/theme/` — `EmeraldColors` e `AppColors` convivem.
- `site/` — usa `#101311` e Inter externa.
- `AGENTS.md` §3 — tokens claros e escuros documentados.
- Validação pendente: goldens de `ExamListTile`, contraste, alvo de 48 px e
  decisão sobre Inter; aprovação do responsável.
