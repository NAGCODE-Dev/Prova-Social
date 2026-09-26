import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/backend/exam_repository.dart';
import '../../domain/models/exam.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({required this.search, required this.onOpen, super.key});
  final Future<List<Exam>> Function(String) search;
  final ValueChanged<Exam> onOpen;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  Timer? _debounce;
  int _revision = 0;
  bool _loading = false;
  String _query = '';
  String? _error;
  List<Exam> _results = [];
  void _change(String value) {
    _query = value.trim();
    final revision = ++_revision;
    _debounce?.cancel();
    setState(() {
      _loading = _query.isNotEmpty;
      _error = null;
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
            if (!_loading &&
                _error == null &&
                _query.isNotEmpty &&
                _results.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhum resultado encontrado.'),
              ),
            if (_query.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Pesquise no catálogo público, mesmo sem conta.'),
              ),
            Expanded(
              child: ListView.builder(
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
