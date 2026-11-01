import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/backend/exam_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/emerald_backdrop.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/source_badge.dart';
import '../../domain/models/exam.dart';
import 'exam_source_directory.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    required this.search,
    required this.onOpen,
    this.openExternalSearch,
    super.key,
  });
  final Future<List<Exam>> Function(String) search;
  final ValueChanged<Exam> onOpen;
  final Future<bool> Function(Uri uri)? openExternalSearch;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class ExamSearchFilters {
  const ExamSearchFilters({
    this.year,
    this.category,
    this.source,
    this.topic,
    this.author,
  });

  final int? year;
  final String? category;
  final String? source;
  final String? topic;
  final String? author;

  List<Exam> apply(Iterable<Exam> exams) => exams
      .where((exam) {
        if (year != null && exam.year != year) return false;
        if (category != null && exam.category != category) return false;
        if (source != null && exam.author != source) return false;
        if (author != null && exam.uploaderName != author) return false;
        if (topic != null &&
            !exam.questions.any((question) => question.topic == topic)) {
          return false;
        }
        return true;
      })
      .toList(growable: false);

  int get activeCount => [
    year,
    category,
    source,
    topic,
    author,
  ].where((value) => value != null).length;
}

Future<ExamSearchFilters?> showExamSearchFilters({
  required BuildContext context,
  required Iterable<Exam> exams,
  ExamSearchFilters initial = const ExamSearchFilters(),
  String title = 'Filtrar resultados encontrados',
}) {
  final candidates = exams.toList(growable: false);
  final years =
      candidates.map((exam) => exam.year).whereType<int>().toSet().toList()
        ..sort((first, second) => second.compareTo(first));
  final categories =
      candidates
          .map((exam) => exam.category)
          .where((value) => value.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  final sources = candidates.map((exam) => exam.author).toSet().toList()
    ..sort();
  final authors =
      candidates
          .map((exam) => exam.uploaderName)
          .whereType<String>()
          .where((name) => name.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  final topics =
      candidates
          .expand((exam) => exam.questions.map((question) => question.topic))
          .where((value) => value.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  var yearFilter = initial.year;
  var categoryFilter = initial.category;
  var sourceFilter = initial.source;
  var topicFilter = initial.topic;
  var authorFilter = initial.author;

  return showModalBottomSheet<ExamSearchFilters>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, updateSheet) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _FilterDropdown(
                  label: 'Ano',
                  value: yearFilter?.toString(),
                  options: years.map((year) => year.toString()).toList(),
                  onChanged: (value) => updateSheet(() {
                    yearFilter = int.tryParse(value ?? '');
                  }),
                ),
                _FilterDropdown(
                  label: 'Categoria',
                  value: categoryFilter,
                  options: categories,
                  onChanged: (value) =>
                      updateSheet(() => categoryFilter = value),
                ),
                _FilterDropdown(
                  label: 'Banca / fonte',
                  value: sourceFilter,
                  options: sources,
                  onChanged: (value) => updateSheet(() => sourceFilter = value),
                ),
                _FilterDropdown(
                  label: 'Assunto',
                  value: topicFilter,
                  options: topics,
                  onChanged: (value) => updateSheet(() => topicFilter = value),
                ),
                if (authors.isNotEmpty)
                  _FilterDropdown(
                    label: 'Autor',
                    value: authorFilter,
                    options: authors,
                    onChanged: (value) =>
                        updateSheet(() => authorFilter = value),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    ExamSearchFilters(
                      year: yearFilter,
                      category: categoryFilter,
                      source: sourceFilter,
                      topic: topicFilter,
                      author: authorFilter,
                    ),
                  ),
                  child: const Text('Aplicar filtros'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, const ExamSearchFilters()),
                  child: const Text('Limpar filtros'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SearchPageState extends State<SearchPage> {
  static const _recentSearchesKey = 'search_recent_queries_v1';
  static const _topicExamples = [
    ('Português', Icons.translate_rounded),
    ('Direito Constitucional', Icons.balance_rounded),
    ('Matemática', Icons.calculate_outlined),
    ('Informática', Icons.laptop_mac_rounded),
  ];
  final _queryController = TextEditingController();
  Timer? _debounce;
  int _revision = 0;
  bool _loading = false;
  String _query = '';
  String? _error;
  String? _sourceError;
  String? _openingSource;
  List<Exam> _results = [];
  List<String> _recentQueries = const [];
  int? _yearFilter;
  String? _categoryFilter;
  String? _sourceFilter;
  String? _topicFilter;
  String? _authorFilter;

  @override
  void initState() {
    super.initState();
    _loadRecentQueries();
  }

  List<Exam> get _filteredResults => ExamSearchFilters(
    year: _yearFilter,
    category: _categoryFilter,
    source: _sourceFilter,
    topic: _topicFilter,
    author: _authorFilter,
  ).apply(_results);

  int get _activeFilterCount => [
    _yearFilter,
    _categoryFilter,
    _sourceFilter,
    _topicFilter,
    _authorFilter,
  ].where((value) => value != null).length;

  Future<void> _loadRecentQueries() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(
        () => _recentQueries =
            preferences.getStringList(_recentSearchesKey) ?? const [],
      );
    } catch (error, stackTrace) {
      debugPrint('[SEARCH_HISTORY] leitura falhou: ${error.runtimeType}');
      debugPrint('[SEARCH_HISTORY] stack: $stackTrace');
    }
  }

  Future<void> _rememberQuery(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    final updated = [
      normalized,
      ..._recentQueries.where(
        (item) => item.toLowerCase() != normalized.toLowerCase(),
      ),
    ].take(8).toList(growable: false);
    try {
      final saved = await (await SharedPreferences.getInstance()).setStringList(
        _recentSearchesKey,
        updated,
      );
      if (!saved) throw StateError('A preferência recusou a gravação.');
      if (mounted) setState(() => _recentQueries = updated);
    } catch (error, stackTrace) {
      debugPrint('[SEARCH_HISTORY] gravação falhou: ${error.runtimeType}');
      debugPrint('[SEARCH_HISTORY] stack: $stackTrace');
    }
  }

  void _change(String value) {
    _query = value.trim();
    if (_queryController.text != value) {
      _queryController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    final revision = ++_revision;
    _debounce?.cancel();
    setState(() {
      _loading = _query.isNotEmpty;
      _error = null;
      _sourceError = null;
      _openingSource = null;
      _results = [];
      _yearFilter = null;
      _categoryFilter = null;
      _sourceFilter = null;
      _topicFilter = null;
      _authorFilter = null;
    });
    if (_query.isEmpty) return;
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _run(_query, revision),
    );
  }

  void _submitSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    _debounce?.cancel();
    _query = query;
    _queryController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _error = null;
      _sourceError = null;
      _openingSource = null;
    });
    unawaited(_run(query, revision));
  }

  Future<void> _run(String query, int revision) async {
    try {
      final results = await widget.search(query);
      if (!mounted || revision != _revision) return;
      setState(() {
        _results = results;
        _loading = false;
      });
      unawaited(_rememberQuery(query));
    } catch (error, stackTrace) {
      debugPrint('[SEARCH] consulta falhou: ${error.runtimeType}');
      debugPrint('[SEARCH] stack: $stackTrace');
      if (!mounted || revision != _revision) return;
      setState(() {
        _error = 'Não foi possível pesquisar. Verifique a conexão.';
        _loading = false;
      });
    }
  }

  Future<void> _openFilters() async {
    final filters = await showExamSearchFilters(
      context: context,
      exams: _results,
      initial: ExamSearchFilters(
        year: _yearFilter,
        category: _categoryFilter,
        source: _sourceFilter,
        topic: _topicFilter,
        author: _authorFilter,
      ),
    );
    if (filters == null || !mounted) return;
    setState(() {
      _yearFilter = filters.year;
      _categoryFilter = filters.category;
      _sourceFilter = filters.source;
      _topicFilter = filters.topic;
      _authorFilter = filters.author;
    });
  }

  Future<void> _openSource(ExamSourceDirectoryEntry source) async {
    setState(() {
      _openingSource = source.name;
      _sourceError = null;
    });
    try {
      final uri = source.searchUri(_query);
      final opened =
          await (widget.openExternalSearch ??
              (uri) =>
                  launchUrl(uri, mode: LaunchMode.externalApplication))(uri);
      if (!mounted) return;
      setState(() {
        _openingSource = null;
        if (!opened) {
          _sourceError =
              'Não foi possível abrir a busca externa. Tente novamente.';
        }
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _openingSource = null;
        _sourceError =
            'Não foi possível abrir a busca externa. Tente novamente.';
      });
    } catch (error, stackTrace) {
      debugPrint('[EXTERNAL_SEARCH] falhou: ${error.runtimeType}');
      debugPrint('[EXTERNAL_SEARCH] stack: $stackTrace');
      if (!mounted) return;
      setState(() {
        _openingSource = null;
        _sourceError =
            'Não foi possível abrir a busca externa. Tente novamente.';
      });
    }
  }

  Widget _buildInitialSearchContent() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    children: [
      if (_recentQueries.isNotEmpty) ...[
        Text('Buscas recentes', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final query in _recentQueries)
              ActionChip(
                label: Text(query),
                onPressed: () => _submitSearch(query),
              ),
          ],
        ),
        const SizedBox(height: 24),
      ],
      StudySurface(
        highlighted: true,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: EmeraldColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: EmeraldColors.borderHighlight),
              ),
              child: const Icon(
                Icons.lightbulb_outline_rounded,
                color: EmeraldColors.primaryLight,
                size: 29,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sugestões para começar',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Escolha um tema ou uma fonte para pesquisar.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              color: EmeraldColors.primary,
            ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      const _SearchSectionHeading(title: 'Temas'),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final spacing = 10.0;
          final itemWidth = (constraints.maxWidth - spacing) / 2;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final (topic, icon) in _topicExamples)
                SizedBox(
                  width: itemWidth,
                  child: _SuggestionTile(
                    icon: icon,
                    label: topic,
                    onTap: () => _submitSearch(topic),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 26),
      const _SearchSectionHeading(title: 'Fontes oficiais'),
      const SizedBox(height: 12),
      for (final source in examSourceDirectory) ...[
        _SuggestionTile(
          icon: Icons.account_balance_outlined,
          label: source.name,
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _submitSearch(source.name),
        ),
        const SizedBox(height: 8),
      ],
    ],
  );

  @override
  void dispose() {
    _debounce?.cancel();
    _revision++;
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Explorar')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'O que você quer estudar?',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(color: EmeraldColors.primaryLight),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
              child: TextField(
                controller: _queryController,
                autofocus: false,
                onChanged: _change,
                onSubmitted: _submitSearch,
                textInputAction: TextInputAction.search,
                maxLength: 120,
                decoration: InputDecoration(
                  hintText: 'Tema, prova, banca ou fonte',
                  prefixIcon: const Icon(Icons.search_rounded),
                  prefixIconColor: EmeraldColors.primaryLight,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 22,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar pesquisa',
                          onPressed: () => _change(''),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            if (_loading)
              const LinearProgressIndicator(semanticsLabel: 'Pesquisando'),
            Expanded(
              child: _loading
                  ? ListView(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [const ExamListSkeleton(count: 3)],
                    )
                  : _query.isEmpty
                  ? _buildInitialSearchContent()
                  : _error != null
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 32,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'A busca não conseguiu carregar os resultados.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(_error!),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Tooltip(
                            message: 'Tentar novamente',
                            child: OutlinedButton.icon(
                              onPressed: () => _change(_query),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Tentar novamente'),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _query.isNotEmpty && _results.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      children: [
                        Text(
                          'Nenhum resultado no catálogo.',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tente outro termo ou procure em uma fonte oficial.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'A busca pode não encontrar a prova. Confira a origem e a licença antes de compartilhar.',
                        ),
                        if (_sourceError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _sourceError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        for (final source in examSourceDirectory)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(source.name),
                            subtitle: Text(
                              '${source.description} · ${source.domain}',
                            ),
                            trailing: _openingSource == source.name
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.open_in_new),
                            onTap: _openingSource == null
                                ? () => _openSource(source)
                                : null,
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Para importar, baixe o arquivo diretamente no site de origem.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    )
                  : _query.isEmpty
                  ? const SizedBox.shrink()
                  : _filteredResults.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          'Nenhuma prova combina com esses filtros.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Altere ou limpe os filtros para ver mais resultados.',
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => setState(() {
                              _yearFilter = null;
                              _categoryFilter = null;
                              _sourceFilter = null;
                              _topicFilter = null;
                              _authorFilter = null;
                            }),
                            child: const Text('Limpar filtros'),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _filteredResults.length == 1
                                      ? '1 resultado'
                                      : '${_filteredResults.length} resultados',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _openFilters,
                                icon: const Icon(Icons.tune_rounded),
                                label: Text(
                                  _activeFilterCount == 0
                                      ? 'Filtros'
                                      : 'Filtros ($_activeFilterCount)',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _filteredResults.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final exam = _filteredResults[index];
                              final year = exam.year == null
                                  ? ''
                                  : ' · ${exam.year}';
                              return ListTile(
                                leading: const Icon(Icons.menu_book_outlined),
                                title: Text(
                                  exam.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        SourceBadge(
                                          sourceType: exam.sourceType,
                                          compact: true,
                                        ),
                                        Text('${exam.category}$year'),
                                      ],
                                    ),
                                    Text(
                                      '${exam.author} · '
                                      '${exam.questions.length} questões'
                                      '${exam.uploaderName == null ? '' : ' · por ${exam.uploaderName}'}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => widget.onOpen(exam),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SearchSectionHeading extends StatelessWidget {
  const _SearchSectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 5,
        height: 30,
        decoration: BoxDecoration(
          color: EmeraldColors.primary,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
    ],
  );
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [EmeraldColors.surface, EmeraldColors.backgroundSecondary],
          ),
          border: Border.all(color: EmeraldColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: EmeraldColors.primaryLight, size: 23),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                IconTheme(
                  data: const IconThemeData(color: EmeraldColors.textSecondary),
                  child: trailing!,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      initialValue: value ?? '',
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('Todos')),
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: (selected) =>
          onChanged(selected == null || selected.isEmpty ? null : selected),
    ),
  );
}

Future<void> openGlobalSearch(
  BuildContext context,
  ValueChanged<Exam> onOpen,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => SearchPage(search: ExamRepository().search, onOpen: onOpen),
  ),
);
