import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/exam.dart';
import '../result/result_page.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({required this.exam, super.key});
  final Exam exam;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final answers = <int, int>{};
  final review = <int>{};
  late final Timer timer;
  int current = 0;
  int seconds = 0;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => seconds++);
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.exam.questions[current];
    return Scaffold(
      appBar: AppBar(title: Text(widget.exam.title, overflow: TextOverflow.ellipsis), actions: [
        Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Chip(avatar: const Icon(Icons.timer_outlined, size: 17), label: Text(_time(seconds), style: const TextStyle(fontWeight: FontWeight.w800))))),
      ]),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: List.generate(widget.exam.questions.length, (index) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Badge(
                      isLabelVisible: review.contains(index),
                      backgroundColor: AppColors.amber,
                      child: FilledButton.tonal(onPressed: () => setState(() => current = index), style: FilledButton.styleFrom(backgroundColor: current == index ? AppColors.blue : answers.containsKey(index) ? AppColors.blueSoft : Colors.white, foregroundColor: current == index ? Colors.white : AppColors.ink, minimumSize: const Size(44, 44), padding: EdgeInsets.zero), child: Text('${index + 1}')),
                    ),
                  ))),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('QUESTÃO ${current + 1} DE ${widget.exam.questions.length} · ${question.topic.toUpperCase()}', style: const TextStyle(color: AppColors.blue, fontSize: 11, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      Text(question.statement, style: const TextStyle(fontSize: 19, height: 1.4, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 20),
                      ...List.generate(question.options.length, (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RadioListTile<int>(
                          value: index,
                          groupValue: answers[current],
                          onChanged: (value) => setState(() => answers[current] = value!),
                          title: Text(question.options[index]),
                          secondary: CircleAvatar(radius: 16, backgroundColor: answers[current] == index ? AppColors.blue : AppColors.paper, child: Text(String.fromCharCode(65 + index), style: TextStyle(color: answers[current] == index ? Colors.white : AppColors.ink, fontSize: 12, fontWeight: FontWeight.w800))),
                          shape: RoundedRectangleBorder(side: BorderSide(color: answers[current] == index ? AppColors.blue : AppColors.line), borderRadius: BorderRadius.circular(14)),
                          tileColor: answers[current] == index ? AppColors.blueSoft : Colors.white,
                        ),
                      )),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 10, children: [
                  OutlinedButton.icon(onPressed: () => setState(() => review.contains(current) ? review.remove(current) : review.add(current)), icon: Icon(review.contains(current) ? Icons.star_rounded : Icons.star_border_rounded), label: Text(review.contains(current) ? 'Marcada para revisão' : 'Marcar para revisão')),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    OutlinedButton(onPressed: current == 0 ? null : () => setState(() => current--), child: const Text('Anterior')),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: current == widget.exam.questions.length - 1 ? _confirmFinish : () => setState(() => current++), child: Text(current == widget.exam.questions.length - 1 ? 'Entregar prova' : 'Próxima')),
                  ]),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmFinish() async {
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Entregar a prova?'),
      content: Text('${answers.length} de ${widget.exam.questions.length} questões respondidas${review.isEmpty ? '.' : ' e ${review.length} marcada(s) para revisão.'}'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuar prova')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Entregar'))],
    ));
    if (accepted != true || !mounted) return;
    timer.cancel();
    final result = ExamResult(exam: widget.exam, answers: Map.of(answers), markedForReview: Set.of(review), durationSeconds: seconds, finishedAt: DateTime.now());
    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => ResultPage(result: result)));
  }

  String _time(int value) => '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}
