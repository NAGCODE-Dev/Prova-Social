import 'package:flutter/material.dart';

import '../../core/backend/exam_repository.dart';
import '../../core/navigation/share_link_service.dart';
import '../../core/widgets/question_media_gallery.dart';
import '../../core/widgets/source_badge.dart';
import '../../domain/models/exam.dart';
import '../auth/auth_page.dart';
import '../quiz/quiz_page.dart';
import 'question_discussion.dart';

class ShareLinkPage extends StatefulWidget {
  const ShareLinkPage({required this.destination, super.key});

  final ShareLinkDestination destination;

  @override
  State<ShareLinkPage> createState() => _ShareLinkPageState();
}

class _ShareLinkPageState extends State<ShareLinkPage> {
  late final Future<Exam?> exam = ExamRepository().publicExamById(
    widget.destination.examId,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Prova Social')),
    body: FutureBuilder<Exam?>(
      future: exam,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _Message(
            title: 'Não foi possível abrir esta prova',
            body: 'Confira sua conexão e tente abrir o link novamente.',
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final value = snapshot.data;
        if (value == null) {
          return const _Message(
            title: 'Prova não encontrada',
            body: 'Ela pode ter sido removida ou deixado de ser pública.',
          );
        }
        final selected = widget.destination.questionId == null
            ? null
            : value.questions
                  .where(
                    (question) => question.id == widget.destination.questionId,
                  )
                  .firstOrNull;
        if (widget.destination.questionId != null && selected == null) {
          return const _Message(
            title: 'Questão não encontrada',
            body: 'Esta questão não está mais disponível nesta prova.',
          );
        }
        return _PublicContent(exam: value, question: selected);
      },
    ),
  );
}

class _PublicContent extends StatelessWidget {
  const _PublicContent({required this.exam, this.question});

  final Exam exam;
  final Question? question;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            exam.category.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(exam.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SourceBadge(sourceType: exam.sourceType),
              Text(
                '${exam.author}${exam.year == null ? '' : ' · ${exam.year}'} · ${exam.questions.length} questões',
              ),
            ],
          ),
          if (question != null) ...[
            const SizedBox(height: 28),
            Text(
              'Questão ${exam.questions.indexOf(question!) + 1}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              question!.statement,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (question!.media.isNotEmpty) ...[
              const SizedBox(height: 16),
              QuestionMediaGallery(media: question!.media),
            ],
            const SizedBox(height: 16),
            for (var index = 0; index < question!.options.length; index++)
              ListTile(
                leading: CircleAvatar(
                  child: Text(String.fromCharCode(65 + index)),
                ),
                title: Text(question!.options[index]),
              ),
            const SizedBox(height: 24),
            QuestionDiscussion(
              questionId: question!.id,
              topic: question!.topic,
              onSignIn: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const AuthPage(closeAfterAuth: true),
                  ),
                );
              },
            ),
          ] else ...[
            const SizedBox(height: 20),
            Text(exam.description),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => QuizPage(
                  exam: exam,
                  initialQuestionId: question?.id,
                  onSignIn: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const AuthPage(closeAfterAuth: true),
                      ),
                    );
                  },
                ),
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              question == null
                  ? 'Resolver esta prova'
                  : 'Resolver esta questão',
            ),
          ),
        ],
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
