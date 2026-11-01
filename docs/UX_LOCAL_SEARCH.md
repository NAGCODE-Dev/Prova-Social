# Busca, provas privadas e publicação

A busca consulta Supabase (título, descrição, categoria, origem e tópico das
questões) e restringe todas as consultas a provas publicadas e públicas. O schema
atual não tem uma entidade separada de concursos: estes são encontrados pelos
metadados das provas. Cada consulta de campo retorna até 50 registros; não há
paginação neste lote. O debounce é de 350 ms e respostas de buscas anteriores
são descartadas. Os resultados abrem diretamente a prova. Filtros de ano,
categoria, banca/fonte, assunto e autor são derivados apenas dos resultados reais
retornados; o nome do autor vem do perfil público quando disponível. Até oito
consultas recentes são persistidas localmente. Não há sugestões de conteúdo
inventadas. A tela diferencia catálogo sem resultados de filtros sem
correspondências.

Na Home, o botão de filtros usa os mesmos campos e valores reais da busca, mas
se limita às provas já carregadas no catálogo. A contagem indica esse escopo;
quando não há correspondências, a tela permite limpar os filtros e informa se
há mais provas para carregar. As linhas da lista mantêm procedência, ano,
categoria, quantidade de questões e duração visíveis, adaptando título e
metadados a telas estreitas e fontes ampliadas.

Antes de pesquisar, Explorar mostra buscas recentes (quando existirem) e
exemplos de pesquisa por tema e fonte oficial. São atalhos para consultas reais,
não uma afirmação de que esses materiais já existem no catálogo. Não exibe
estados de resultado vazio nem aplica filtros sem uma consulta.
Limpar a consulta retorna ao estado inicial e mantém as buscas recentes. A home
sem catálogo oferece caminhos reais para Explorar e Importar PDF, e a seção de
salvos vazia na Biblioteca leva à descoberta de provas.

Quando uma busca termina sem resultados, a interface apresenta um diretório
curado de domínios oficiais (INEP, Cebraspe, FGV Conhecimento, FCC, VUNESP e
Instituto AOCP). A pessoa escolhe uma fonte; só então o app abre uma busca externa do
Google restrita ao domínio selecionado e incluindo os termos informados. O app
não faz scraping, não afirma que encontrou uma prova, não baixa nem hospeda
arquivos externos. O usuário deve conferir domínio, procedência e condições de
uso, baixar da fonte original e selecionar o arquivo no fluxo de importação.
Isso não concede licença de republicação nem transforma a prova em conteúdo do
catálogo Prova Social.

Provas criadas manualmente ou importadas de PDF/JSON usam o mesmo editor. Cada
alteração agenda imediatamente uma gravação local serializada. Voltar espera a
gravação; falhas são exibidas com nova tentativa e exportação JSON por cópia para
a área de transferência. Salvar só para mim nunca acessa Supabase. Rascunhos
incompletos podem ser salvos; resolver exige questões e gabarito preenchidos.

No Android/iOS, o payload local é gravado em arquivo de suporte com gravação
atômica e cópia anterior; na Web, usa SharedPreferences. Os pacotes são
compactados quando isso reduz o tamanho e verificados por hash. Se o payload e o
backup estiverem ilegíveis, a gravação falha sem sobrescrevê-los. Downloads de
provas podem ser removidos da biblioteca com confirmação; provas criadas pelo
usuário não são removidas por essa ação. A biblioteca mostra o total de bytes das
imagens offline e bloqueia a remoção enquanto houver tentativa ativa daquela
prova. O armazenamento local não é backup permanente nem criptografado: outras
pessoas com acesso ao mesmo perfil do navegador/aparelho podem vê-lo. Limpeza do
navegador, desinstalação, quota esgotada e fechamento abrupto antes da gravação
podem causar perda. Exporte o JSON e guarde-o em um arquivo externo.

Na página canônica de uma questão pública, a discussão lê e publica comentários
em `question_comments` e acompanha um assunto somente se o nome corresponder a
um registro existente em `topics`. O cliente envia o usuário autenticado e
`status = visible`; as políticas RLS existentes continuam sendo a autoridade de
leitura e escrita. Visitantes mantêm o texto no campo durante o login. Erros de
rede preservam o rascunho e oferecem nova tentativa.

A importação de PDF mantém o limite de 25 MB e rejeita documentos acima de 500
páginas, orientando a divisão do arquivo. O documento é descartado mesmo quando
o limite ou outra falha interrompe a extração. O PDFium é inicializado sob
demanda no primeiro processamento de documento, sem bloquear a abertura do app.

O login não muda a privacidade. A intenção de publicar é persistida antes de
abrir a autenticação. No retorno normal, o editor pede confirmação. Se OAuth
recarregar a aplicação, uma intenção pendente reabre o editor quando a sessão
estiver presente; a confirmação é reapresentada, sem enviar o conteúdo automaticamente. A
biblioteca também permite reabrir a prova. Cancelar a confirmação ou selecionar
Salvar só para mim cancela a intenção. Não há sincronização de provas privadas;
`LocalExam` permanece separado do repositório público para futura implementação
explícita. Tentativas locais são corrigidas com o gabarito local e barradas tanto
na fila quanto no cliente de envio. As respostas locais permanecem no rascunho;
o histórico local de resultados ainda não é uma funcionalidade deste lote.

Na navegação, a Home oferece retomada das tentativas realmente salvas no aparelho.
Explorar destaca a intenção de estudo e identifica a procedência nos resultados.
Publicar organiza os formatos em uma coluna no celular e duas em telas largas.
Detalhes da prova incluem o ano quando disponível; o Focus Mode reorganiza
controles em larguras estreitas; o resultado mostra desempenho por assunto em
barras com valores acessíveis. O app Android permanece em orientação retrato.
O PWA solicita orientação retrato; a aba comum do Flutter Web usa as mesmas
telas e se adapta a retrato e paisagem, conforme o navegador. As telas Flutter
são compartilhadas entre Android e Web e publicadas sob `/app/` pelo workflow.

## Verificação

- `dart format` nos arquivos Dart alterados e novos.
- `flutter analyze` e `flutter test`.
- Testes de filtro/histórico de busca, remoção segura de downloads, comentários
  sob as políticas existentes, revisão virtualizada e limite de páginas PDF.
- `node --test site/tests/*.test.cjs` e `node --check site/app.js`.
- Os testes de backend usam cliente HTTP controlado, sem conteúdo de produção.
- Os testes do site validam resultado calculado, fallback de download e contraste.
- Nenhum schema, segredo ou configuração remota é necessário para este lote.
