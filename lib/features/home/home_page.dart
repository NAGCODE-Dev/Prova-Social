export '../../core/widgets/source_badge.dart';

import '../../core/widgets/source_badge.dart';

import 'dart:async';

import '../../core/backend/local_exam_store.dart';
import '../search/search_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/emerald_backdrop.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/backend/exam_repository.dart';
import '../../core/backend/digital_exam_service.dart';
import '../../core/backend/attempt_sync_service.dart';
import '../../core/navigation/share_link_service.dart';
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
  ExamSearchFilters homeFilters = const ExamSearchFilters();
  List<Exam> savedExams = const [];
  ExamCatalogCursor? catalogCursor;
  bool catalogHasMore = false;
  bool loadingMoreExams = false;
  String? loadMoreError;
  List<PendingAttempt> pendingAttempts = const [];
  List<Exam> startedExams = const [];
  Map<String, ExamResult> completedAttempts = const {};
  bool loading = true;
  bool signingOut = false;
  String? loadError;
  StreamSubscription<AuthState>? authSubscription;

  @override
  void initState() {
    super.initState();
    authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) {
        if (mounted) {
          setState(() {});
          _loadContent();
          unawaited(_loadAttempts());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[AUTH_STATE] falhou: ${error.runtimeType}');
        debugPrint('[AUTH_STATE] stack: $stackTrace');
      },
    );
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
      final page = await repository.publishedExamPage();
      final loadedSaved = await repository.savedExamIds();
      final loadedSavedExams = await repository.savedExamModels();
      if (!mounted) return;
      setState(() {
        exams = page.exams;
        catalogCursor = page.nextCursor;
        catalogHasMore = page.hasMore;
        loadingMoreExams = false;
        loadMoreError = null;
        savedExams = loadedSavedExams;
        saved
          ..clear()
          ..addAll(loadedSaved);
        loading = false;
        loadError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = 'Verifique sua conexão e tente carregar novamente.';
        });
      }
    }
  }

  Future<void> _setHomeFilters() async {
    final filters = await showExamSearchFilters(
      context: context,
      exams: exams,
      initial: homeFilters,
      title: 'Filtrar provas carregadas',
    );
    if (!mounted || filters == null) return;
    setState(() => homeFilters = filters);
  }

  void _clearHomeFilters() {
    setState(() => homeFilters = const ExamSearchFilters());
  }

  Future<void> _loadMoreExams() async {
    final cursor = catalogCursor;
    if (loadingMoreExams || !catalogHasMore || cursor == null) return;
    setState(() {
      loadingMoreExams = true;
      loadMoreError = null;
    });
    try {
      final page = await repository.publishedExamPage(after: cursor);
      if (!mounted) return;
      setState(() {
        final known = exams.map((exam) => exam.id).toSet();
        exams = [...exams, ...page.exams.where((exam) => known.add(exam.id))];
        catalogCursor = page.nextCursor;
        catalogHasMore = page.hasMore;
        loadingMoreExams = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingMoreExams = false;
        loadMoreError = 'Não foi possível carregar mais provas.';
      });
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
              sourceUrl: pending.sourceUrl,
              durationMinutes: pending.durationMinutes,
              year: pending.year,
              questions: pending.questions,
              localId: pending.id,
              pendingPublication: true,
              reviewIndex: pending.reviewIndex,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => localError =
              'Não foi possível ler as provas locais. Tente novamente.',
        );
      }
    }
  }

  Future<void> _loadAttempts() async {
    await _loadLocal();
    try {
      // Conteúdo local aparece antes de qualquer tentativa de rede.
      final started = await attemptSync.store.startedExams();
      final pending = await attemptSync.store.pending();
      final completed = await attemptSync.store.completed();
      if (mounted) {
        setState(() {
          pendingAttempts = pending;
          startedExams = started;
          completedAttempts = completed;
        });
      }
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
          filters: homeFilters,
          startedExams: startedExams,
          loading: loading,
          error: loadError,
          onRetry: _loadContent,
          hasMore: catalogHasMore,
          loadingMore: loadingMoreExams,
          loadMoreError: loadMoreError,
          onLoadMore: _loadMoreExams,
          saved: saved,
          onSave: _toggleSave,
          onOpen: _openExam,
          onPublish: () => _selectTab(2),
          onContinue: _continueAttempt,
          onFiltersChanged: _setHomeFilters,
          onClearFilters: _clearHomeFilters,
        ),
        SearchPage(search: repository.search, onOpen: _openExam),
        const PublishPage(),
        _LibraryPage(
          exams: savedExams,
          localExams: localExams,
          localError: localError,
          onRetryLocal: _loadLocal,
          onRemoveDownload: _removeDownloadedExam,
          onExplore: () => _selectTab(1),
          onPublish: () => _selectTab(2),
          saved: saved,
          onOpen: _openExam,
          onSignIn: _openLogin,
          onSave: _toggleSave,
          pendingAttempts: pendingAttempts,
          startedExams: startedExams,
          onContinue: _continueAttempt,
          completedAttempts: completedAttempts,
          onPending: (item) async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PendingResultPage(
                  clientAttemptId: item.submission.clientAttemptId,
                  syncService: attemptSync,
                  onSignIn: _openLogin,
                ),
              ),
            );
            await _loadAttempts();
          },
          onResult: (result) => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => ResultPage(result: result)),
          ),
        ),
        _ProfilePage(
          onLibrary: () => _selectTab(3),
          onSignOut: _signOut,
          signingOut: signingOut,
        ),
      ];
      return Scaffold(
        appBar: desktop
            ? null
            : AppBar(
                toolbarHeight: 72,
                title: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: BrandLockup(),
                ),
                actions: [
                  _HeaderActions(
                    onProfile: _openProfile,
                    signingOut: signingOut,
                  ),
                ],
              ),
        body: Row(
          children: [
            if (desktop)
              Container(
                key: const ValueKey('desktop-sidebar'),
                width: 240,
                decoration: BoxDecoration(
                  color: _HomeColors.surface(context),
                  border: Border(
                    right: BorderSide(color: _HomeColors.line(context)),
                  ),
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
                        child: _UserTile(
                          onLogin: _openLogin,
                          onSignOut: _signOut,
                          signingOut: signingOut,
                        ),
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
                      signingOut: signingOut,
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
            : _BottomNavBar(
                destinations: destinations,
                selectedIndex: currentTab,
                onSelected: _selectTab,
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
    } catch (_) {
      if (!mounted) return;
      setState(() => wasSaved ? saved.add(id) : saved.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Não foi possível atualizar a biblioteca. Verifique sua conexão e tente novamente.',
          ),
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
          onSignIn: _openLogin,
          isDownloaded: localExams.any(
            (item) => item.downloaded && item.id == exam.id,
          ),
          onDownload: () => _downloadExam(exam),
        ),
      ),
    );
    await _loadAttempts();
  }

  Future<void> _continueAttempt(Exam exam) async {
    final resumable = _restoreDownloadedMedia(exam);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizPage(exam: resumable, onSignIn: _openLogin),
      ),
    );
    await _loadAttempts();
  }

  Exam _restoreDownloadedMedia(Exam exam) {
    final downloaded = localExams
        .where((item) => item.downloaded && item.id == exam.id)
        .firstOrNull
        ?.exam;
    if (downloaded == null) return exam;
    final questionsById = {
      for (final question in downloaded.questions) question.id: question,
    };
    return exam.copyWith(
      questions: [
        for (final question in exam.questions)
          question.copyWith(
            media: questionsById[question.id]?.media ?? question.media,
          ),
      ],
    );
  }

  Future<bool> _downloadExam(Exam exam) async {
    try {
      final existing = (await LocalExamStore().load()).any(
        (item) => item.downloaded && item.id == exam.id,
      );
      if (!existing) {
        final offlineCopy = await DigitalExamService().download(exam);
        await LocalExamStore().save(offlineCopy);
      }
      await _loadLocal();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing
                  ? 'Esta prova já está disponível offline.'
                  : 'Prova baixada e pronta para uso offline.',
            ),
          ),
        );
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível baixar a prova. Confira a conexão e tente novamente.',
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _removeDownloadedExam(LocalExam exam) async {
    Future<void> showBlockedMessage() async {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conclua a tentativa ativa antes de remover as imagens offline.',
          ),
        ),
      );
    }

    try {
      final activeExams = await attemptSync.store.startedExams();
      if (activeExams.any((active) => active.id == exam.id)) {
        await showBlockedMessage();
        return;
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remover prova baixada?'),
          content: Text(
            'A cópia offline e ${_formatByteSize(exam.offlineImageBytes)} '
            'em imagens serão removidas. A prova pública continuará disponível '
            'quando houver conexão.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover download'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final latestActive = await attemptSync.store.startedExams();
      final removed = await LocalExamStore().removeDownloaded(
        exam.id,
        activeExamIds: latestActive.map((active) => active.id).toSet(),
      );
      if (!mounted) return;
      await _loadLocal();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            removed
                ? 'Download removido. A prova criada localmente foi preservada.'
                : 'Este download já não está na biblioteca.',
          ),
        ),
      );
    } on ActiveAttemptDownloadException {
      await showBlockedMessage();
    } catch (error, stackTrace) {
      debugPrint('[OFFLINE_REMOVE] falhou: ${error.runtimeType}');
      debugPrint('[OFFLINE_REMOVE] stack: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível remover o download. Tente novamente.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openProfile() async {
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

  /// Updates the visible session immediately and only then waits for the
  /// network/storage sign-out to finish. Otherwise a slow sign-out leaves the
  /// profile showing the old account even though the session is already gone.
  Future<void> _signOut() async {
    if (signingOut) return;
    setState(() => signingOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      if (mounted && Supabase.instance.client.auth.currentUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível sair. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => signingOut = false);
        unawaited(_loadContent());
        unawaited(_loadAttempts());
      }
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
            Icon(
              Icons.person_outline_rounded,
              size: 36,
              color: _HomeColors.brand(context),
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
              style: TextStyle(color: _HomeColors.muted(context)),
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
  const _DesktopTopBar({
    required this.onSearch,
    required this.onProfile,
    required this.signingOut,
  });
  final VoidCallback onSearch, onProfile;
  final bool signingOut;
  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    padding: const EdgeInsets.symmetric(horizontal: 28),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: _HomeColors.line(context))),
    ),
    child: Row(
      children: [
        Expanded(child: _SearchBox(onTap: onSearch)),
        const SizedBox(width: 24),
        _HeaderActions(onProfile: onProfile, signingOut: signingOut),
      ],
    ),
  );
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({required this.onProfile, required this.signingOut});
  final VoidCallback onProfile;
  final bool signingOut;
  @override
  Widget build(BuildContext context) {
    final user = signingOut ? null : Supabase.instance.client.auth.currentUser;
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
          tooltip: 'Abrir perfil',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: EmeraldColors.surfaceHighlight.withValues(alpha: .8),
              border: Border.all(color: EmeraldColors.border),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: EmeraldColors.primaryGlow.withValues(alpha: .08),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Center(
              child: initials == null
                  ? const Icon(
                      Icons.person_outline_rounded,
                      size: 22,
                      color: EmeraldColors.primaryLight,
                    )
                  : Text(
                      initials.toUpperCase(),
                      style: const TextStyle(
                        color: EmeraldColors.primaryLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
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
          minimumSize: const Size(48, 64),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          backgroundColor: EmeraldColors.surface.withValues(alpha: .7),
          side: const BorderSide(color: EmeraldColors.border, width: 1.5),
          foregroundColor: EmeraldColors.primaryLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.search_rounded),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Buscar provas e matérias',
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          selected: selected,
          selectedTileColor: EmeraldColors.surfaceHighlight,
          selectedColor: EmeraldColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Icon(
            selected ? data.$2 : data.$1,
            color: selected ? EmeraldColors.primary : EmeraldColors.textPrimary,
          ),
          title: Text(
            data.$3,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<(IconData, IconData, String)> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: EmeraldColors.backgroundSecondary.withValues(alpha: .96),
      border: const Border(top: BorderSide(color: EmeraldColors.border)),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .2),
          blurRadius: 18,
          offset: const Offset(0, -6),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          for (var index = 0; index < destinations.length; index++)
            Expanded(
              child: _BottomNavItem(
                item: destinations[index],
                selected: selectedIndex == index,
                onTap: () => onSelected(index),
              ),
            ),
        ],
      ),
    ),
  );
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final (IconData, IconData, String) item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPublish = item.$3 == 'Publicar';
    return Semantics(
      button: true,
      selected: selected,
      label: item.$3,
      child: Tooltip(
        message: item.$3,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: AppMotion.of(context, AppMotion.fast),
                  width: isPublish
                      ? 50
                      : selected
                      ? 60
                      : 48,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isPublish
                        ? EmeraldColors.primary
                        : selected
                        ? EmeraldColors.surfaceHighlight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(isPublish ? 15 : 24),
                    border: selected && !isPublish
                        ? Border.all(
                            color: EmeraldColors.borderHighlight.withValues(
                              alpha: .8,
                            ),
                          )
                        : null,
                    boxShadow: isPublish
                        ? [
                            BoxShadow(
                              color: EmeraldColors.primaryGlow.withValues(
                                alpha: .24,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    isPublish
                        ? Icons.add_rounded
                        : selected
                        ? item.$2
                        : item.$1,
                    color: isPublish
                        ? EmeraldColors.background
                        : selected
                        ? EmeraldColors.primaryLight
                        : EmeraldColors.textSecondary,
                    size: isPublish ? 28 : 23,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.$3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isPublish
                        ? EmeraldColors.primaryLight
                        : selected
                        ? EmeraldColors.primary
                        : EmeraldColors.textSecondary,
                    fontSize: 11,
                    fontWeight: selected || isPublish
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: AppMotion.of(context, AppMotion.fast),
                  width: selected && !isPublish ? 30 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: EmeraldColors.primary,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: selected && !isPublish
                        ? [
                            BoxShadow(
                              color: EmeraldColors.primaryGlow.withValues(
                                alpha: .3,
                              ),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeFeed extends StatelessWidget {
  const _HomeFeed({
    required this.exams,
    required this.filters,
    required this.startedExams,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.hasMore,
    required this.loadingMore,
    required this.loadMoreError,
    required this.onLoadMore,
    required this.saved,
    required this.onSave,
    required this.onOpen,
    required this.onPublish,
    required this.onContinue,
    required this.onFiltersChanged,
    required this.onClearFilters,
  });
  final List<Exam> exams;
  final ExamSearchFilters filters;
  final List<Exam> startedExams;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final bool hasMore;
  final bool loadingMore;
  final String? loadMoreError;
  final VoidCallback onLoadMore;
  final Set<String> saved;
  final ValueChanged<String> onSave;
  final ValueChanged<Exam> onOpen;
  final VoidCallback onPublish;
  final ValueChanged<Exam> onContinue;
  final VoidCallback onFiltersChanged;
  final VoidCallback onClearFilters;
  @override
  Widget build(BuildContext context) {
    final filteredExams = filters.apply(exams);
    final hasFilters = filters.activeCount > 0;
    final displayName = Supabase
        .instance
        .client
        .auth
        .currentUser
        ?.userMetadata?['display_name']
        ?.toString()
        .trim();
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (displayName != null && displayName.isNotEmpty) ...[
            Text(
              'Olá, $displayName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: _HomeColors.muted(context)),
            ),
            const SizedBox(height: 4),
          ],
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Encontre sua próxima '),
                TextSpan(
                  text: 'prova',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: MediaQuery.sizeOf(context).width < 600 ? 30 : 48,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Materiais publicados pela comunidade, com origem visível.',
            style: TextStyle(color: _HomeColors.muted(context)),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SearchBox(
                  onTap: () => openGlobalSearch(context, onOpen),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: exams.isEmpty ? null : onFiltersChanged,
                tooltip: 'Filtrar provas carregadas',
                icon: Badge(
                  isLabelVisible: hasFilters,
                  label: Text('${filters.activeCount}'),
                  child: const Icon(Icons.tune_rounded),
                ),
              ),
            ],
          ),
          if (startedExams.isNotEmpty) ...[
            const SizedBox(height: 28),
            const _SectionTitle('Continuar de onde parou'),
            const SizedBox(height: 12),
            ...startedExams.map(
              (exam) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_circle_outline_rounded),
                title: Text(
                  exam.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${exam.questions.length} questões · salvo neste aparelho',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onContinue(exam),
              ),
            ),
          ],
          const SizedBox(height: 28),
          _SectionTitle(
            'Publicadas recentemente',
            actionLabel: hasFilters ? 'Limpar filtros' : 'Ver todas',
            onAction: hasFilters
                ? onClearFilters
                : () => openGlobalSearch(context, onOpen),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 8),
            Text(
              'Filtros aplicados às ${exams.length} provas já carregadas.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: _HomeColors.muted(context)),
            ),
          ],
          const SizedBox(height: 12),
          if (error != null && exams.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Não foi possível carregar as provas',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(error!),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          else if (loading && exams.isEmpty)
            const ExamListSkeleton()
          else if (exams.isEmpty)
            _EmptyCatalog(
              onExplore: () => openGlobalSearch(context, onOpen),
              onPublish: onPublish,
            )
          else if (filteredExams.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nenhuma das ${exams.length} provas carregadas combina com estes filtros.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (hasMore)
                    Text(
                      'Carregue mais provas para ampliar os resultados.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: _HomeColors.muted(context)),
                    ),
                ],
              ),
            )
          else
            _ExamGrid(
              exams: filteredExams,
              saved: saved,
              onSave: onSave,
              onOpen: onOpen,
            ),
          if (loadMoreError != null)
            ListTile(
              title: Text(loadMoreError!),
              trailing: IconButton(
                onPressed: onLoadMore,
                tooltip: 'Tentar novamente',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          if (hasMore)
            Align(
              alignment: Alignment.center,
              child: OutlinedButton(
                onPressed: loadingMore ? null : onLoadMore,
                child: loadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Carregar mais provas'),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.onExplore, required this.onPublish});

  final VoidCallback onExplore;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) => StudySurface(
    highlighted: true,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: EmeraldColors.surfaceHighlight,
            border: Border.all(color: EmeraldColors.borderHighlight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.menu_book_rounded,
            color: EmeraldColors.primaryLight,
            size: 26,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Ainda não há provas publicadas',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Explore as provas disponíveis ou importe um PDF para começar.',
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onExplore,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Explorar provas'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onPublish,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Importar PDF'),
          ),
        ),
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
    separatorBuilder: (_, _) => const SizedBox(height: 6),
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
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 42,
              decoration: BoxDecoration(
                color: _HomeColors.brandSoft(context),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                color: _HomeColors.brandHover(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SourceBadge(sourceType: exam.sourceType, compact: true),
                      Text(
                        [
                          if (exam.year != null) exam.year.toString(),
                          exam.category,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _HomeColors.muted(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${exam.questions.length} questões · ${exam.durationMinutes} min · ${exam.author}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
              onPressed: onSave,
              tooltip: saved ? 'Remover dos salvos' : 'Salvar',
              icon: Icon(
                saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: saved
                    ? _HomeColors.brand(context)
                    : _HomeColors.muted(context),
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
    required this.onRemoveDownload,
    required this.onExplore,
    required this.onPublish,
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
  final Future<void> Function(LocalExam exam) onRemoveDownload;
  final VoidCallback onExplore;
  final VoidCallback onPublish;
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
    final downloadedExams = localExams
        .where((item) => item.downloaded)
        .toList(growable: false);
    final offlineImageBytes = downloadedExams.fold<int>(
      0,
      (total, item) => total + item.offlineImageBytes,
    );
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Sua '),
                TextSpan(
                  text: 'biblioteca',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Acesse suas provas salvas e gerencie seus arquivos.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          StudySurface(
            highlighted: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: EmeraldColors.surfaceHighlight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: EmeraldColors.primaryLight,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Privadas neste aparelho',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Suas provas privadas ficam neste aparelho. Exporte uma cópia antes de limpar dados ou desinstalar.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onPublish,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Importar ou criar prova'),
                  ),
                ),
                if (!signedIn) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onSignIn,
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Entrar na conta'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!signedIn) ...[
            const SizedBox(height: 14),
            StudySurface(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: EmeraldColors.primaryLight,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Entre para acessar favoritos públicos. As provas locais continuam privadas.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (localError != null) ...[
            const SizedBox(height: 16),
            ListTile(
              title: Text(localError!),
              trailing: IconButton(
                onPressed: onRetryLocal,
                tooltip: 'Tentar novamente',
                icon: const Icon(Icons.refresh),
              ),
            ),
          ],
          if (startedExams.isNotEmpty) ...[
            const SizedBox(height: 28),
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
          if (downloadedExams.isNotEmpty) ...[
            const _SectionTitle('Baixadas para uso offline'),
            Text(
              '${_formatByteSize(offlineImageBytes)} ocupados por imagens offline',
              style: TextStyle(color: _HomeColors.muted(context)),
            ),
            ...downloadedExams.map(
              (item) => ListTile(
                leading: const Icon(Icons.download_done_rounded),
                title: Text(item.title),
                subtitle: Text(
                  '${item.questions.length} questões · '
                  '${_formatByteSize(item.offlineImageBytes)} em imagens',
                ),
                onTap: () => onOpen(item.exam),
                trailing: Wrap(
                  spacing: 0,
                  children: [
                    IconButton(
                      tooltip: 'Começar prova offline',
                      onPressed: () => onOpen(item.exam),
                      icon: const Icon(Icons.play_arrow_rounded),
                    ),
                    IconButton(
                      tooltip: 'Remover prova baixada',
                      onPressed: () => onRemoveDownload(item),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          ...localExams
              .where((item) => !item.downloaded)
              .map(
                (item) => ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(
                    item.title.trim().isEmpty
                        ? 'Rascunho sem título'
                        : item.title,
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
                          sourceUrl: item.sourceUrl,
                          durationMinutes: item.durationMinutes,
                          year: item.year,
                          questions: item.questions,
                          localId: item.id,
                          pendingPublication: item.pendingPublication,
                          reviewIndex: item.reviewIndex,
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
            _SavedExamsEmpty(onExplore: onExplore)
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

class _SavedExamsEmpty extends StatelessWidget {
  const _SavedExamsEmpty({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) => StudySurface(
    highlighted: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: EmeraldColors.surfaceHighlight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.bookmark_border_rounded,
            size: 24,
            color: EmeraldColors.primaryLight,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Suas provas estarão aqui',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Explore o catálogo e salve as provas que deseja resolver depois.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onExplore,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Explorar provas'),
          ),
        ),
      ],
    ),
  );
}

String _formatByteSize(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(0)} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

class _FeatureIcon extends StatelessWidget {
  const _FeatureIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: EmeraldColors.surfaceHighlight,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: EmeraldColors.border),
    ),
    child: Icon(icon, color: EmeraldColors.primaryLight, size: 24),
  );
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: StudySurface(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _FeatureIcon(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: EmeraldColors.textSecondary,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.onLibrary,
    required this.onSignOut,
    required this.signingOut,
  });
  final VoidCallback onLibrary;
  final Future<void> Function() onSignOut;
  final bool signingOut;
  @override
  Widget build(BuildContext context) {
    final user = signingOut ? null : Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return _PageScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Perfil', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Gerencie sua conta e preferências.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            StudySurface(
              highlighted: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: EmeraldColors.surfaceHighlight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 30,
                      color: EmeraldColors.primaryLight,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Estude do seu jeito',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fazer provas continua liberado. Entre para publicar, salvar e sincronizar resultados.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AuthPage(closeAfterAuth: true),
                        ),
                      ),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Entrar ou criar conta'),
                    ),
                  ),
                ],
              ),
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
          Text('Perfil', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Gerencie sua conta e preferências.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          StudySurface(
            highlighted: true,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: EmeraldColors.surfaceHighlight,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: EmeraldColors.primaryLight,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StudySurface(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const _FeatureIcon(icon: Icons.bar_chart_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seu progresso',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Acesse suas provas e resultados.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onLibrary,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Ver'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ProfileAction(
            icon: Icons.collections_bookmark_outlined,
            title: 'Biblioteca e resultados',
            subtitle: 'Acesse provas salvas e atividades.',
            onTap: onLibrary,
          ),
          const SizedBox(height: 12),
          _ProfileAction(
            icon: Icons.info_outline_rounded,
            title: 'Sobre o Prova Social',
            subtitle: 'Saiba mais sobre o aplicativo.',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Prova Social',
              children: const [
                Text('Encontre, importe, resolva e revise provas.'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sair da conta'),
            ),
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
    required this.onSignIn,
    required this.isDownloaded,
    required this.onDownload,
  });
  final Exam exam;
  final bool saved;
  final VoidCallback onSave;
  final Future<void> Function() onSignIn;
  final bool isDownloaded;
  final Future<bool> Function() onDownload;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const BrandLockup(),
      actions: [
        if (!exam.isLocal)
          IconButton(
            tooltip: 'Copiar link da prova',
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: ShareLinkService.exam(exam.id).toString()),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link da prova copiado.')),
                );
              }
            },
            icon: const Icon(Icons.ios_share_rounded),
          ),
      ],
    ),
    body: _PageScroll(
      maxWidth: 820,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SourceBadge(sourceType: exam.sourceType),
          const SizedBox(height: 22),
          Text(
            exam.category.toUpperCase(),
            style: TextStyle(
              color: _HomeColors.brandHover(context),
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(exam.title, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 10),
          Text(
            exam.author,
            style: TextStyle(color: _HomeColors.muted(context)),
          ),
          const SizedBox(height: 26),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _Meta(Icons.quiz_outlined, '${exam.questions.length} questões'),
              _Meta(Icons.schedule_rounded, '${exam.durationMinutes} minutos'),
              if (exam.year case final year?)
                _Meta(Icons.event_outlined, '$year'),
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
                MaterialPageRoute<void>(
                  builder: (_) => QuizPage(exam: exam, onSignIn: onSignIn),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Começar prova'),
            ),
          ),
          const SizedBox(height: 10),
          if (!exam.isLocal)
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _OfflineDownloadButton(
                    downloaded: isDownloaded,
                    onDownload: onDownload,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
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
                ],
              ),
            ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 22),
          const _SectionTitle('Sobre'),
          const SizedBox(height: 10),
          Text(
            exam.description,
            style: TextStyle(color: _HomeColors.muted(context)),
          ),
          const SizedBox(height: 26),
          const _SectionTitle('Origem'),
          const SizedBox(height: 10),
          Text(
            exam.author,
            style: TextStyle(color: _HomeColors.muted(context)),
          ),
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

class _OfflineDownloadButton extends StatefulWidget {
  const _OfflineDownloadButton({
    required this.downloaded,
    required this.onDownload,
  });
  final bool downloaded;
  final Future<bool> Function() onDownload;

  @override
  State<_OfflineDownloadButton> createState() => _OfflineDownloadButtonState();
}

class _OfflineDownloadButtonState extends State<_OfflineDownloadButton> {
  late bool downloaded = widget.downloaded;
  bool busy = false;

  Future<void> _download() async {
    if (busy || downloaded) return;
    setState(() => busy = true);
    final success = await widget.onDownload();
    if (mounted) {
      setState(() {
        busy = false;
        downloaded = success;
      });
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: busy || downloaded ? null : _download,
    icon: busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            downloaded ? Icons.download_done_rounded : Icons.download_rounded,
          ),
    label: Text(
      busy
          ? 'Baixando prova…'
          : downloaded
          ? 'Disponível offline'
          : 'Baixar para usar offline',
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
      Icon(icon, size: 18, color: _HomeColors.muted(context)),
      const SizedBox(width: 7),
      Text(text, style: TextStyle(color: _HomeColors.muted(context))),
    ],
  );
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.child, this.maxWidth = 1200});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 24,
        compact ? 20 : 28,
        compact ? 16 : 24,
        32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.actionLabel, this.onAction});
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 440;
      final heading = Row(
        children: [
          Container(
            width: 4,
            height: compact ? 28 : 32,
            decoration: BoxDecoration(
              color: EmeraldColors.primary,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: EmeraldColors.primaryGlow.withValues(alpha: .24),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontSize: compact ? 18 : 22),
            ),
          ),
          if (!compact && actionLabel != null && onAction != null)
            TextButton.icon(
              onPressed: onAction,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: Text(actionLabel!),
              style: TextButton.styleFrom(
                foregroundColor: EmeraldColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
        ],
      );
      if (!compact || actionLabel == null || onAction == null) return heading;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: EmeraldColors.primary,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(actionLabel!),
            ),
          ),
        ],
      );
    },
  );
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.onLogin,
    required this.onSignOut,
    required this.signingOut,
  });
  final VoidCallback onLogin;
  final Future<void> Function() onSignOut;
  final bool signingOut;
  @override
  Widget build(BuildContext context) {
    final user = signingOut ? null : Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['display_name']?.toString().trim();
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: _HomeColors.brandSoft(context),
          child: Icon(
            Icons.person_outline_rounded,
            size: 18,
            color: _HomeColors.brandHover(context),
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
              await onSignOut();
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

abstract final class _HomeColors {
  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color line(BuildContext context) =>
      Theme.of(context).colorScheme.outline;

  static Color muted(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color brand(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color brandHover(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.primary
        : AppColors.brandHover;
  }

  static Color brandSoft(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.primary.withValues(alpha: .16)
        : AppColors.brandSoft;
  }
}
