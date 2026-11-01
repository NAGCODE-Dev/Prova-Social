import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/question_media_gallery.dart';
import '../../domain/models/exam.dart';

enum QuestionState { all, wrong, correct, notAnswered, noKey }

class ReviewPage extends StatefulWidget {
  const ReviewPage({required this.result, super.key});

  final ExamResult result;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  QuestionState _activeFilter = QuestionState.all;

  List<int> get _visibleIndices {
    final result = widget.result;
    return [
      for (var index = 0; index < result.exam.questions.length; index++)
        if (_matches(result, index)) index,
    ];
  }

  bool _matches(ExamResult result, int index) {
    final question = result.exam.questions[index];
    final selected = result.answers[index];
    return switch (_activeFilter) {
      QuestionState.all => true,
      QuestionState.wrong =>
        selected != null &&
            question.correctIndex != null &&
            selected != question.correctIndex,
      QuestionState.correct =>
        selected != null && selected == question.correctIndex,
      QuestionState.notAnswered => selected == null,
      QuestionState.noKey => question.correctIndex == null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final indices = _visibleIndices;
    final noKey = result.exam.questions
        .where((question) => question.correctIndex == null)
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('Revisão das questões')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (final state in QuestionState.values) ...[
                  if (state != QuestionState.all)
                    const SizedBox(width: AppSpacing.xs),
                  FilterChip(
                    label: Text(_label(state)),
                    selected: _activeFilter == state,
                    onSelected: (_) => setState(() => _activeFilter = state),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Count(label: 'Certas', value: result.correct),
                _Count(
                  label: 'Erradas',
                  value: result.wrongQuestionIndices.length,
                ),
                _Count(label: 'Em branco', value: result.unanswered),
                if (noKey > 0) _Count(label: 'Sem gabarito', value: noKey),
                _Count(label: 'Exibidas', value: indices.length),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: indices.isEmpty
                ? Center(
                    child: Text(
                      'Nenhuma questão ${_emptyFilterLabel(_activeFilter)}.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: indices.length,
                    itemBuilder: (context, listIndex) {
                      final questionIndex = indices[listIndex];
                      final question = result.exam.questions[questionIndex];
                      final selected = result.answers[questionIndex];
                      final isCorrect =
                          selected != null && selected == question.correctIndex;
                      final isWrong =
                          selected != null &&
                          question.correctIndex != null &&
                          selected != question.correctIndex;
                      final answer = selected == null
                          ? 'Em branco'
                          : question.options[selected];
                      final key = question.correctIndex == null
                          ? 'Gabarito indisponível'
                          : question.options[question.correctIndex!];
                      final status = isCorrect
                          ? 'Correta'
                          : isWrong
                          ? 'Errada'
                          : selected == null
                          ? 'Em branco'
                          : 'Sem gabarito';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isCorrect
                                        ? Icons.check_circle_rounded
                                        : Icons.error_outline_rounded,
                                    color: isCorrect
                                        ? AppColors.success
                                        : Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Questão ${questionIndex + 1} · $status',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  if (result.markedForReview.contains(
                                    questionIndex,
                                  ))
                                    const Tooltip(
                                      message: 'Marcada para revisão',
                                      child: Icon(Icons.bookmark_rounded),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(question.statement),
                              if (question.media.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                QuestionMediaGallery(media: question.media),
                              ],
                              const SizedBox(height: 10),
                              _Answer(label: 'Sua resposta', value: answer),
                              if (!isCorrect)
                                _Answer(label: 'Gabarito', value: key),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _label(QuestionState state) => switch (state) {
    QuestionState.all => 'Todas',
    QuestionState.wrong => 'Erradas',
    QuestionState.correct => 'Certas',
    QuestionState.notAnswered => 'Em branco',
    QuestionState.noKey => 'Sem gabarito',
  };

  static String _emptyFilterLabel(QuestionState state) => switch (state) {
    QuestionState.all => 'disponíveis',
    QuestionState.wrong => 'erradas',
    QuestionState.correct => 'corretas',
    QuestionState.notAnswered => 'em branco',
    QuestionState.noKey => 'sem gabarito',
  };
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Text('$label: $value');
}

class _Answer extends StatelessWidget {
  const _Answer({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text('$label: $value'),
  );
}
