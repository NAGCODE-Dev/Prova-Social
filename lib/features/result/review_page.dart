import 'package:flutter/material.dart';
import 'package:prova_social/domain/models/exam.dart';

enum QuestionState { all, wrong, correct, notAnswered, noKey }

class ReviewPage extends StatelessWidget {
  const ReviewPage({
    required this.result,
    required this.onFilterChanged,
    super.key,
  });

  final ExamResult result;
  final ValueChanged<QuestionState> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final totalQuestions = result.exam.questions.length;
    final wrongCount = result.wrongQuestionIndices.length;
    final noAnswerKey = totalQuestions - result.correct - wrongCount - result.unanswered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisão de Respostas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrar questões',
            onPressed: () => onFilterChanged(QuestionState.all),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(onFilterChanged: onFilterChanged),
          const Divider(),
          _FilterCount(
            correct: result.correct,
            wrong: wrongCount,
            unanswered: result.unanswered,
            noAnswerKey: noAnswerKey,
            total: totalQuestions,
          ),
          const Expanded(child: _QuestionList(result: result, onFilterChanged: onFilterChanged)),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.onFilterChanged});

  final ValueChanged<QuestionState> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: QuestionState.values.map((state) {
          return FilterChip(
            label: Text(_getLabel(state)),
            selected: false,
            onSelected: (_) => onFilterChanged(state),
          );
        }).toList(),
      ),
    );
  }

  String _getLabel(QuestionState state) {
    switch (state) {
      case QuestionState.all:
        return 'Todas';
      case QuestionState.wrong:
        return 'Erradas';
      case QuestionState.correct:
        return 'Certas';
      case QuestionState.notAnswered:
        return 'Em branco';
      case QuestionState.noKey:
        return 'Sem gabarito';
    }
  }
}

class _FilterCount extends StatelessWidget {
  const _FilterCount({
    required this.correct,
    required this.wrong,
    required this.unanswered,
    required this.noAnswerKey,
    required this.total,
  });

  final int correct;
  final int wrong;
  final int unanswered;
  final int noAnswerKey;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CountBox(label: 'Certas', value: correct),
          _CountBox(label: 'Erradas', value: wrong),
          _CountBox(label: 'Em branco', value: unanswered),
          if (noAnswerKey > 0) _CountBox(label: 'Sem gabarito', value: noAnswerKey),
        ],
      ),
    );
  }
}

class _CountBox extends StatelessWidget {
  const _CountBox({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [Text(value.toString()), const SizedBox(height: 4), Text(label)],
    );
  }
}

class _QuestionList extends StatefulWidget {
  const _QuestionList({required this.result, required this.onFilterChanged});

  final ExamResult result;
  final ValueChanged<QuestionState> onFilterChanged;

  @override
  State<_QuestionList> createState() => _QuestionListState();
}

class _QuestionListState extends State<_QuestionList> {
  QuestionState _activeFilter = QuestionState.all;
  List<int> _filteredIndices = [];
  List<Question> _filteredQuestions = [];

  @override
  void initState() {
    super.initState();
    _refreshFiltered();
  }

  void _refreshFiltered() {
    final r = widget.result;
    switch (_activeFilter) {
      case QuestionState.wrong:
        _filteredIndices = List.of(r.wrongQuestionIndices);
        break;
      case QuestionState.correct:
        _filteredIndices = _getCorrectIndices();
        break;
      case QuestionState.notAnswered:
        _filteredIndices = _getNotAnsweredIndices();
        break;
      case QuestionState.noKey:
        _filteredIndices = _getNoKeyIndices();
        break;
      case QuestionState.all:
      default:
        _filteredIndices = List.generate(r.exam.questions.length, (i) => i);
    }
    _filteredQuestions = _filteredIndices.map((i) => r.exam.questions[i]).toList();
    setState(() {});
  }

  List<int> _getNotAnsweredIndices() {
    final all = List.generate(widget.result.exam.questions.length, (i) => i);
    return all.where((i) => widget.result.answers[i] == null).toList();
  }

  List<int> _getNoKeyIndices() {
    final all = List.generate(widget.result.exam.questions.length, (i) => i);
    return all.where((i) => widget.result.exam.questions[i].correctIndex == null).toList();
  }

  List<int> _getCorrectIndices() {
    final all = List.generate(widget.result.exam.questions.length, (i) => i);
    return all.where((i) {
      final selected = widget.result.answers[i];
      return selected != null && selected == widget.result.exam.questions[i].correctIndex;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final questionCount = _filteredIndices.length;

    if (questionCount == 0) {
      return const Center(child: Text('Nenhuma questão com este filtro'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: questionCount,
      itemBuilder: (context, listIndex) {
        final questionIndex = _filteredIndices[listIndex];
        final question = _filteredQuestions[listIndex];
        final selected = widget.result.answers[questionIndex];
        final isCorrect = selected != null && selected == question.correctIndex;
        final isWrong = selected != null && selected != question.correctIndex;
        final isNotAnswered = selected == null;
        final hasNoKey = question.correctIndex == null;

        String correctAnswer;
        String userAnswer;

        if (hasNoKey) {
          correctAnswer = 'Sem gabarito';
          userAnswer = selected != null ? question.options[selected] : 'Em branco';
        } else if (isCorrect) {
          correctAnswer = 'Gabarito: ${question.options[question.correctIndex!]}';
          userAnswer = question.options[selected!];
        } else if (isWrong) {
          correctAnswer = 'Gabarito: ${question.options[question.correctIndex!]}';
          userAnswer = question.options[selected!];
        } else {
          correctAnswer = 'Gabarito: ${question.options[question.correctIndex!]}';
          userAnswer = 'Em branco';
        }

        final listPosition = listIndex + 1;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StateIcon(isWrong: isWrong, isNotAnswered: isNotAnswered, hasNoKey: hasNoKey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Questão ${listPosition} de $questionCount: ${question.statement}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _AnswerRow(label: 'Sua resposta:', value: userAnswer),
                const SizedBox(height: 4),
                _AnswerRow(label: 'Gabarito:', value: correctAnswer),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (listIndex > 0) const IconButton(icon: Icon(Icons.arrow_back_rounded), tooltip: 'Anterior', onPressed: () {}),
                    if (listIndex < questionCount - 1) IconButton(icon: Icon(Icons.arrow_forward_rounded), tooltip: 'Próxima', onPressed: () {}),
                    const Spacer(),
                    Text('${listPosition} de $questionCount', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StateIcon extends StatelessWidget {
  const _StateIcon({required this.isWrong, required this.isNotAnswered, required this.hasNoKey});

  final bool isWrong;
  final bool isNotAnswered;
  final bool hasNoKey;

  @override
  Widget build(BuildContext context) {
    if (hasNoKey) return const Icon(Icons.lock_outline, color: Colors.orange);
    if (isNotAnswered) return const Icon(Icons.remove_circle_outline, color: Colors.grey);
    if (isWrong) return const Icon(Icons.close, color: Colors.red);
    return const Icon(Icons.check, color: Colors.green);
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(children: [Text('$label ', style: const TextStyle(fontWeight: FontWeight.w600)), Expanded(child: Text(value))]);
  }
}
