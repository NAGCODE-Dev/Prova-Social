# Prova Social --- Contexto Mestre do Projeto

> Arquivo raiz de contexto do projeto. Atualizado em **27/09/2026**.
>
> Este documento reúne o contexto conhecido sobre o Prova Social para
> desenvolvimento, QA, arquitetura, UX/UI, produto, monetização e
> roadmap. Itens marcados como ideia ou planejados não devem ser
> tratados como implementados.

## 1. Visão geral

**Nome:** Prova Social\
**Repositório:** `NAGCODE-Dev/Prova-Social`\
**Tecnologia principal:** Flutter/Dart\
**Plataforma prioritária:** Android/mobile-first

### Ideia central

Digitalizar provas e transformá-las em uma experiência completa de
estudo:

``` text
Importar/Criar prova
→ OCR/Edição
→ Resolver
→ Pausar/Retomar
→ Finalizar
→ Corrigir
→ Histórico
→ Estatísticas
→ Identificar dificuldades
→ Praticar novamente
```

Além do núcleo de estudos, a **v1** deve incluir uma camada social:

``` text
Publicar prova
→ Biblioteca pública
→ Resolver/Favoritar
→ Dúvidas
→ Respostas
→ Destaques
→ Perfis
→ Denúncias/Moderação
```

O produto deve ser utilizável por uma pessoa que nunca viu o código, sem
depender do desenvolvedor.

------------------------------------------------------------------------

# 2. Objetivos

O Prova Social deve:

-   digitalizar provas;
-   usar OCR para acelerar a criação;
-   permitir correção manual do OCR;
-   permitir criação manual;
-   permitir resolução e retomada;
-   registrar respostas;
-   corrigir tentativas;
-   manter histórico;
-   gerar estatísticas reais;
-   ajudar o usuário a identificar dificuldades;
-   oferecer biblioteca pessoal;
-   oferecer biblioteca pública;
-   permitir publicação comunitária;
-   oferecer dúvidas e interação;
-   ter perfis;
-   ter moderação básica;
-   possuir monetização opcional;
-   preservar o estudo básico gratuito;
-   manter baixo custo operacional;
-   priorizar privacidade e segurança.

Pode atender ENEM, vestibulares, concursos, Barro Branco, provas
escolares, simulados e outras avaliações.

------------------------------------------------------------------------

# 3. Estado conhecido do repositório

Em uma verificação feita em **27/09/2026**:

-   repositório público;
-   `NAGCODE-Dev/Prova-Social`;
-   branch padrão: `main`;
-   linguagem principal: Dart;
-   issues abertas: 0 naquele momento;
-   tamanho aproximado: 1,3 MB;
-   tags conhecidas: `v0.2.0` a `v0.6.3`;
-   commit de `main` observado: `d74b3c2`;
-   desenvolvimento ativo;
-   não havia licença identificada na verificação.

Esses dados podem mudar e não devem ser tratados como estado permanente
sem nova verificação.

Documentação/estrutura conhecida:

-   `CODEX_QA_COMPLETO_PROVA_SOCIAL.md`
-   `docs/qa/`
-   `qa/`
-   workflows do Codemagic.

Um build observado em 26/09/2026 passou por:

``` text
Preparing build machine
Fetching app sources
Restoring cache
Installing SDKs
Preparar Flutter
QA estático
Testes Flutter
```

Os testes Flutter daquele build levaram aproximadamente 4m38s.

**CI verde não significa que todo o produto esteja pronto.**

------------------------------------------------------------------------

# 4. Princípios de desenvolvimento

Prioridade:

1.  funcionalidade real;
2.  persistência real;
3.  segurança;
4.  UX;
5.  baixo custo;
6.  privacidade;
7.  arquitetura sustentável;
8.  QA automatizado;
9.  capacidade de evolução.

Evitar:

-   telas falsas;
-   botões sem função;
-   dados mockados apresentados como reais;
-   hardcode indevido;
-   funcionalidades que só funcionam no happy path;
-   complexidade desnecessária;
-   estética genérica de aplicativo de IA.

------------------------------------------------------------------------

# 5. Stack e infraestrutura planejada

## App

-   Flutter
-   Dart
-   Android prioritário
-   mobile-first

## OCR

-   Tesseract/OCR ou solução compatível.

O OCR nunca deve ser tratado como perfeito. O usuário deve poder revisar
e corrigir.

## Backend/infrastrutura

Direções já discutidas:

-   Supabase;
-   Turso;
-   Cloudflare Pages;
-   Cloudflare R2;
-   Cloudflare Workers;
-   GitHub;
-   GitHub Releases;
-   Codemagic.

A arquitetura final dessas integrações precisa ser validada durante a
implementação. Não assumir que todas já estão funcionando.

------------------------------------------------------------------------

# 6. Design system

## Identidade

Verde esmeralda:

``` text
#16A36A
```

### Light

``` text
#F7F8F6
#FFFFFF
#171A18
#68706B
#E3E7E4
```

### Dark

``` text
#101311
#181C19
#F3F5F3
#2A302C
```

### Estados

``` text
#E5A524  revisão
#DC4C4C  perigo/erro
```

Evitar:

-   azul genérico como identidade;
-   gradiente roxo de IA;
-   excesso de cores;
-   interface carregada.

## UX

-   mobile-first;
-   limpa;
-   rápida;
-   pouco texto;
-   hierarquia visual forte;
-   skeleton loading;
-   estados vazios;
-   estados de erro;
-   feedback imediato;
-   dark mode;
-   acessibilidade.

## Cards

Ideia de cards de prova expansíveis, com informações principais visíveis
e detalhes sob interação. Long press pode ser utilizado quando fizer
sentido.

## Botão +

Botão verde centralizado na região inferior, abrindo opções como
criar/importar.

## Logo

Direção:

-   verde da identidade;
-   livro aberto;
-   versão sobre fundo preto;
-   simples e legível em ícone pequeno.

------------------------------------------------------------------------

# 7. Núcleo da v1

A definição atual é:

> **A v1 deve ser um produto praticamente operável, não apenas um MVP
> visual.**

Uma pessoa externa deve conseguir instalar e usar o aplicativo sem
intervenção do desenvolvedor.

## Provas

-   importar;
-   OCR;
-   revisão do OCR;
-   criar manualmente;
-   editar;
-   visualizar;
-   resolver;
-   pausar;
-   retomar;
-   finalizar;
-   corrigir;
-   salvar tentativa;
-   excluir/arquivar.

## Questões

-   alternativas;
-   resposta marcada;
-   questão em dúvida;
-   navegação;
-   correção;
-   explicação/observação quando houver.

## Histórico

-   provas;
-   tentativas;
-   resultados;
-   progresso;
-   retomada.

## Estatísticas

-   questões;
-   acertos;
-   erros;
-   percentual;
-   desempenho por prova;
-   matéria;
-   assunto quando os dados permitirem;
-   evolução;
-   tentativas;
-   dificuldades.

Não apresentar estatística que não possa ser calculada corretamente.

------------------------------------------------------------------------

# 8. Biblioteca pessoal

Possíveis categorias:

-   minhas provas;
-   em andamento;
-   concluídas;
-   favoritas;
-   importadas;
-   criadas;
-   simulados.

Importação privada não deve tornar uma prova pública automaticamente.

------------------------------------------------------------------------

# 9. Comunidade na v1

A camada social deve existir já na v1.

Funcionalidades:

-   publicar prova;
-   editar publicação própria;
-   excluir publicação própria;
-   biblioteca pública;
-   busca;
-   filtros;
-   visualizar autor;
-   favoritar;
-   denunciar;
-   moderação básica.

A publicação comunitária é diferente da importação privada.

------------------------------------------------------------------------

# 10. Limites de publicação

Modelo discutido:

-   importações pessoais podem ser livres;
-   publicações públicas podem possuir limite gratuito;
-   capacidade adicional pode ser vendida ou incluída no Plus.

O objetivo do limite é controlar:

-   armazenamento;
-   processamento;
-   moderação;
-   spam;
-   abuso;
-   custo da comunidade.

Os valores finais não estão definidos.

------------------------------------------------------------------------

# 11. Sistema de dúvidas

Na v1:

-   marcar questão como dúvida;
-   publicar dúvida;
-   visualizar;
-   responder/interagir;
-   acompanhar próprias dúvidas;
-   destacar dúvida.

## Destaque

Conceito discutido:

-   pagar para aumentar a visibilidade por determinado período;
-   exemplo hipotético: R\$1,99 por 24h.

Não vender resposta garantida. Vender visibilidade.

------------------------------------------------------------------------

# 12. Perfis

A v1 deve possuir:

-   nome/username;
-   avatar;
-   bio;
-   provas publicadas;
-   atividade;
-   estatísticas públicas configuráveis;
-   dúvidas;
-   configurações de privacidade.

------------------------------------------------------------------------

# 13. Perfil verificado

O conceito de **Perfil Verificado** pode existir na v1.

A interface deve explicar o que foi verificado, por exemplo:

-   identidade;
-   instituição;
-   informação específica.

Não tratar verificação como sinônimo de "pessoa confiável".

------------------------------------------------------------------------

# 14. Moderação

Base necessária:

-   denúncias;
-   spam;
-   conteúdo inadequado;
-   duplicatas;
-   abuso;
-   fraude;
-   remoção;
-   bloqueio/suspensão quando necessário;
-   registro mínimo de ações.

Pode começar simples e evoluir.

------------------------------------------------------------------------

# 15. Monetização

Princípio:

> Monetizar conveniência, visibilidade e recursos avançados, não o
> direito básico de estudar.

## Gratuito

Deve ser possível:

-   importar provas pessoais;
-   resolver;
-   corrigir;
-   histórico básico;
-   estatísticas básicas;
-   acessar biblioteca;
-   participar da comunidade dentro das regras.

## Prova Social Plus

Preço discutido como hipótese:

``` text
R$7,90/mês
```

Possíveis benefícios:

-   sem anúncios;
-   estatísticas avançadas;
-   filtros avançados;
-   organização avançada;
-   destaques incluídos;
-   OCR/importação avançados;
-   outros recursos premium.

Preço não é definitivo.

------------------------------------------------------------------------

# 16. Microtransações

Hipóteses já discutidas:

``` text
R$0,99 → +5 publicações
R$1,99 → destaque de dúvida
R$4,99 → 5 destaques
```

São apenas exemplos e precisam ser validados.

------------------------------------------------------------------------

# 17. Publicidade

Foi proposta a ideia de anúncios visualmente semelhantes a uma questão
de prova.

Se usada:

-   deve ser claramente identificada como publicidade/anúncio;
-   não pode parecer questão oficial;
-   não pode enganar o usuário;
-   não deve interromper uma questão de forma enganosa;
-   deve ter frequência controlada;
-   deve evitar formatos abusivos;
-   deve respeitar regras de publicidade.

O Plus pode remover anúncios.

------------------------------------------------------------------------

# 18. Backend e dados

Entidades conceituais possíveis:

``` text
User
Profile
Verification
Exam
Question
Alternative
Attempt
Answer
Subject
Topic
Doubt
DoubtHighlight
PublicExam
Favorite
Report
ModerationAction
Subscription
Purchase
Advertisement
Notification
```

Os nomes podem mudar.

Separar conceitualmente:

``` text
Conta
Perfil
Dados privados
Dados públicos
Conteúdo comunitário
Desempenho
Pagamento
Moderação
```

Usuário só deve editar seus próprios dados.

------------------------------------------------------------------------

# 19. Persistência

Dados críticos precisam sobreviver ao fechamento do app:

-   provas;
-   questões;
-   alternativas;
-   respostas;
-   progresso;
-   tentativas;
-   resultados;
-   perfil;
-   publicações;
-   dúvidas.

Não considerar uma função pronta se os dados desaparecem ao reiniciar.

------------------------------------------------------------------------

# 20. Offline e falhas

Tratar:

-   internet indisponível;
-   upload interrompido;
-   OCR falhando;
-   backend indisponível;
-   timeout;
-   sessão expirada;
-   sincronização parcial.

Nunca mostrar sucesso quando a operação falhou.

------------------------------------------------------------------------

# 21. OCR

Fluxo:

``` text
Imagem/PDF
→ OCR
→ Extração
→ Questões
→ Alternativas
→ Revisão
→ Correção manual
→ Salvar
```

O usuário deve poder corrigir erros do OCR antes de confiar na prova.

------------------------------------------------------------------------

# 22. IA

Objetivo de custo:

> manter processamento de IA barato.

IA não deve ser obrigatória para o núcleo.

Possíveis usos futuros:

-   explicação;
-   análise de erros;
-   recomendações;
-   geração de exercícios;
-   classificação de assuntos.

Precisão e custo devem ser avaliados antes de colocar recursos de IA no
produto.

------------------------------------------------------------------------

# 23. Arquitetura

Separação conceitual recomendada:

``` text
Presentation
    ↓
Application / Use Cases
    ↓
Domain
    ↓
Data
    ↓
Infrastructure
```

Evitar acoplamento excessivo da UI ao banco.

------------------------------------------------------------------------

# 24. Segurança

Prioridades:

-   autenticação;
-   autorização;
-   regras por usuário;
-   proteção de arquivos;
-   validação;
-   rate limiting;
-   prevenção de abuso;
-   logs sem exposição desnecessária;
-   proteção de dados pessoais.

------------------------------------------------------------------------

# 25. QA

QA é parte do desenvolvimento.

Já existe direção para:

-   QA estático;
-   testes Flutter;
-   documentação de QA;
-   Codemagic.

## Fluxo de prova

``` text
Criar/importar
→ salvar
→ abrir
→ responder
→ pausar
→ retomar
→ finalizar
→ corrigir
→ histórico
```

## Fluxo social

``` text
Criar publicação
→ publicar
→ encontrar
→ abrir
→ favoritar
→ denunciar
```

## Fluxo de dúvida

``` text
Marcar
→ publicar
→ visualizar
→ responder
→ destacar
```

## Conta

``` text
Cadastro
→ login
→ sessão
→ logout
→ retorno
```

## Monetização

``` text
Free
→ recurso premium
→ compra/assinatura
→ benefício
→ expiração/cancelamento
```

------------------------------------------------------------------------

# 26. CI/CD

Codemagic:

``` text
Push
↓
Checkout
↓
Dependências
↓
Análise estática
↓
Testes
↓
Build
↓
QA
↓
Artefato
```

Depois:

``` text
Release
↓
GitHub Release
↓
Distribuição
```

Pode existir verificação de atualização baseada em releases, respeitando
a forma de distribuição do Android.

------------------------------------------------------------------------

# 27. Roadmap

## v0.x --- fundação

-   arquitetura;
-   identidade;
-   navegação;
-   modelos;
-   autenticação;
-   banco;
-   importação;
-   OCR;
-   persistência;
-   histórico;
-   estatísticas;
-   QA;
-   CI/CD.

## v0.7--v0.9 --- produto utilizável

Foco em transformar telas e estrutura em fluxos completos:

-   criar/importar;
-   OCR;
-   revisar;
-   resolver;
-   pausar/retomar;
-   finalizar;
-   corrigir;
-   histórico real;
-   estatísticas reais;
-   biblioteca;
-   perfil;
-   configurações;
-   backend;
-   segurança;
-   tratamento de erros.

## v1.0 --- produto completo

Já deve incluir:

-   núcleo de provas;
-   OCR;
-   resolução;
-   correção;
-   histórico;
-   estatísticas;
-   biblioteca pessoal;
-   biblioteca pública;
-   publicação;
-   perfis;
-   dúvidas;
-   respostas/interação;
-   destaque de dúvidas;
-   denúncias;
-   moderação básica;
-   verificação;
-   anúncios;
-   Plus;
-   microtransações;
-   backend;
-   segurança;
-   persistência;
-   QA;
-   CI/CD.

## v1.x

Apenas depois do produto funcional:

-   recomendações avançadas;
-   IA;
-   gamificação;
-   feed sofisticado;
-   moderação automática;
-   notificações avançadas;
-   analytics;
-   otimização de custos;
-   escalabilidade;
-   recursos institucionais.

------------------------------------------------------------------------

# 28. Definition of Done

Uma feature só está pronta quando:

-   UI existe;
-   loading existe;
-   estado vazio existe;
-   erro é tratado;
-   dados persistem;
-   permissões estão corretas;
-   fluxo principal funciona;
-   falhas são tratadas;
-   teste relevante existe;
-   não depende indevidamente de hardcode;
-   funciona no Android alvo;
-   passou pelo QA necessário.

------------------------------------------------------------------------

# 29. Critério definitivo da v1

Pergunta:

> **"Consigo entregar o aplicativo para uma pessoa que não conhece o
> projeto e ela consegue utilizá-lo sozinha?"**

Se não, a v1 ainda não está pronta.

------------------------------------------------------------------------

# 30. Modelo comercial

``` text
Estudar → grátis
Resolver → grátis
Importar para si → grátis
Histórico básico → grátis
Estatísticas básicas → grátis

Convenience/recursos avançados → Plus
Visibilidade → microtransações
Capacidade comunitária → Plus/microtransações
Sem anúncios → Plus
```

A função educacional central não deve ser artificialmente bloqueada.

------------------------------------------------------------------------

# 31. Propriedade intelectual

O projeto deve poder ser:

-   mantido pelo criador;
-   licenciado;
-   vendido parcialmente;
-   vendido integralmente;
-   transformado em startup.

Para eventual negociação, conceitos mais adequados que uma "garantia de
lucro" incluem:

-   licença;
-   pagamento inicial;
-   remuneração variável;
-   earn-out;
-   participação;
-   prazo;
-   território;
-   exclusividade;
-   renovação;
-   rescisão;
-   condições objetivas de pagamento.

Uma negociação real deve ser feita com orientação jurídica e responsável
legal quando aplicável.

Ativos que devem ser considerados separadamente:

-   código;
-   marca;
-   nome;
-   logo;
-   identidade;
-   domínio;
-   design;
-   banco;
-   infraestrutura;
-   documentação;
-   know-how;
-   conteúdo;
-   versões futuras;
-   produtos derivados.

------------------------------------------------------------------------

# 32. Proteção contra abandono

Em eventual contrato podem ser definidos, com orientação jurídica:

-   inadimplência;
-   abandono;
-   falta de operação;
-   descumprimento;
-   rescisão;
-   eventual reversão/reaquisição quando cabível.

Objetivo: impedir que uma aquisição/licença simplesmente deixe o projeto
abandonado sem consequência contratual.

------------------------------------------------------------------------

# 33. Métricas futuras

Com usuários reais:

-   usuários ativos;
-   provas importadas;
-   provas resolvidas;
-   conclusão;
-   retenção;
-   questões respondidas;
-   publicações;
-   dúvidas;
-   respostas;
-   denúncias;
-   conversão Plus;
-   cancelamentos;
-   receita;
-   custo por usuário.

Não fabricar métricas.

------------------------------------------------------------------------

# 34. Valorização --- apenas referência hipotética

Cenários anteriormente discutidos:

``` text
Somente código:
~R$10 mil–R$40 mil

Produto com usuários:
~R$40 mil–R$150 mil

Startup com receita:
~R$150 mil–R$500 mil+
```

São estimativas ilustrativas, não avaliações garantidas.

Exemplo matemático:

``` text
2.000 assinantes × R$10/mês
= R$20.000 MRR
= R$240.000/ano
```

Isso também não é previsão.

------------------------------------------------------------------------

# 35. Regras para agentes de código

Qualquer agente trabalhando no repositório deve:

1.  ler este arquivo antes de grandes alterações;
2.  preservar decisões estabelecidas;
3.  não remover funcionalidades sem justificativa;
4.  não inventar integrações;
5.  não trocar dados reais por mocks sem deixar claro;
6.  preservar a identidade visual;
7.  manter mobile-first;
8.  priorizar funcionalidade real;
9.  executar testes após mudanças relevantes;
10. atualizar documentação quando uma decisão estrutural mudar;
11. diferenciar planejado de implementado.

------------------------------------------------------------------------

# 36. Estados de implementação

Usar estes estados:

``` text
[IDEIA]
Conceito não implementado.

[PLANEJADO]
Decidido para roadmap, mas não necessariamente implementado.

[EM DESENVOLVIMENTO]
Implementação em andamento.

[IMPLEMENTADO]
Código existente e funcional, ainda sujeito a QA.

[VALIDADO]
Implementado e validado por testes/QA.

[PRODUÇÃO]
Disponível para usuários reais.
```

Nunca assumir que algo está implementado apenas porque aparece neste
documento.

------------------------------------------------------------------------

# 37. Resumo executivo

O Prova Social é um aplicativo Flutter mobile-first para digitalizar,
organizar, resolver e analisar provas, com biblioteca social, perfis e
sistema de dúvidas.

A experiência central é:

``` text
Prova
→ Questões
→ Resolução
→ Correção
→ Histórico
→ Desempenho
→ Dificuldades
→ Prática
→ Comunidade
```

O modelo:

``` text
Core educacional gratuito
+
Comunidade
+
Publicidade
+
Plus
+
Microtransações
```

A **v1 é propositalmente mais ambiciosa**: deve ser praticamente
operável e já conter a camada social e a base de monetização, não apenas
o núcleo de resolução.

------------------------------------------------------------------------

## Última atualização

**27/09/2026**

Atualizar este arquivo quando houver mudança importante em:

-   arquitetura;
-   stack;
-   escopo;
-   roadmap;
-   modelo de negócio;
-   identidade visual;
-   segurança;
-   infraestrutura;
-   definição da v1.
