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
