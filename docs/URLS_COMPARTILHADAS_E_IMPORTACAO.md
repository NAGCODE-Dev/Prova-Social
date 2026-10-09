# URLs públicas, importação e armazenamento

## Compartilhamento

- Prova: `https://prova-social.pages.dev/provas/<exam-uuid>`
- Questão: `https://prova-social.pages.dev/provas/<exam-uuid>/questoes/<question-uuid>`
- O destino abre o conteúdo público no app ou no Flutter Web; a chave de respostas não é incluída na consulta pública.
- `site/_redirects` encaminha URLs de prova ao Flutter Web em `/app/`.
- O workflow de release acrescenta `autoVerify` e o filtro HTTPS ao manifesto Android gerado. Configure `ANDROID_APP_LINKS_SHA256` com o SHA-256 do certificado de release armazenado em `ANDROID_KEYSTORE_BASE64`; não use a impressão digital de `~/.android/debug.keystore`. O CI confere o segredo contra o keystore antes de gerar APKs e valida a resposta publicada em `/.well-known/assetlinks.json` depois do deploy.
- O repositório não tem projeto iOS nem `apple-app-site-association`; Universal Links no iOS continuam pendentes.

## Importação

A digitalização começa assim que o PDF é selecionado. O app sugere título usando o nome do arquivo ou o cabeçalho extraído da primeira página e sugere o ano quando encontra um ano no cabeçalho/nome. A pessoa confirma título, banca e categoria antes de editar/publicar. OCR continua dependente dos motores locais Android; PDFs escaneados não são reconhecidos na versão Web.

Questões extraídas com confiança de parser de 99% ou mais, sem avisos estruturais, começam validadas. Questões entre 80% e 98% precisam de confirmação humana; abaixo de 80% aparecem como atenção. Questões com revisão pendente bloqueiam a publicação. A navegação sequencial da revisão pula questões já validadas; editar uma questão reabre a confirmação. Avisos de parser sempre exigem conferência, mesmo acima de 99%.

## JSON, compressão e gabarito

- Provas privadas locais continuam serializadas como JSON e usam gzip/Base64 com hash SHA-256 quando o pacote fica menor; bibliotecas pequenas permanecem como JSON para evitar crescimento por causa do cabeçalho da compressão. A leitura aceita as versões JSON sem compressão e os pacotes são atualizados no próximo salvamento.
- Provas públicas são estruturadas em `exams` e `questions`. O gabarito fica em `private.question_keys`, fora da leitura pública.
- A entrega consulta a função `submit_exam_attempt` ao finalizar; o app compara o resultado recebido com as respostas que salvou localmente e só então mostra gabarito e acertos.
- `DigitalExamService` também monta arquivos gzip com manifest/hash, mas não é utilizado pelo fluxo de publicação atual. A publicação atual escreve questões estruturadas no Postgres, sem distribuir esses pacotes gzip.
