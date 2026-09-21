# Roadmap de execução

## P0 — produto utilizável

1. **Procedência (implementado no código, aguardando CI):** mapear tipo e URL, exibir os três estados, abrir apenas origem HTTPS e retirar contagem fixa de discussão. Testes unitários e de widget adicionados.
2. **Confiabilidade da prova (gravação local implementada, aguardando CI):** respostas enfileiradas em ordem, `flush()` na saída, pausa e finalização, retomada compatível com o formato v1 e estado acessível de salvamento. Fila de entrega ao servidor e sincronização continuam pendentes.
3. **Navegação e autenticação:** retomar automaticamente a ação original após login e validar deep links Android/Web.
4. **Conteúdo e estados:** completar estados vazios e leitura pública real, sem métricas ou listas simuladas.
5. **Marca e distribuição:** conferir ícones Android/Web/PWA e simplificar CI sem publicação implícita.

## P1 — importação confiável

Preservar página e coordenadas, ordenar colunas, combinar evidências estruturais e validar com prova real de 80 questões antes de declarar a importação resolvida.

## P2–P4

Evoluir Focus Mode e prova dos erros; depois questões sociais e comunidades; por fim automatizar distribuição e atualização. Cada lote exige análise, testes e revisão de diff antes de publicação.
