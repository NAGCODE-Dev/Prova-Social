# Busca, provas privadas e publicação

A busca consulta Supabase (título, descrição, categoria, origem e tópico das
questões) e restringe todas as consultas a provas publicadas e públicas. O schema
atual não tem uma entidade separada de concursos: estes são encontrados pelos
metadados das provas. Cada consulta de campo retorna até 50 registros; não há
paginação neste lote. O debounce é de 350 ms e respostas de buscas anteriores
são descartadas. Os resultados abrem diretamente a prova.

Provas criadas manualmente ou importadas de PDF/JSON usam o mesmo editor. Cada
alteração agenda imediatamente uma gravação local serializada. Voltar espera a
gravação; falhas são exibidas com nova tentativa e exportação JSON por cópia para
a área de transferência. Salvar só para mim nunca acessa Supabase. Rascunhos
incompletos podem ser salvos; resolver exige questões e gabarito preenchidos.

O armazenamento usa SharedPreferences, com limite de 4 MB por biblioteca e cópia
da versão anterior para recuperação de JSON corrompido. Se ambos os registros
estiverem ilegíveis, a gravação falha sem sobrescrevê-los. A recuperação por backup
pode restaurar a versão anterior. O armazenamento não é backup permanente nem
criptografado: é privado em relação ao servidor, mas outras pessoas com acesso
ao mesmo perfil do navegador/aparelho podem vê-lo. Limpeza do navegador,
desinstalação, quota esgotada e fechamento abrupto antes de a gravação terminar
podem causar perda. Exporte o JSON e guarde-o em um arquivo externo. No navegador,
os dados pertencem à origem: outro domínio não acessa a mesma biblioteca.

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

## Verificação

- `dart format` nos arquivos Dart alterados e novos.
- `flutter analyze` e `flutter test`.
- `node --test site/tests/*.test.cjs` e `node --check site/app.js`.
- Os testes de backend usam cliente HTTP controlado, sem conteúdo de produção.
- Os testes do site validam resultado calculado, fallback de download e contraste.
- Nenhum schema, segredo ou configuração remota é necessário para este lote.
