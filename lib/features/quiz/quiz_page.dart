import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/backend/attempt_draft_store.dart';
import '../../core/backend/attempt_submission.dart';
import '../../core/backend/attempt_sync_service.dart';
import '../../domain/models/exam.dart';
import '../result/result_page.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({
    required this.exam,
    this.draftStore,
    this.syncService,
    super.key,
  });
  final Exam exam;
  final AttemptDraftStore? draftStore;
  final AttemptSyncService? syncService;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> with WidgetsBindingObserver {
  late Exam exam;
  late final AttemptDraftStore draftStore;
  late final AttemptSyncService syncService;
  late String clientAttemptId;
  final answers = <int, int>{};
  final review = <int>{};
  final elapsed = ValueNotifier<int>(0);
  Timer? timer;
  late Future<void> restoration;
  Future<void>? pauseFlush;
  int current = 0;
  bool restoring = true;
  bool restoreFailed = false;
  bool leaving = false;
  bool canPop = false;
  bool finishing = false;

  @override
  void initState() {
    super.initState();
    exam = widget.exam;
    draftStore = widget.draftStore ?? AttemptDraftStore();
    syncService = widget.syncService ?? AttemptSyncService();
    clientAttemptId = AttemptSyncService.newClientAttemptId();
    WidgetsBinding.instance.addObserver(this);
    restoration = _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    try {
      // Reopening from the online catalog must not attach saved answer indices
      // to a newer question order. Keep the content of the started attempt.
      for (final cached in await syncService.store.startedExams()) {
        if (cached.id == exam.id) {
          exam = cached;
          break;
        }
      }
      if (!mounted) return;
      if (exam.questions.isEmpty) {
        throw StateError('A prova não possui questões disponíveis.');
      }
      final draft = await draftStore.load(exam.id);
      if (!mounted) return;
      // A entrega pode ter sido persistida antes de o app fechar ou de a
      // remoção do rascunho falhar. Nunca reutilize seu ID para novas respostas.
      final deliveredId = draft?.clientAttemptId;
      if (deliveredId != null) {
        final pending = await syncService.store.find(deliveredId);
        final result = (await syncService.store.completed())[deliveredId];
        if (!mounted) return;
        if (pending != null || result != null) {
          finishing = true;
          try {
            await draftStore.clear(exam.id);
          } catch (_) {
            // A entrega permanece acessível mesmo se o rascunho não sair.
          }
          if (!mounted) return;
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => result != null
                  ? ResultPage(result: result)
                  : PendingResultPage(
                      clientAttemptId: deliveredId,
                      syncService: syncService,
                    ),
            ),
          );
          return;
        }
      }
      await syncService.store.saveStartedExam(exam);
      if (!mounted) return;
      setState(() {
        if (draft != null) {
          answers.addAll(draft.answers);
          review.addAll(draft.review);
          current = draft.current.clamp(0, exam.questions.length - 1).toInt();
          elapsed.value = draft.elapsedSeconds;
          clientAttemptId = draft.clientAttemptId ?? clientAttemptId;
        }
        restoring = false;
        restoreFailed = false;
      });
      timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => elapsed.value++,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        restoring = false;
        restoreFailed = true;
      });
    }
  }

  Future<void> _persistDraft() => draftStore.save(
    exam.id,
    AttemptDraft(
      answers: Map.of(answers),
      review: Set.of(review),
      current: current,
      elapsedSeconds: elapsed.value,
      clientAttemptId: clientAttemptId,
    ),
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (finishing || canPop) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      pauseFlush = _flushOnPause();
      unawaited(pauseFlush!);
    }
  }

  Future<void> _flushOnPause() async {
    await restoration;
    if (!mounted || finishing || canPop || restoreFailed) return;
    await _persistDraft();
    try {
      await draftStore.flush();
    } catch (_) {
      // O estado continua em memória e o indicador oferece nova tentativa.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    elapsed.dispose();
    unawaited(() async {
      try {
        await pauseFlush;
        await draftStore.flush();
      } catch (_) {
        // Não há interface disponível após dispose; o rascunho fica em memória
        // enquanto esta operação termina.
      } finally {
        if (widget.draftStore == null) draftStore.dispose();
      }
    }());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: canPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_confirmExit());
    },
    child: Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Sair da prova',
          onPressed: _confirmExit,
          icon: const Icon(Icons.close_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MODO FOCO',
              style: TextStyle(
                color: AppColors.brandHover,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            Text(
              exam.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          _ExamTimer(elapsed: elapsed),
          const SizedBox(width: AppSpacing.sm),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: exam.questions.isEmpty
                ? 0
                : (current + 1) / exam.questions.length,
            minHeight: 4,
            backgroundColor: AppColors.line,
            color: AppColors.brand,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (restoring) {
            return const Center(child: CircularProgressIndicator());
          }
          if (restoreFailed) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Não foi possível restaurar a tentativa. Suas respostas '
                      'salvas serão preservadas enquanto você tenta novamente.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() => restoring = true);
                        restoration = _restoreDraft();
                      },
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }
          final desktop = constraints.maxWidth >= 980;
          return Column(
            children: [
              ValueListenableBuilder<DraftSaveStatus>(
                valueListenable: draftStore.status,
                builder: (context, status, _) {
                  final (label, icon) = switch (status) {
                    DraftSaveStatus.saving => (
                      'Salvando no aparelho',
                      Icons.sync_rounded,
                    ),
                    DraftSaveStatus.saved => (
                      'Salvo no aparelho',
                      Icons.check_circle_outline_rounded,
                    ),
                    DraftSaveStatus.failed => (
                      'Falha ao salvar',
                      Icons.error_outline_rounded,
                    ),
                  };
                  return Semantics(
                    liveRegion: true,
                    label: label,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(icon, size: 16),
                          const SizedBox(width: 6),
                          Text(label),
                          if (status == DraftSaveStatus.failed)
                            TextButton(
                              onPressed: () => unawaited(_retrySave()),
                              child: const Text('Tentar novamente'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Expanded(
                child: Row(
                  children: [
                    if (desktop)
                      SizedBox(
                        width: 280,
                        child: _QuestionNavigator(
                          total: exam.questions.length,
                          current: current,
                          answers: answers,
                          review: review,
                          onSelect: _selectQuestion,
                        ),
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                desktop ? 40 : 16,
                                20,
                                desktop ? 40 : 16,
                                32,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 820,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _QuestionStatus(
                                        current: current,
                                        total: exam.questions.length,
                                        answered: answers.length,
                                        marked: review.length,
                                      ),
                                      if (!desktop) ...[
                                        const SizedBox(height: AppSpacing.md),
                                        _MobileQuestionStrip(
                                          total: exam.questions.length,
                                          current: current,
                                          answers: answers,
                                          review: review,
                                          onSelect: _selectQuestion,
                                        ),
                                      ],
                                      const SizedBox(height: AppSpacing.lg),
                                      AnimatedSwitcher(
                                        duration: AppMotion.of(
                                          context,
                                          AppMotion.fast,
                                        ),
                                        child: _QuestionContent(
                                          key: ValueKey(current),
                                          question: exam.questions[current],
                                          selected: answers[current],
                                          onSelected: (answer) {
                                            if (finishing) return;
                                            setState(
                                              () => answers[current] = answer,
                                            );
                                            unawaited(_persistDraft());
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _FocusActions(
                            marked: review.contains(current),
                            onToggleReview: () {
                              if (finishing) return;
                              setState(() {
                                review.contains(current)
                                    ? review.remove(current)
                                    : review.add(current);
                              });
                              unawaited(_persistDraft());
                            },
                            onPrevious: current == 0
                                ? null
                                : () => _selectQuestion(current - 1),
                            onNext: current == exam.questions.length - 1
                                ? _openReview
                                : () => _selectQuestion(current + 1),
                            last: current == exam.questions.length - 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Future<void> _retrySave() async {
    try {
      await draftStore.flush();
    } catch (_) {
      // O estado de falha permanece visível para outra tentativa.
    }
  }

  void _selectQuestion(int index) {
    if (finishing) return;
    setState(() => current = index);
    unawaited(_persistDraft());
  }

  Future<void> _confirmExit() async {
    if (leaving || finishing) return;
    leaving = true;
    try {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.pause_circle_outline_rounded),
          title: const Text('Pausar esta prova?'),
          content: const Text(
            'Seu progresso será salvo no aparelho antes de sair.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sair'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (leave == true) {
        await restoration;
        if (!mounted) return;
        if (!restoreFailed) {
          await _persistDraft();
          await draftStore.flush();
        }
        if (!mounted) return;
        setState(() => canPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar no aparelho. Tente novamente antes de sair.',
            ),
          ),
        );
      }
    } finally {
      leaving = false;
    }
  }

  Future<void> _openReview() async {
    final finish = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _DeliveryReview(
        total: exam.questions.length,
        answers: answers,
        review: review,
        onQuestion: (index) {
          Navigator.pop(context, false);
          _selectQuestion(index);
        },
      ),
    );
    if (finish == true) await _finish();
  }

  Future<void> _finish() async {
    if (finishing) return;
    setState(() => finishing = true);
    timer?.cancel();
    var deliveryPersisted = false;
    try {
      await _persistDraft();
      await draftStore.flush();
      if (exam.isLocal) {
        final result = ExamResult(
          exam: exam,
          answers: Map.of(answers),
          markedForReview: Set.of(review),
          durationSeconds: elapsed.value,
          finishedAt: DateTime.now(),
        );
        await syncService.store.completeLocal(clientAttemptId, result);
        deliveryPersisted = true;
        try {
          await draftStore.clear(exam.id);
        } catch (_) {
          // O resultado persistido permite recuperar uma entrega interrompida.
        }
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => ResultPage(result: result)),
        );
        return;
      }
      final submission = AttemptSubmission(
        clientAttemptId: clientAttemptId,
        exam: exam,
        answers: Map.of(answers),
        markedForReview: Set.of(review),
        durationSeconds: elapsed.value,
        finishedAt: DateTime.now(),
      );
      await syncService.saveForSync(submission);
      deliveryPersisted = true;
      try {
        await draftStore.clear(exam.id);
      } catch (_) {
        // A entrega já está segura; o rascunho antigo pode ser removido depois.
      }
      final outcome = await syncService.sync(
        clientAttemptId,
        ignoreSchedule: true,
      );
      if (!mounted) return;
      if (outcome.result != null) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ResultPage(result: outcome.result!),
          ),
        );
      } else {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PendingResultPage(
              clientAttemptId: clientAttemptId,
              syncService: syncService,
            ),
          ),
        );
      }
    } catch (error) {
      if (deliveryPersisted) {
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PendingResultPage(
              clientAttemptId: clientAttemptId,
              syncService: syncService,
            ),
          ),
        );
        return;
      }
      try {
        await _persistDraft();
        await draftStore.flush();
      } catch (_) {}
      if (!mounted) return;
      timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => elapsed.value++,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível salvar a entrega no aparelho. Suas respostas continuam nesta prova. $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => finishing = false);
    }
  }
}

class _ExamTimer extends StatefulWidget {
  const _ExamTimer({required this.elapsed});
  final ValueListenable<int> elapsed;

  @override
  State<_ExamTimer> createState() => _ExamTimerState();
}

class _ExamTimerState extends State<_ExamTimer> {
  bool hidden = false;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: widget.elapsed,
    builder: (_, seconds, __) => Semantics(
      label: hidden ? 'Revelar cronômetro' : 'Ocultar cronômetro',
      child: TextButton.icon(
        onPressed: () => setState(() => hidden = !hidden),
        icon: Icon(
          hidden ? Icons.visibility_off_outlined : Icons.timer_outlined,
          size: 18,
        ),
        label: Text(hidden ? 'Oculto' : _time(seconds)),
      ),
    ),
  );

  static String _time(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}

class _QuestionStatus extends StatelessWidget {
  const _QuestionStatus({
    required this.current,
    required this.total,
    required this.answered,
    required this.marked,
  });
  final int current;
  final int total;
  final int answered;
  final int marked;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'Questão ${current + 1} de $total',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      Text(
        '$answered respondidas · $marked revisar',
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    ],
  );
}

class _QuestionContent extends StatelessWidget {
  const _QuestionContent({
    required this.question,
    required this.selected,
    required this.onSelected,
    super.key,
  });
  final Question question;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        question.topic.toUpperCase(),
        style: const TextStyle(
          color: AppColors.brandHover,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .7,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      SelectableText(
        question.statement,
        semanticsLabel: question.statement,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontSize: 20, height: 1.5),
      ),
      const SizedBox(height: AppSpacing.xl),
      ...List.generate(question.options.length, (index) {
        final active = selected == index;
        final letter = String.fromCharCode(65 + index);
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Semantics(
            button: true,
            selected: active,
            toggled: active,
            label: 'Alternativa $letter, ${question.options[index]}',
            child: InkWell(
              onTap: () => onSelected(index),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.fast),
                constraints: const BoxConstraints(minHeight: 60),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.brandSoft
                      : Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: active
                        ? AppColors.brand
                        : Theme.of(context).colorScheme.outline,
                    width: active ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: AppMotion.of(context, AppMotion.fast),
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.brand
                            : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        letter,
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        question.options[index],
                        style: const TextStyle(fontSize: 16, height: 1.4),
                      ),
                    ),
                    if (active)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.brand,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    ],
  );
}

class _FocusActions extends StatelessWidget {
  const _FocusActions({
    required this.marked,
    required this.last,
    required this.onToggleReview,
    required this.onPrevious,
    required this.onNext,
  });
  final bool marked;
  final bool last;
  final VoidCallback onToggleReview;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: 3,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Row(
              children: [
                IconButton(
                  tooltip: marked
                      ? 'Remover da revisão'
                      : 'Marcar para revisão',
                  onPressed: onToggleReview,
                  icon: Icon(
                    marked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                  ),
                  color: marked ? AppColors.warning : null,
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: onPrevious,
                  child: const Text('Anterior'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: onNext,
                  icon: Icon(
                    last
                        ? Icons.fact_check_outlined
                        : Icons.arrow_forward_rounded,
                  ),
                  label: Text(last ? 'Revisar entrega' : 'Próxima'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _QuestionNavigator extends StatelessWidget {
  const _QuestionNavigator({
    required this.total,
    required this.current,
    required this.answers,
    required this.review,
    required this.onSelect,
  });
  final int total;
  final int current;
  final Map<int, int> answers;
  final Set<int> review;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      border: Border(
        right: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
    ),
    child: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Questões', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Selecione um número para navegar.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.lg),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: total,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (_, index) => _NumberButton(
            index: index,
            current: current == index,
            answered: answers.containsKey(index),
            marked: review.contains(index),
            onTap: () => onSelect(index),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _Legend(),
      ],
    ),
  );
}

class _MobileQuestionStrip extends StatelessWidget {
  const _MobileQuestionStrip({
    required this.total,
    required this.current,
    required this.answers,
    required this.review,
    required this.onSelect,
  });
  final int total;
  final int current;
  final Map<int, int> answers;
  final Set<int> review;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: total,
      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
      itemBuilder: (_, index) => SizedBox(
        width: 44,
        child: _NumberButton(
          index: index,
          current: current == index,
          answered: answers.containsKey(index),
          marked: review.contains(index),
          onTap: () => onSelect(index),
        ),
      ),
    ),
  );
}

class _NumberButton extends StatelessWidget {
  const _NumberButton({
    required this.index,
    required this.current,
    required this.answered,
    required this.marked,
    required this.onTap,
  });
  final int index;
  final bool current;
  final bool answered;
  final bool marked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Questão ${index + 1}${answered ? ', respondida' : ', não respondida'}${marked ? ', marcada para revisão' : ''}',
    selected: current,
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.fast),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: current
              ? AppColors.brand
              : answered
              ? AppColors.brandSoft
              : Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: marked
                ? AppColors.warning
                : current
                ? AppColors.brand
                : Theme.of(context).colorScheme.outline,
            width: marked ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${index + 1}',
              style: TextStyle(
                color: current ? Colors.white : null,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (answered && !current)
              const Positioned(
                right: 3,
                bottom: 3,
                child: Icon(
                  Icons.check_rounded,
                  size: 10,
                  color: AppColors.brandHover,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _LegendItem(Icons.check_circle_outline_rounded, 'Respondida'),
      _LegendItem(Icons.radio_button_unchecked_rounded, 'Não respondida'),
      _LegendItem(Icons.bookmark_outline_rounded, 'Revisar'),
    ],
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: const TextStyle(color: AppColors.muted)),
      ],
    ),
  );
}

class _DeliveryReview extends StatelessWidget {
  const _DeliveryReview({
    required this.total,
    required this.answers,
    required this.review,
    required this.onQuestion,
  });
  final int total;
  final Map<int, int> answers;
  final Set<int> review;
  final ValueChanged<int> onQuestion;

  @override
  Widget build(BuildContext context) {
    final blank = List.generate(
      total,
      (index) => index,
    ).where((index) => !answers.containsKey(index)).toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Revisar antes de entregar',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('${answers.length} de $total respondidas'),
            const SizedBox(height: AppSpacing.lg),
            if (blank.isNotEmpty) ...[
              const Text(
                'Não respondidas',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: blank
                    .map(
                      (index) => ActionChip(
                        label: Text('${index + 1}'),
                        onPressed: () => onQuestion(index),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (review.isNotEmpty) ...[
              const Text(
                'Marcadas para revisão',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: review
                    .map(
                      (index) => ActionChip(
                        avatar: const Icon(
                          Icons.bookmark_outline_rounded,
                          size: 16,
                        ),
                        label: Text('${index + 1}'),
                        onPressed: () => onQuestion(index),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.send_rounded),
              label: Text(
                blank.isEmpty
                    ? 'Entregar prova'
                    : 'Entregar mesmo com questões em branco',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar revisando'),
            ),
          ],
        ),
      ),
    );
  }
}
