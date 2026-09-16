import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/backend/attempt_draft_store.dart';
import '../../core/backend/attempt_repository.dart';
import '../../domain/models/exam.dart';
import '../result/result_page.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({required this.exam, super.key});
  final Exam exam;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  static const draftStore = AttemptDraftStore();
  final answers = <int, int>{};
  final review = <int>{};
  final elapsed = ValueNotifier<int>(0);
  late final Timer timer;
  int current = 0;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => elapsed.value++);
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final draft = await draftStore.load(widget.exam.id);
    if (draft == null || !mounted) return;
    setState(() {
      answers.addAll(draft.answers);
      review.addAll(draft.review);
      current = draft.current.clamp(0, widget.exam.questions.length - 1).toInt();
      elapsed.value = draft.elapsedSeconds;
    });
  }

  Future<void> _persistDraft() => draftStore.save(
        widget.exam.id,
        AttemptDraft(
          answers: Map.of(answers),
          review: Set.of(review),
          current: current,
          elapsedSeconds: elapsed.value,
        ),
      );

  @override
  void dispose() {
    timer.cancel();
    elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
              const Text('MODO FOCO',
                  style: TextStyle(
                    color: AppColors.brandHover,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  )),
              Text(widget.exam.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          actions: [
            _ExamTimer(elapsed: elapsed),
            const SizedBox(width: AppSpacing.sm),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: (current + 1) / widget.exam.questions.length,
              minHeight: 4,
              backgroundColor: AppColors.line,
              color: AppColors.brand,
            ),
          ),
        ),
        body: LayoutBuilder(builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 980;
          return Row(children: [
            if (desktop)
              SizedBox(
                width: 280,
                child: _QuestionNavigator(
                  total: widget.exam.questions.length,
                  current: current,
                  answers: answers,
                  review: review,
                  onSelect: _selectQuestion,
                ),
              ),
            Expanded(
              child: Column(children: [
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
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _QuestionStatus(
                              current: current,
                              total: widget.exam.questions.length,
                              answered: answers.length,
                              marked: review.length,
                            ),
                            if (!desktop) ...[
                              const SizedBox(height: AppSpacing.md),
                              _MobileQuestionStrip(
                                total: widget.exam.questions.length,
                                current: current,
                                answers: answers,
                                review: review,
                                onSelect: _selectQuestion,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            AnimatedSwitcher(
                              duration: AppMotion.of(context, AppMotion.fast),
                              child: _QuestionContent(
                                key: ValueKey(current),
                                question: widget.exam.questions[current],
                                selected: answers[current],
                                onSelected: (answer) {
                                  setState(() => answers[current] = answer);
                                  _persistDraft();
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
                  onToggleReview: () => setState(() {
                    review.contains(current)
                        ? review.remove(current)
                        : review.add(current);
                    _persistDraft();
                  }),
                  onPrevious:
                      current == 0 ? null : () => _selectQuestion(current - 1),
                  onNext: current == widget.exam.questions.length - 1
                      ? _openReview
                      : () => _selectQuestion(current + 1),
                  last: current == widget.exam.questions.length - 1,
                ),
              ]),
            ),
          ]);
        }),
      );

  void _selectQuestion(int index) {
    setState(() => current = index);
    _persistDraft();
  }

  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.pause_circle_outline_rounded),
        title: const Text('Pausar esta prova?'),
        content: const Text(
          'Suas respostas continuam nesta sessão. A sincronização permanente será conectada ao histórico.',
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
    if (leave == true && mounted) Navigator.pop(context);
  }

  Future<void> _openReview() async {
    final finish = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _DeliveryReview(
        total: widget.exam.questions.length,
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
    timer.cancel();
    final result = ExamResult(
      exam: widget.exam,
      answers: Map.of(answers),
      markedForReview: Set.of(review),
      durationSeconds: elapsed.value,
      finishedAt: DateTime.now(),
    );
    try {
      await AttemptRepository().saveCompleted(result);
      await draftStore.clear(widget.exam.id);
    } catch (_) {
      await _persistDraft();
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ResultPage(result: result)),
    );
  }
}

class _ExamTimer extends StatelessWidget {
  const _ExamTimer({required this.elapsed});
  final ValueListenable<int> elapsed;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: elapsed,
        builder: (_, seconds, __) => Semantics(
          label: 'Tempo de prova ${_time(seconds)}',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(children: [
              const Icon(Icons.timer_outlined, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text(_time(seconds),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
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
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text('Questão ${current + 1} de $total',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        Text('$answered respondidas · $marked revisar',
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ]);
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
          Text(question.topic.toUpperCase(),
              style: const TextStyle(
                color: AppColors.brandHover,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .7,
              )),
          const SizedBox(height: AppSpacing.md),
          SelectableText(
            question.statement,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  height: 1.5,
                ),
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
                    child: Row(children: [
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
                        child: Text(letter,
                            style: TextStyle(
                              color: active
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            )),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(question.options[index],
                            style: const TextStyle(fontSize: 16, height: 1.4)),
                      ),
                      if (active)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.brand),
                    ]),
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
                child: Row(children: [
                  IconButton(
                    tooltip: marked
                        ? 'Remover da revisão'
                        : 'Marcar para revisão',
                    onPressed: onToggleReview,
                    icon: Icon(marked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded),
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
                    icon: Icon(last
                        ? Icons.fact_check_outlined
                        : Icons.arrow_forward_rounded),
                    label: Text(last ? 'Revisar entrega' : 'Próxima'),
                  ),
                ]),
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
            const Text('Selecione um número para navegar.',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
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
            child: Stack(alignment: Alignment.center, children: [
              Text('${index + 1}',
                  style: TextStyle(
                    color: current ? Colors.white : null,
                    fontWeight: FontWeight.w700,
                  )),
              if (answered && !current)
                const Positioned(
                  right: 3,
                  bottom: 3,
                  child: Icon(Icons.check_rounded,
                      size: 10, color: AppColors.brandHover),
                ),
            ]),
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
        child: Row(children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: const TextStyle(color: AppColors.muted)),
        ]),
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
    final blank = List.generate(total, (index) => index)
        .where((index) => !answers.containsKey(index))
        .toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Revisar antes de entregar',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text('${answers.length} de $total respondidas'),
            const SizedBox(height: AppSpacing.lg),
            if (blank.isNotEmpty) ...[
              const Text('Não respondidas',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: blank
                    .map((index) => ActionChip(
                          label: Text('${index + 1}'),
                          onPressed: () => onQuestion(index),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (review.isNotEmpty) ...[
              const Text('Marcadas para revisão',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: review
                    .map((index) => ActionChip(
                          avatar: const Icon(Icons.bookmark_outline_rounded,
                              size: 16),
                          label: Text('${index + 1}'),
                          onPressed: () => onQuestion(index),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.send_rounded),
              label: Text(blank.isEmpty
                  ? 'Entregar prova'
                  : 'Entregar mesmo com questões em branco'),
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
