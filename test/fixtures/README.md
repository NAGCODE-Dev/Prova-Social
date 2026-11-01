# PDF de QA do importador

`synthetic_two_column_80_questions.pdf` é um fixture sintético, criado no
próprio projeto exclusivamente para validar a extração de texto e a importação
de 80 questões distribuídas em duas colunas.

- Não contém prova real, questão de concurso, banca, instituição ou texto
  extraído da internet.
- Não usar no catálogo, na home, em screenshots que o apresentem como conteúdo
  real, nem em produção.
- Não implica licença ou autorização para redistribuir provas de terceiros.
- As respostas do exercício fictício usam a regra `3n + 2`; o gabarito correto
  é a alternativa C em cada questão.

O PDF pode ser regenerado com Python e ReportLab 5.0.1:

```sh
python3 -m pip install reportlab==5.0.1
python3 test/fixtures/generate_synthetic_two_column_exam.py
```

`vunesp_2024_pm_sp.pdf` é o benchmark real fornecido pelo responsável pelo
projeto. O teste valida extração e estrutura (32 páginas, 80 questões e ordem)
e o arquivo não deve ser incluído no catálogo ou em telas de produto. O teste
também verifica a origem das quatro questões com alternativas visuais, a
continuação de questões entre páginas, IDs de mídia únicos vinculados às
questões e às páginas fonte, persistência desses vínculos e renderização JPEG
seletiva das páginas de revisão e da tabela periódica de referência.
As prévias têm 1200 px no máximo e o processamento limita o conjunto a 12 MiB;
se o limite for alcançado, o importador mantém as páginas concluídas e informa
que algumas páginas ficaram sem prévia.
