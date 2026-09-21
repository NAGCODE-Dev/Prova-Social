import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand.dart';
import '../../core/backend/exam_repository.dart';
import '../../domain/models/exam.dart';
import '../quiz/quiz_page.dart';
import '../publish/publish_page.dart';
import '../auth/auth_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final repository = ExamRepository();
  int currentTab = 0;
  String query = '';
  String category = 'Todos';
  final saved = <String>{};
  List<Exam> exams = const [];
  bool loading = true;
  String? loadError;
  StreamSubscription<AuthState>? authSubscription;

  @override
  void initState() {
    super.initState();
    authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) {
        setState(() {});
        _loadContent();
      }
    });
    _loadContent();
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadContent() async {
    try {
      final loadedExams = await repository.publishedExamModels();
      final loadedSaved = await repository.savedExamIds();
      if (!mounted) return;
      setState(() {
        exams = loadedExams;
        saved
          ..clear()
          ..addAll(loadedSaved);
        loading = false;
        loadError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = '$error';
        });
      }
    }
  }

  static const destinations = [
    (Icons.home_outlined, Icons.home_rounded, 'Início'),
    (Icons.search_rounded, Icons.search_rounded, 'Explorar'),
    (Icons.add_box_outlined, Icons.add_box_rounded, 'Publicar'),
    (Icons.bookmarks_outlined, Icons.bookmarks_rounded, 'Biblioteca'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        final pages = [
          _HomeFeed(exams: exams, loading: loading, error: loadError, onRetry: _loadContent, saved: saved, onSave: _toggleSave, onOpen: _openExam),
          _ExplorePage(exams: exams, query: query, category: category, saved: saved, onQuery: (value) => setState(() => query = value), onCategory: (value) => setState(() => category = value), onSave: _toggleSave, onOpen: _openExam),
          const PublishPage(),
          _LibraryPage(
            exams: exams,
            saved: saved,
            onOpen: _openExam,
            onSignIn: _openLogin,
          ),
          const _ProfilePage(),
        ];
        return Scaffold(
          appBar: desktop ? null : AppBar(title: const BrandLockup(), actions: const [_HeaderActions()]),
          body: Row(children: [
            if (desktop)
              Container(
                width: 240,
                decoration: const BoxDecoration(color: AppColors.surface, border: Border(right: BorderSide(color: AppColors.line))),
                child: SafeArea(child: Column(children: [
                  const Padding(padding: EdgeInsets.fromLTRB(24, 22, 16, 26), child: Align(alignment: Alignment.centerLeft, child: BrandLockup())),
                  ...List.generate(destinations.length, (index) => _RailItem(data: destinations[index], selected: currentTab == index, onTap: () => _selectTab(index))),
                  const Spacer(),
                  const Padding(padding: EdgeInsets.all(16), child: _UserTile()),
                ])),
              ),
            Expanded(child: Column(children: [
              if (desktop) const _DesktopTopBar(),
              Expanded(child: IndexedStack(index: currentTab, children: pages)),
            ])),
          ]),
          bottomNavigationBar: desktop ? null : NavigationBar(
            selectedIndex: currentTab,
            onDestinationSelected: _selectTab,
            destinations: destinations.map((item) => NavigationDestination(icon: Icon(item.$1), selectedIcon: Icon(item.$2), label: item.$3)).toList(),
          ),
        );
      });

  Future<void> _selectTab(int value) async {
    if (value == 2 && !await _requireAccount('publicar uma prova')) {
      return;
    }
    setState(() => currentTab = value);
    if (value == 0 || value == 1 || value == 3) _loadContent();
  }

  Future<void> _toggleSave(String id) async {
    if (!await _requireAccount('salvar provas na sua biblioteca')) {
      return;
    }
    final wasSaved = saved.contains(id);
    setState(() => wasSaved ? saved.remove(id) : saved.add(id));
    try {
      wasSaved ? await repository.removeSavedExam(id) : await repository.saveExam(id);
    } catch (error) {
      if (!mounted) return;
      setState(() => wasSaved ? saved.add(id) : saved.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível atualizar a biblioteca: $error')));
    }
  }

  Future<void> _openExam(Exam exam) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _ExamDetails(exam: exam, saved: saved.contains(exam.id), onSave: () => _toggleSave(exam.id))));
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AuthPage(closeAfterAuth: true),
      ),
    );
    if (mounted) {
      await _loadContent();
      setState(() {});
    }
  }

  Future<bool> _requireAccount(String reason) async {
    if (Supabase.instance.client.auth.currentUser != null) return true;
    final shouldOpen = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.person_outline_rounded,
                size: 36, color: AppColors.brand),
            const SizedBox(height: 16),
            Text('Use sua conta',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Você pode explorar e fazer provas sem login. Entre apenas para $reason.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Entrar ou criar conta'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar explorando'),
            ),
          ],
        ),
      ),
    );
    if (shouldOpen != true || !mounted) return false;
    await _openLogin();
    return Supabase.instance.client.auth.currentUser != null;
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar();
  @override
  Widget build(BuildContext context) => Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
        child: const Row(children: [Expanded(child: _SearchBox()), SizedBox(width: 24), _HeaderActions()]),
      );
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions();
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['display_name']?.toString().trim();
    final initials = (name == null || name.isEmpty)
        ? null
        : name.split(RegExp(r'\s+')).take(2).map((part) => part[0]).join();
    return Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(onPressed: () {}, tooltip: 'Notificações', icon: const Icon(Icons.notifications_none_rounded)),
        const SizedBox(width: 4),
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.brandSoft,
          child: initials == null
              ? const Icon(Icons.person_outline_rounded,
                  size: 19, color: AppColors.brandHover)
              : Text(initials.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.brandHover,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  )),
        ),
        const SizedBox(width: 12),
      ]);
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox();
  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: TextField(readOnly: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar provas, concursos e matérias', isDense: true)),
      );
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.data, required this.selected, required this.onTap});
  final (IconData, IconData, String) data;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ListTile(
          selected: selected,
          selectedTileColor: AppColors.brandSoft,
          selectedColor: AppColors.brandHover,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: Icon(selected ? data.$2 : data.$1),
          title: Text(data.$3, style: const TextStyle(fontWeight: FontWeight.w600)),
          onTap: onTap,
        ),
      );
}

class _HomeFeed extends StatelessWidget {
  const _HomeFeed({required this.exams, required this.loading, required this.error, required this.onRetry, required this.saved, required this.onSave, required this.onOpen});
  final List<Exam> exams;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final Set<String> saved;
  final ValueChanged<String> onSave;
  final ValueChanged<Exam> onOpen;
  @override
  Widget build(BuildContext context) => _PageScroll(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Encontre sua próxima prova', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        const Text('Materiais publicados pela comunidade, com origem visível.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 28),
        if (loading) const LinearProgressIndicator() else if (error != null) Card(child: ListTile(title: const Text('Não foi possível carregar as provas'), subtitle: Text(error!), trailing: IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded)))),
        const _SectionTitle('Publicadas recentemente'),
        const SizedBox(height: 12),
        if (!loading && exams.isEmpty) const Text('Nenhuma prova publicada ainda.') else _ExamGrid(exams: exams, saved: saved, onSave: onSave, onOpen: onOpen),
      ]));
}

class _ExplorePage extends StatelessWidget {
  const _ExplorePage({required this.exams, required this.query, required this.category, required this.saved, required this.onQuery, required this.onCategory, required this.onSave, required this.onOpen});
  final List<Exam> exams;
  final String query;
  final String category;
  final Set<String> saved;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onSave;
  final ValueChanged<Exam> onOpen;

  @override
  Widget build(BuildContext context) {
    final categories = <String>[
      'Todos',
      ...(exams
          .map((exam) => exam.category.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort()),
    ];
    final normalized = query.trim().toLowerCase();
    final filtered = exams.where((exam) => (category == 'Todos' || exam.category == category) && (normalized.isEmpty || '${exam.title} ${exam.description}'.toLowerCase().contains(normalized))).toList();
    return _PageScroll(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('O que você quer estudar?', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 18),
      TextField(onChanged: onQuery, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Concurso, banca, matéria ou prova')),
      const SizedBox(height: 16),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: categories.map((item) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(item), selected: category == item, selectedColor: AppColors.brandSoft, onSelected: (_) => onCategory(item)))).toList())),
      const SizedBox(height: 28),
      const _SectionTitle('Provas e questões'),
      const SizedBox(height: 12),
      if (filtered.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: Text('Nenhum resultado encontrado.', style: TextStyle(color: AppColors.muted)))) else _ExamGrid(exams: filtered, saved: saved, onSave: onSave, onOpen: onOpen),
    ]));
  }
}

class _ExamGrid extends StatelessWidget {
  const _ExamGrid({required this.exams, required this.saved, required this.onSave, required this.onOpen});
  final List<Exam> exams;
  final Set<String> saved;
  final ValueChanged<String> onSave;
  final ValueChanged<Exam> onOpen;
  @override
  Widget build(BuildContext context) => ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: exams.length,
      itemBuilder: (_, index) => ExamCard(exam: exams[index], saved: saved.contains(exams[index].id), onSave: () => onSave(exams[index].id), onOpen: () => onOpen(exams[index])),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
    );
}

class ExamCard extends StatelessWidget {
  const ExamCard({required this.exam, required this.saved, required this.onSave, required this.onOpen, super.key});
  final Exam exam;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: AppColors.brandHover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              exam.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const SourceBadge(official: false, compact: true),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${exam.category} · ${exam.questions.length} questões · ${exam.durationMinutes} min',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        exam.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onSave,
                  tooltip: saved ? 'Remover dos salvos' : 'Salvar',
                  icon: Icon(
                    saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: saved ? AppColors.brand : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class SourceBadge extends StatelessWidget {
  const SourceBadge({required this.official, this.compact = false, super.key});
  final bool official;
  final bool compact;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: official ? AppColors.brandSoft : AppColors.surfaceHover, borderRadius: BorderRadius.circular(7)),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 5,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          official ? Icons.verified_outlined : Icons.people_outline_rounded,
          size: 13,
          color: official ? AppColors.brandHover : AppColors.muted,
        ),
        if (!compact) ...[
          const SizedBox(width: 5),
          Text(
            official ? 'Fonte oficial' : 'Comunidade',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: official ? AppColors.brandHover : AppColors.muted,
            ),
          ),
        ],
      ]),
    ),
  );
}

class _LibraryPage extends StatelessWidget {
  const _LibraryPage({
    required this.exams,
    required this.saved,
    required this.onOpen,
    required this.onSignIn,
  });
  final List<Exam> exams;
  final Set<String> saved;
  final ValueChanged<Exam> onOpen;
  final VoidCallback onSignIn;
  @override
  Widget build(BuildContext context) {
    final savedExams = exams.where((exam) => saved.contains(exam.id)).toList();
    final signedIn = Supabase.instance.client.auth.currentUser != null;
    return _PageScroll(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Sua biblioteca', style: Theme.of(context).textTheme.headlineMedium),
      if (!signedIn) ...[
        const SizedBox(height: 10),
        const Text(
          'Entre para sincronizar provas salvas entre seus aparelhos.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onSignIn,
          icon: const Icon(Icons.login_rounded),
          label: const Text('Entrar para sincronizar'),
        ),
      ],
      const SizedBox(height: 18),
      const Wrap(spacing: 8, runSpacing: 8, children: [Chip(label: Text('Salvas')), Chip(label: Text('Em andamento')), Chip(label: Text('Concluídas')), Chip(label: Text('Coleções'))]),
      const SizedBox(height: 28),
      const _SectionTitle('Provas salvas'),
      const SizedBox(height: 12),
      if (savedExams.isEmpty) const Text('Salve uma prova para encontrá-la aqui.', style: TextStyle(color: AppColors.muted)) else _ExamGrid(exams: savedExams, saved: saved, onSave: (_) {}, onOpen: onOpen),
    ]));
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return _PageScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Perfil', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 28),
            const Icon(Icons.person_outline_rounded,
                size: 52, color: AppColors.brand),
            const SizedBox(height: 18),
            Text('Você está explorando sem conta',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Fazer provas continua liberado. Entre para publicar, salvar e sincronizar resultados.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AuthPage(closeAfterAuth: true),
                ),
              ),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Entrar ou criar conta'),
            ),
          ],
        ),
      );
    }
    final displayName = user.userMetadata?['display_name']?.toString().trim();
    final name = displayName == null || displayName.isEmpty
        ? 'Estudante'
        : displayName;
    final initials = name
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return _PageScroll(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.brandSoft,
            child: Text(initials,
                style: const TextStyle(
                  color: AppColors.brandHover,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                )),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 3),
                Text(user.email ?? '',
                    style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 28),
        const Divider(),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.history_rounded),
          title: Text('Atividade'),
          subtitle: Text('Seus resultados aparecerão quando houver dados'),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
        const Divider(),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.collections_bookmark_outlined),
          title: Text('Coleções'),
          trailing: Icon(Icons.chevron_right_rounded),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout_rounded),
          title: const Text('Sair da conta'),
          onTap: () => Supabase.instance.client.auth.signOut(),
        ),
      ]),
    );
  }
}

class _ExamDetails extends StatelessWidget {
  const _ExamDetails({required this.exam, required this.saved, required this.onSave});
  final Exam exam;
  final bool saved;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const BrandLockup()),
    body: _PageScroll(maxWidth: 820, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SourceBadge(official: false),
      const SizedBox(height: 22),
      Text(exam.category.toUpperCase(), style: const TextStyle(color: AppColors.brandHover, fontWeight: FontWeight.w800, letterSpacing: 1)),
      const SizedBox(height: 8),
      Text(exam.title, style: Theme.of(context).textTheme.displaySmall),
      const SizedBox(height: 10),
      Text(exam.author, style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 26),
      Wrap(spacing: 24, runSpacing: 12, children: [_Meta(Icons.quiz_outlined, '${exam.questions.length} questões'), _Meta(Icons.schedule_rounded, '${exam.durationMinutes} minutos'), _Meta(Icons.people_outline_rounded, '${exam.attempts} realizações')]),
      const SizedBox(height: 28),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => QuizPage(exam: exam))), icon: const Icon(Icons.play_arrow_rounded), label: const Text('Começar prova'))),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onSave, icon: Icon(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded), label: Text(saved ? 'Salva na biblioteca' : 'Salvar na biblioteca'))),
      const SizedBox(height: 32),
      const Divider(),
      const SizedBox(height: 22),
      const _SectionTitle('Sobre'),
      const SizedBox(height: 10),
      Text(exam.description, style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 26),
      const _SectionTitle('Origem'),
      const SizedBox(height: 10),
      Text('Enviado por ${exam.author}', style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 26),
      const _SectionTitle('Discussão · 0'),
    ])),
  );
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: AppColors.muted), const SizedBox(width: 7), Text(text, style: const TextStyle(color: AppColors.muted))]);
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.child, this.maxWidth = 1200});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 28, 20, 100), child: Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child)));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.headlineSmall);
}

class _UserTile extends StatelessWidget {
  const _UserTile();
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['display_name']?.toString().trim();
    return Row(children: [
      const CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.brandSoft,
        child: Icon(Icons.person_outline_rounded,
            size: 18, color: AppColors.brandHover),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          name == null || name.isEmpty ? 'Visitante' : name,
          style: const TextStyle(fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const Icon(Icons.more_horiz_rounded),
    ]);
  }
}
