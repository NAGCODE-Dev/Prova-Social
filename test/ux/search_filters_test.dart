import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/theme/app_theme.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:prova_social/features/home/home_page.dart';
import 'package:prova_social/features/search/search_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Exam sampleExam({
  required String id,
  required int year,
  required String category,
  required String source,
  required String author,
  required String topic,
}) => Exam(
  id: id,
  title: 'Prova $id',
  category: category,
  description: '',
  author: source,
  uploaderName: author,
  year: year,
  durationMinutes: 60,
  attempts: 0,
  questions: [
    Question(topic: topic, statement: 'Questão $id', options: ['A', 'B']),
  ],
);

void main() {
  final exams = [
    sampleExam(
      id: 'one',
      year: 2024,
      category: 'Polícia',
      source: 'VUNESP',
      author: 'Ana',
      topic: 'Direito Constitucional',
    ),
    sampleExam(
      id: 'two',
      year: 2023,
      category: 'Fiscal',
      source: 'Cebraspe',
      author: 'Bruno',
      topic: 'Contabilidade',
    ),
  ];

  test('applies year, category, source, topic and author filters', () {
    expect(ExamSearchFilters(year: 2024).apply(exams), [exams.first]);
    expect(ExamSearchFilters(category: 'Fiscal').apply(exams), [exams.last]);
    expect(ExamSearchFilters(source: 'VUNESP').apply(exams), [exams.first]);
    expect(ExamSearchFilters(topic: 'Contabilidade').apply(exams), [
      exams.last,
    ]);
    expect(ExamSearchFilters(author: 'Ana').apply(exams), [exams.first]);
    expect(
      ExamSearchFilters(
        year: 2024,
        category: 'Polícia',
        source: 'VUNESP',
        topic: 'Direito Constitucional',
        author: 'Ana',
      ).apply(exams),
      [exams.first],
    );
    expect(ExamSearchFilters(year: 2022).apply(exams), isEmpty);
  });

  testWidgets('shows recent searches and example topics and sources', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'search_recent_queries_v1': ['PM-SP'],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(search: (_) async => exams, onOpen: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    final cebraspe = find.text('Cebraspe');
    for (var index = 0; index < 6 && cebraspe.evaluate().isEmpty; index++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -240));
      await tester.pumpAndSettle();
    }
    expect(cebraspe, findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 2400));
    await tester.pumpAndSettle();

    expect(find.text('Buscas recentes'), findsOneWidget);
    expect(find.text('PM-SP'), findsOneWidget);
    expect(find.text('Sugestões para começar'), findsOneWidget);
    expect(find.text('Direito Constitucional'), findsOneWidget);
    expect(find.text('sem conta'), findsNothing);
  });

  testWidgets('selecting a suggested topic searches the catalog', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    String? searchedQuery;

    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(
          search: (query) async {
            searchedQuery = query;
            return exams;
          },
          onOpen: (_) {},
        ),
      ),
    );
    await tester.tap(
      find
          .ancestor(
            of: find.text('Direito Constitucional'),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(searchedQuery, 'Direito Constitucional');
    expect(find.text('Prova one'), findsOneWidget);
  });

  testWidgets('official source suggestions stay scrollable on a small screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? searchedQuery;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.5),
          ),
          child: SearchPage(
            search: (query) async {
              searchedQuery = query;
              return exams;
            },
            onOpen: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final lastSource = find.text('Instituto AOCP');
    for (var index = 0; index < 6 && lastSource.evaluate().isEmpty; index++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -240));
      await tester.pumpAndSettle();
    }
    expect(lastSource, findsOneWidget);
    await tester.ensureVisible(lastSource);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(
      find.ancestor(of: lastSource, matching: find.byType(InkWell)).first,
    );
    await tester.pumpAndSettle();

    expect(searchedQuery, 'Instituto AOCP');
    expect(find.text('Prova one'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not show an empty-results message before searching', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(search: (_) async => exams, onOpen: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explorar'), findsOneWidget);
    expect(find.text('Sugestões para começar'), findsOneWidget);
    expect(
      find.text('Escolha um tema ou uma fonte para pesquisar.'),
      findsOneWidget,
    );
    expect(find.textContaining('sem conta'), findsNothing);
    expect(find.text('Nenhuma prova combina com esses filtros.'), findsNothing);
    expect(find.text('Nenhum resultado no catálogo.'), findsNothing);
  });

  testWidgets('search clear action resets to its initial state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(search: (_) async => exams, onOpen: (_) {}),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'concurso');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Limpar pesquisa'), findsOneWidget);

    await tester.tap(find.byTooltip('Limpar pesquisa'));
    await tester.pumpAndSettle();
    expect(find.text('Buscas recentes'), findsOneWidget);
    expect(find.text('concurso'), findsOneWidget);
    expect(find.text('Nenhuma prova combina com esses filtros.'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('applies visible filters and remembers successful searches', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(search: (_) async => exams, onOpen: (_) {}),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'concurso');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getStringList(
        'search_recent_queries_v1',
      ),
      ['concurso'],
    );

    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    final dropdowns = find.byType(DropdownButtonFormField<String>);
    await tester.tap(dropdowns.at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2024').last);
    await tester.pumpAndSettle();
    await tester.tap(dropdowns.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fiscal').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();
    expect(
      find.text('Nenhuma prova combina com esses filtros.'),
      findsOneWidget,
    );
    expect(find.text('Nenhum resultado no catálogo.'), findsNothing);
  });

  testWidgets('shared filter picker applies real catalog options', (
    tester,
  ) async {
    ExamSearchFilters? applied;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                applied = await showExamSearchFilters(
                  context: context,
                  exams: exams,
                  initial: const ExamSearchFilters(),
                  title: 'Filtrar provas carregadas',
                );
              },
              child: const Text('Abrir filtros'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Filtrar provas carregadas'), findsOneWidget);

    final yearDropdown = find.byType(DropdownButtonFormField<String>).first;
    await tester.tap(yearDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2024').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();

    expect(applied?.year, 2024);
    expect(applied?.apply(exams), [exams.first]);
  });

  testWidgets('exam tile stays readable on a narrow screen with larger text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 720),
          textScaler: TextScaler.linear(1.5),
        ),
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ExamCard(
                  exam: exams.first,
                  saved: false,
                  onSave: () {},
                  onOpen: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prova one'), findsOneWidget);
    expect(find.text('Não verificada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
