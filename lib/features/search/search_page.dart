import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/backend/exam_repository.dart';
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

class _SearchPageState extends State<SearchPage> {
  Timer? _debounce;
  int _revision = 0;
  bool _loading = false;
  String _query = '';
  String? _error;
  String? _sourceError;
  String? _openingSource;
  List<Exam> _results = [];
  void _change(String value) {
    _query = value.trim();
    final revision = ++_revision;
    _debounce?.cancel();
    setState(() {
      _loading = _query.isNotEmpty;
      _error = null;
      _sourceError = null;
      _openingSource = null;
      _results = [];
    });
    if (_query.isEmpty) return;
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _run(_query, revision),
    );
  }

  Future<void> _run(String query, int revision) async {
    try {
      final results = await widget.search(query);
      if (!mounted || revision != _revision) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || revision != _revision) return;
      setState(() {
        _error = 'Não foi possível pesquisar. Verifique a conexão.';
        _loading = false;
      });
    }
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

  @override
  void dispose() {
    _debounce?.cancel();
    _revision++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Busca global')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: false,
                onChanged: _change,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Buscar provas, concursos e matérias',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            if (_loading)
              const LinearProgressIndicator(semanticsLabel: 'Pesquisando'),
            if (_error != null)
              ListTile(
                title: Text(_error!),
                trailing: IconButton(
                  tooltip: 'Tentar novamente',
                  onPressed: () => _change(_query),
                  icon: const Icon(Icons.refresh),
                ),
              ),
            if (_query.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Pesquise no catálogo público, mesmo sem conta.'),
              ),
            Expanded(
              child:
                  !_loading &&
                      _error == null &&
                      _query.isNotEmpty &&
                      _results.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      children: [
                        Text(
                          'Não encontramos essa prova no catálogo Prova Social.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Você pode procurar nos sites de organizadoras e órgãos oficiais. '
                          'A busca abre resultados do Google limitados ao domínio escolhido; '
                          'isso não significa que o app verificou ou hospeda a prova.',
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
                          'Confira o endereço, a procedência e as condições de uso antes de baixar. '
                          'Se decidir baixar, obtenha o arquivo no site de origem e importe-o pelo fluxo de publicação. '
                          'O catálogo não copia nem redistribui provas de terceiros.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (_, index) {
                        final exam = _results[index];
                        return ListTile(
                          title: Text(exam.title),
                          subtitle: Text('${exam.category} · ${exam.author}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => widget.onOpen(exam),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
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
