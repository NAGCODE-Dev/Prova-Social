import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/exam.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({required this.result, super.key});
  final ExamResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: AppColors.brandHover, borderRadius: BorderRadius.circular(16)),
                  child: Padding(padding: const EdgeInsets.all(26), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('PROVA CONCLUÍDA', style: TextStyle(color: AppColors.mint, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Text('${result.scorePercent}%', style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900, letterSpacing: -3)),
                    Text('${result.correct} de ${result.exam.questions.length} acertos', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text('Suas questões para revisão estão organizadas abaixo.', style: TextStyle(color: Color(0xFFD7F3E7))),
                  ])),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: _Stat(value: _time(result.durationSeconds), label: 'Tempo total')),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(value: '${result.correct}', label: 'Corretas')),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(value: '${result.exam.questions.length - result.correct}', label: 'Revisar')),
                ]),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(child: Text('Revisão das questões', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                  TextButton.icon(onPressed: () => _copyJson(context), icon: const Icon(Icons.copy_rounded), label: const Text('Copiar JSON')),
                ]),
                const SizedBox(height: 10),
                ...List.generate(result.exam.questions.length, (index) {
                  final question = result.exam.questions[index];
                  final selected = result.answers[index];
                  final correct = selected == question.correctIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Icon(correct ? Icons.check_circle_rounded : Icons.cancel_rounded, color: correct ? AppColors.success : AppColors.danger), const SizedBox(width: 8), Text('Questão ${index + 1}: ${correct ? 'Correta' : 'Revisar'}', style: const TextStyle(fontWeight: FontWeight.w800))]),
                      const SizedBox(height: 8),
                      Text('Sua resposta: ${selected == null ? 'Em branco' : question.options[selected]}', style: const TextStyle(color: AppColors.muted)),
                      if (!correct) ...[
                        Text('Gabarito: ${question.options[question.correctIndex]}', style: const TextStyle(color: AppColors.muted)),
                      ],
                    ]))),
                  );
                }),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyJson(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(result.toJson())));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resultado JSON copiado.')));
    }
  }

  static String _time(int value) => '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.muted))])));
}
