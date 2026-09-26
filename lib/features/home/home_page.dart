export '../../core/widgets/source_badge.dart';

import '../../core/widgets/source_badge.dart';
import 'dart:async';

import '../../core/backend/local_exam_store.dart';
import '../search/search_page.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand.dart';
import '../../core/backend/exam_repository.dart';
import '../../core/backend/attempt_sync_service.dart';
import '../../domain/models/exam.dart';
import '../quiz/quiz_page.dart';
import '../publish/publish_page.dart';
import '../auth/auth_page.dart';
import '../result/result_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final repository = ExamRepository();
  final attemptSync = AttemptSyncService();
  int currentTab = 0;
  List<LocalExam> localExams = [];
  String? localError;
  bool resumedPublication = false;
  final saved = <String>{};
  List<Exam> exams = const [];
  List<PendingAttempt> pendingAttempts = const [];
  List<Exam> startedExams = const [];
  Map<String, ExamResult> completedAttempts = const {};
  bool loading = true;
  String? loadError;
  StreamSubscription<AuthState>? authSubscription;

  @override
  void initState() {
    super.initState();
    authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      _,
    ) {
      if (mounted) {
        setState(() {});
        _loadContent();
        unawaited(_loadAttempts());
      }
    });
    _loadContent();
    unawaited(_loadAttempts());
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

  Future<void> _loadLocal() async {
    try {
      final items = await LocalExamStore().load();
      if (!mounted) return;
      setState(() {
        localExams = items;
        localError = null;
      });
      final pending = items.where((e) => e.pendingPublication).firstOrNull;
      if (!resumedPublication &&
          pending != null &&
          Supabase.instance.client.auth.currentUser != null &&
          ModalRoute.of(context)?.isCurrent == true) {
        resumedPublication = true;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ImportReviewPage(
              title: pending.title,
              category: pending.category,
              source: pending.source,
              durationMinutes: pending.durationMinutes,
              year: pending.year,
              questions: pending.questions,
              localId: pending.id,
              pendingPublication: true,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted)
        setState(
          () => localError =
              'Não foi possível ler as provas locais. Tente novamente.',
        );
    }
  }

  Future<void> _loadAttempts() async {
    await _loadLocal();
    try {
      // Conteúdo local aparece antes de qualquer tentativa de rede.
      final started = await attemptSync.store.startedExams();
      final pending = await attemptSync.store.pending();
      final completed = await attemptSync.store.completed();
      if (mounted)
        setState(() {
          pendingAttempts = pending;
          startedExams = started;
          completedAttempts = completed;
        });
      await attemptSync.syncDue();
      final refreshedPending = await attemptSync.store.pending();
      final refreshedCompleted = await attemptSync.store.completed();
      if (mounted) {
        setState(() {
          pendingAttempts = refreshedPending;
          completedAttempts = refreshedCompleted;
        });
      }
    } catch (_) {
      // O catálogo continua utilizável; a biblioteca tentará novamente depois.
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 900;
      final pages = [
        _HomeFeed(
          exams: exams,
          loading: loading,
          error: loadError,
          onRetry: _loadContent,
          saved: saved,
          onSave: _toggleSave,
          onOpen: _openExam,
        ),
        SearchPage(search: repository.search, onOpen: _openExam),
        const PublishPage(),
        _LibraryPage(
          exams: exams,
          localExams: localExams,
          localError: localError,
          onRetryLocal: _loadLocal,
          saved: saved,
          onOpen: _openExam,
          onSignIn: _openLogin,
          onSave: _toggleSave,
          pendingAttempts: pendingAttempts,
          startedExams: startedExams,
          onContinue: (exam) async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => QuizPage(exam: exam)),
            );
            await _loadAttempts();
          },
          completedAttempts: completedAttempts,
          onPending: (item) async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PendingResultPage(
                  clientAttemptId: item.submission.clientAttemptId,
                  syncService: attemptSync,
                ),
              ),
            );
            await _loadAttempts();
          },
          onResult: (result) => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => ResultPage(result: result)),
          ),
        ),
        _ProfilePage(onLibrary: () => _selectTab(3)),
      ];
      return Scaffold(
        appBar: desktop
            ? null
            : AppBar(
                title: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: BrandLockup(),
                ),
                actions: [_HeaderActions(onProfile: _openProfile)],
              ),
        body: Row(
          children: [
            if (desktop)
              Container(
                width: 240,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(right: BorderSide(color: AppColors.line)),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 22, 16, 26),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: BrandLockup(),
                          ),
                        ),
                      ),
                      ...List.generate(
                        destinations.length,
                        (index) => _RailItem(
                          data: destinations[index],
                          selected: currentTab == index,
                          onTap: () => _selectTab(index),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _UserTile(onLogin: _openLogin),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  if (desktop)
                    _DesktopTopBar(
                      onSearch: () => openGlobalSearch(context, _openExam),
                      onProfile: _openProfile,
                    ),
                  Expanded(
                    child: IndexedStack(index: currentTab, children: pages),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: desktop
            ? null
            : NavigationBar(
                selectedIndex: currentTab,
                onDestinationSelected: _selectTab,
                destinations: destinations
                    .map(
                      (item) => NavigationDestination(
                        icon: Icon(item.$1),
                        selectedIcon: Icon(item.$2),
                        label: item.$3,
                      ),
                    )
                    .toList(),
              ),
      );
    },
  );

  Future<void> _selectTab(int value) async {
    if (!mounted) return;
    setState(() => currentTab = value);
    if (value == 0 || value == 1 || value == 3) _loadContent();
    if (value == 3) unawaited(_loadAttempts());
  }

  Future<void> _toggleSave(String id) async {
    if (!await _requireAccount('salvar provas na sua biblioteca')) {
      return;
    }
    final wasSaved = saved.contains(id);
    setState(() => wasSaved ? saved.remove(id) : saved.add(id));
    try {
      wasSaved
          ? await repository.removeSavedExam(id)
          : await repository.saveExam(id);
    } catch (error) {
      if (!mounted) return;
      setState(() => wasSaved ? saved.add(id) : saved.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível atualizar a biblioteca: $error'),
        ),
      );
    }
  }

  Future<void> _openExam(Exam exam) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ExamDetails(
          exam: exam,
          saved: saved.contains(exam.id),
          onSave: () => _toggleSave(exam.id),
        ),
      ),
    );
    await _loadAttempts();
  }

  Future<void> _openProfile() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await _openLogin();
      if (!mounted || Supabase.instance.client.auth.currentUser == null) return;
    }
    setState(() => currentTab = 4);
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
            const Icon(
              Icons.person_outline_rounded,
              size: 36,
              color: AppColors.brand,
            ),
            const SizedBox(height: 16),
            Text(
              'Use sua conta',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
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
  const _DesktopTopBar({required this.onSearch, required this.onProfile});
  final VoidCallback onSearch, onProfile;
  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    padding: const EdgeInsets.symmetric(horizontal: 28),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        Expanded(child: _SearchBox(onTap: onSearch)),
        const SizedBox(width: 24),
        _HeaderActions(onProfile: onProfile),
      ],
    ),
  );
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({required this.onProfile});
  final VoidCallback onProfile;
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['display_name']?.toString().trim();
    final initials = (name == null || name.isEmpty)
        ? null
        : name.split(RegExp(r'\s+')).take(2).map((part) => part[0]).join();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 4),
        IconButton(
          onPressed: onProfile,
          tooltip: user == null ? 'Entrar na conta' : 'Abrir perfil',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.brandSoft,
            child: initials == null
                ? const Icon(
                    Icons.person_outline_rounded,
                    size: 19,
                    color: AppColors.brandHover,
                  )
                : Text(
                    initials.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.brandHover,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 620),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size(48, 48),
        ),
        child: const Row(
          children: [
            Icon(Icons.search_rounded),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Buscar provas, concursos e matérias',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });
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
  const _HomeFeed({
    required this.exams,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.saved,
    required this.onSave,
    required this.onOpen,
  });
  final List<Exam> exams;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final Set<String> saved;
  final ValueChanged<String> onSave;
  final ValueChanged<Exam> onOpen;
  @override
  Widget build(BuildContext context) => _PageScroll(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Encontre sua próxima prova',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Materiais publicados pela comunidade, com origem visível.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        _SearchBox(onTap: () => openGlobalSearch(context, onOpen)),
        const SizedBox(height: 28),
        if (loading)
          const LinearProgressIndicator()
        else if (error != null)
          Card(
            child: ListTile(
              title: const Text('Não foi possível carregar as provas'),
              subtitle: Text(error!),
              trailing: IconButton(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          ),
        const _SectionTitle('Publicadas recentemente'),
        const SizedBox(height: 12),
        if (!loading && exams.isEmpty)
          const Text('Nenhuma prova publicada ainda.')
        else
          _ExamGrid(exams: exams, saved: saved, onSave: onSave, onOpen: onOpen),
      ],
    ),
  );
}

class _ExamGrid extends StatelessWidget {
  const _ExamGrid({
    required this.exams,
    required this.saved,
    required this.onSave,
    required this.onOpen,
  });
  final List<Exam> exams;
  final Set<String> saved;
  final ValueChanged<String> onSave;
  final ValueChanged<Exam> onOpen;
  @override
  Widget build(BuildContext context) => ListView.separated(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: exams.length,
    itemBuilder: (_, index) => ExamCard(
      exam: exams[index],
      saved: saved.contains(exams[index].id),
      onSave: () => onSave(exams[index].id),
      onOpen: () => onOpen(exams[index]),
    ),
    separatorBuilder: (_, __) => const SizedBox(height: 8),
  );
}

class ExamCard extends StatelessWidget {
  const ExamCard({
    required this.exam,
    required this.saved,
    required this.onSave,
    required this.onOpen,
    super.key,
  });
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
              child: const Icon(
                Icons.menu_book_rounded,
                color: AppColors.brandHover,
              ),
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
                      SourceBadge(sourceType: exam.sourceType, compact: true),
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

class _LibraryPage extends StatelessWidget {
  const _LibraryPage({
    required this.exams,
    required this.localExams,
    required this.localError,
    required this.onRetryLocal,
    required this.saved,
    required this.onOpen,
    required this.onSignIn,
    required this.onSave,
    required this.pendingAttempts,
    required this.startedExams,
    required this.onContinue,
    required this.completedAttempts,
    required this.onPending,
    required this.onResult,
  });
  final List<LocalExam> localExams;
  final String? localError;
  final VoidCallback onRetryLocal;
  final List<Exam> exams;
  final Set<String> saved;
  final ValueChanged<Exam> onOpen;
  final VoidCallback onSignIn;
  final ValueChanged<String> onSave;
  final List<PendingAttempt> pendingAttempts;
  final List<Exam> startedExams;
  final ValueChanged<Exam> onContinue;
  final Map<String, ExamResult> completedAttempts;
  final ValueChanged<PendingAttempt> onPending;
  final ValueChanged<ExamResult> onResult;
  @override
  Widget build(BuildContext context) {
    final savedExams = exams.where((exam) => saved.contains(exam.id)).toList();
    final signedIn = Supabase.instance.client.auth.currentUser != null;
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sua biblioteca',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          if (startedExams.isNotEmpty) ...[
            const _SectionTitle('Em andamento neste aparelho'),
            ...startedExams.map(
              (exam) => ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: Text(exam.title),
                subtitle: const Text('Continuar — disponível offline'),
                onTap: () => onContinue(exam),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const _SectionTitle('Privadas neste aparelho'),
          const Text(
            'Sem sincronização automática. Exporte uma cópia antes de limpar dados ou desinstalar.',
          ),
          if (localError != null)
            ListTile(
              title: Text(localError!),
              trailing: IconButton(
                onPressed: onRetryLocal,
                tooltip: 'Tentar novamente',
                icon: const Icon(Icons.refresh),
              ),
            ),
          if (localError == null && localExams.isEmpty)
            const Text('Importe ou crie uma prova para salvá-la só para você.'),
          ...localExams.map(
            (item) => ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(
                item.title.trim().isEmpty ? 'Rascunho sem título' : item.title,
              ),
              subtitle: Text(
                item.pendingPublication
                    ? 'Publicação pendente de confirmação'
                    : 'Salva só para mim',
              ),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ImportReviewPage(
                      title: item.title,
                      category: item.category,
                      source: item.source,
                      durationMinutes: item.durationMinutes,
                      year: item.year,
                      questions: item.questions,
                      localId: item.id,
                      pendingPublication: item.pendingPublication,
                    ),
                  ),
                );
                onRetryLocal();
              },
              trailing: IconButton(
                tooltip: 'Fazer prova',
                onPressed:
                    item.questions.isEmpty ||
                        item.questions.any(
                          (q) =>
                              q.statement.trim().isEmpty ||
                              q.options.length < 2 ||
                              q.correctIndex == null,
                        )
                    ? null
                    : () => onOpen(item.exam),
                icon: const Icon(Icons.play_arrow),
              ),
            ),
          ),
          if (!signedIn) ...[
            const SizedBox(height: 10),
            const Text(
              'Entre para acessar favoritos públicos da sua conta. As provas locais continuam privadas.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onSignIn,
              icon: const Icon(Icons.login_rounded),
              label: const Text('Entrar na conta'),
            ),
          ],
          const SizedBox(height: 18),

          const SizedBox(height: 28),
          if (pendingAttempts.isNotEmpty) ...[
            const _SectionTitle('Entregas aguardando correção'),
            const SizedBox(height: 12),
            ...pendingAttempts.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.state == AttemptSyncState.requiresAttention
                      ? Icons.error_outline_rounded
                      : Icons.cloud_off_rounded,
                ),
                title: Text(item.submission.exam.title),
                subtitle: Text(
                  item.state == AttemptSyncState.requiresAttention
                      ? 'Requer atenção'
                      : 'Salva no aparelho',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onPending(item),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (completedAttempts.isNotEmpty) ...[
            const _SectionTitle('Provas concluídas'),
            const SizedBox(height: 12),
            ...completedAttempts.values.map(
              (result) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: Text(result.exam.title),
                subtitle: Text(
                  result.exam.isLocal ? 'Salva no aparelho' : 'Sincronizada',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onResult(result),
              ),
            ),
            const SizedBox(height: 20),
          ],
          const _SectionTitle('Provas salvas'),
          const SizedBox(height: 12),
          if (savedExams.isEmpty)
            const Text(
              'Salve uma prova para encontrá-la aqui.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            _ExamGrid(
              exams: savedExams,
              saved: saved,
              onSave: onSave,
              onOpen: onOpen,
            ),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.onLibrary});
  final VoidCallback onLibrary;
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
            const Icon(
              Icons.person_outline_rounded,
              size: 52,
              color: AppColors.brand,
            ),
            const SizedBox(height: 18),
            Text(
              'Você está explorando sem conta',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.brandSoft,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.brandHover,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email ?? '',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.collections_bookmark_outlined),
            title: const Text('Biblioteca e resultados'),
            onTap: onLibrary,
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sair da conta'),
            onTap: () async {
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (_) {
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Não foi possível sair. Tente novamente.'),
                    ),
                  );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ExamDetails extends StatelessWidget {
  const _ExamDetails({
    required this.exam,
    required this.saved,
    required this.onSave,
  });
  final Exam exam;
  final bool saved;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const BrandLockup()),
    body: _PageScroll(
      maxWidth: 820,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SourceBadge(sourceType: exam.sourceType),
          const SizedBox(height: 22),
          Text(
            exam.category.toUpperCase(),
            style: const TextStyle(
              color: AppColors.brandHover,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(exam.title, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 10),
          Text(exam.author, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 26),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _Meta(Icons.quiz_outlined, '${exam.questions.length} questões'),
              _Meta(Icons.schedule_rounded, '${exam.durationMinutes} minutos'),
              if (!exam.isLocal)
                _Meta(
                  Icons.people_outline_rounded,
                  '${exam.attempts} realizações',
                ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => QuizPage(exam: exam)),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Começar prova'),
            ),
          ),
          const SizedBox(height: 10),
          if (!exam.isLocal)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSave,
                icon: Icon(
                  saved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
                label: Text(
                  saved ? 'Salva na biblioteca' : 'Salvar na biblioteca',
                ),
              ),
            ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 22),
          const _SectionTitle('Sobre'),
          const SizedBox(height: 10),
          Text(
            exam.description,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 26),
          const _SectionTitle('Origem'),
          const SizedBox(height: 10),
          Text(exam.author, style: const TextStyle(color: AppColors.muted)),
          if (exam.safeSourceUrl case final sourceUrl?) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () =>
                  launchUrl(sourceUrl, mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Abrir fonte'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: AppColors.muted),
      const SizedBox(width: 7),
      Text(text, style: const TextStyle(color: AppColors.muted)),
    ],
  );
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.child, this.maxWidth = 1200});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 100),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.headlineSmall);
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.onLogin});
  final VoidCallback onLogin;
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['display_name']?.toString().trim();
    return Row(
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.brandSoft,
          child: Icon(
            Icons.person_outline_rounded,
            size: 18,
            color: AppColors.brandHover,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            user == null
                ? 'Visitante'
                : (name == null || name.isEmpty ? 'Minha conta' : name),
            style: const TextStyle(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Mais opções',
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (value) async {
            if (value == 'about') {
              showAboutDialog(
                context: context,
                applicationName: 'Prova Social',
                children: [
                  const Text(
                    'Importe, resolva e revise provas. Provas privadas ficam neste aparelho; limpar os dados ou desinstalar remove o armazenamento local.',
                  ),
                ],
              );
            } else if (value == 'login') {
              onLogin();
            } else {
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (_) {
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Não foi possível sair. Tente novamente.'),
                    ),
                  );
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'about', child: Text('Ajuda / sobre')),
            PopupMenuItem(
              value: user == null ? 'login' : 'logout',
              child: Text(user == null ? 'Entrar' : 'Sair da conta'),
            ),
          ],
        ),
      ],
    );
  }
}
