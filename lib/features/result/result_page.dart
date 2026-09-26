import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/source_badge.dart';
import '../../core/backend/attempt_sync_service.dart';
import '../../domain/models/exam.dart';

class PendingResultPage extends StatefulWidget {
  const PendingResultPage({
    required this.clientAttemptId,
    required this.syncService,
    super.key,
  });
  final String clientAttemptId;
  final AttemptSyncService syncService;

  @override
  State<PendingResultPage> createState() => _PendingResultPageState();
}

class _PendingResultPageState extends State<PendingResultPage>
    with WidgetsBindingObserver {
  PendingAttempt? attempt;
  Timer? retryTimer;
  bool syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _sync({
    bool ignoreSchedule = false,
    bool retryAttention = false,
  }) async {
    if (!mounted || syncing) return;
    setState(() => syncing = true);
    try {
      final outcome = await widget.syncService.sync(
        widget.clientAttemptId,
        ignoreSchedule: ignoreSchedule,
        retryAttention: retryAttention,
      );
      if (!mounted) return;
      if (outcome.result != null) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ResultPage(result: outcome.result!),
          ),
        );
        return;
      }
      setState(() => attempt = outcome.attempt);
      _schedule(outcome.attempt.nextAttemptAt);
    } catch (_) {
      if (mounted) {
        final stored = await widget.syncService.store.find(
          widget.clientAttemptId,
        );
        if (mounted) setState(() => attempt = stored);
      }
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  void _schedule(DateTime? when) {
    retryTimer?.cancel();
    if (when == null) return;
    final delay = when.difference(DateTime.now());
    retryTimer = Timer(delay.isNegative ? Duration.zero : delay, _sync);
  }

  @override
  Widget build(BuildContext context) {
    final state = syncing ? AttemptSyncState.sending : attempt?.state;
    final (title, message, icon) = switch (state) {
      AttemptSyncState.sending => (
        'Enviando entrega',
        'Aguarde enquanto enviamos suas respostas para correção.',
        Icons.sync_rounded,
      ),
      AttemptSyncState.requiresAttention => (
        'Entrega requer atenção',
        attempt?.lastError ?? 'O servidor recusou esta entrega.',
        Icons.error_outline_rounded,
      ),
      AttemptSyncState.synced => (
        'Entrega sincronizada',
        'A correção está disponível.',
        Icons.check_circle_outline_rounded,
      ),
      _ => (
        'Entrega salva no aparelho — aguardando correção',
        state == AttemptSyncState.waitingConnection
            ? 'Aguardando conexão. Tentaremos novamente no horário programado.'
            : 'A entrega está segura no aparelho e será enviada em seguida.',
        Icons.cloud_off_rounded,
      ),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Entrega da prova')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 56,
                    color: state == AttemptSyncState.requiresAttention
                        ? AppColors.danger
                        : AppColors.brand,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center),
                  if (!syncing) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () =>
                          _sync(ignoreSchedule: true, retryAttention: true),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar agora'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.brandHover,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PROVA CONCLUÍDA',
                            style: TextStyle(
                              color: AppColors.mint,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            result.exam.questions.any(
                                  (question) => question.correctIndex != null,
                                )
                                ? '${result.scorePercent}%'
                                : '—',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 64,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -3,
                            ),
                          ),
                          Text(
                            result.exam.questions.any(
                                  (question) => question.correctIndex != null,
                                )
                                ? '${result.correct} de ${result.exam.questions.length} acertos'
                                : 'Gabarito indisponível',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Suas questões para revisão estão organizadas abaixo.',
                            style: TextStyle(color: Color(0xFFD7F3E7)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value: _time(result.durationSeconds),
                          label: 'Tempo total',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Stat(
                          value: '${result.correct}',
                          label: 'Corretas',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Stat(
                          value:
                              '${result.exam.questions.length - result.correct}',
                          label: 'Revisar',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text('Erradas: ${result.wrongQuestionIndices.length}'),
                      Text('Em branco: ${result.unanswered}'),
                      Text('Marcadas: ${result.markedForReview.length}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SourceBadge(sourceType: result.exam.sourceType),
                  Text(result.exam.author),
                  if (result.exam.safeSourceUrl case final sourceUrl?)
                    TextButton.icon(
                      onPressed: () => launchUrl(sourceUrl),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Abrir fonte'),
                    ),
                  for (final topic in result.byTopic.entries)
                    Text(
                      '${topic.key}: ${topic.value.correct}/${topic.value.total} acertos',
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Revisão das questões',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _copyJson(context),
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copiar JSON'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(result.exam.questions.length, (index) {
                    final question = result.exam.questions[index];
                    final selected = result.answers[index];
                    final correct =
                        question.correctIndex != null &&
                        selected == question.correctIndex;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    question.correctIndex == null
                                        ? Icons.help_outline_rounded
                                        : correct
                                        ? Icons.check_circle_rounded
                                        : Icons.cancel_rounded,
                                    color: question.correctIndex == null
                                        ? AppColors.muted
                                        : correct
                                        ? AppColors.success
                                        : AppColors.danger,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Questão ${index + 1}: ${correct ? 'Correta' : 'Revisar'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(question.statement),
                              if (result.markedForReview.contains(index))
                                const Text('Marcada para revisão'),
                              const SizedBox(height: 8),
                              Text(
                                'Sua resposta: ${selected == null ? 'Em branco' : question.options[selected]}',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                              if (!correct) ...[
                                Text(
                                  question.correctIndex == null
                                      ? 'Gabarito indisponível'
                                      : 'Gabarito: ${question.options[question.correctIndex!]}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyJson(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(
        text: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Resultado JSON copiado.')));
    }
  }

  static String _time(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}
