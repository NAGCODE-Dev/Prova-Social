import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/backend/question_discussion_repository.dart';

class QuestionDiscussion extends StatefulWidget {
  const QuestionDiscussion({
    required this.questionId,
    required this.topic,
    required this.onSignIn,
    this.repository,
    super.key,
  });

  final String questionId;
  final String topic;
  final Future<void> Function() onSignIn;
  final QuestionDiscussionRepository? repository;

  @override
  State<QuestionDiscussion> createState() => _QuestionDiscussionState();
}

class _QuestionDiscussionState extends State<QuestionDiscussion> {
  final _comment = TextEditingController();
  late final QuestionDiscussionRepository _repository;
  List<QuestionComment> _comments = const [];
  TopicFollow? _topicFollow;
  bool _loading = true;
  bool _posting = false;
  bool _updatingFollow = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? QuestionDiscussionRepository();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final comments = await _repository.comments(widget.questionId);
      final topicFollow = await _repository.topicFollow(widget.topic);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _topicFollow = topicFollow;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[QUESTION_DISCUSSION] leitura falhou: ${error.runtimeType}');
      debugPrint('[QUESTION_DISCUSSION] stack: $stackTrace');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar a discussão. Confira a conexão e tente novamente.';
      });
    }
  }

  Future<void> _publishComment() async {
    final body = _comment.text.trim();
    if (body.isEmpty || _posting) return;
    if (body.length > 2000) {
      setState(() => _error = 'O comentário deve ter até 2000 caracteres.');
      return;
    }
    if (Supabase.instance.client.auth.currentUser == null) {
      await widget.onSignIn();
      if (!mounted || Supabase.instance.client.auth.currentUser == null) {
        return;
      }
    }
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await _repository.addComment(widget.questionId, body);
      if (!mounted) return;
      _comment.clear();
      await _refresh();
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _error = 'Entre na sua conta antes de publicar o comentário.';
      });
    } catch (error, stackTrace) {
      debugPrint(
        '[QUESTION_DISCUSSION] publicação falhou: ${error.runtimeType}',
      );
      debugPrint('[QUESTION_DISCUSSION] stack: $stackTrace');
      if (mounted) {
        setState(() {
          _error = 'O comentário não foi publicado. Seu texto foi preservado; tente novamente.';
        });
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _toggleTopicFollow() async {
    final current = _topicFollow;
    if (current == null || _updatingFollow) return;
    final wasAuthenticated = Supabase.instance.client.auth.currentUser != null;
    final shouldFollow = wasAuthenticated ? !current.isFollowing : true;
    setState(() {
      _updatingFollow = true;
      _error = null;
    });
    try {
      if (!wasAuthenticated) {
        await widget.onSignIn();
        if (!mounted || Supabase.instance.client.auth.currentUser == null) {
          return;
        }
        final refreshed = await _repository.topicFollow(widget.topic);
        if (refreshed == null) return;
        if (refreshed.isFollowing) {
          setState(() => _topicFollow = refreshed);
          return;
        }
      }
      await _repository.setTopicFollow(widget.topic, follow: shouldFollow);
      if (!mounted) return;
      setState(() {
        _topicFollow = TopicFollow(
          topicId: current.topicId,
          isFollowing: shouldFollow,
        );
      });
    } catch (error, stackTrace) {
      debugPrint('[TOPIC_FOLLOW] atualização falhou: ${error.runtimeType}');
      debugPrint('[TOPIC_FOLLOW] stack: $stackTrace');
      if (mounted) {
        setState(() {
          _error =
              'Não foi possível atualizar o assunto seguido. Tente novamente.';
        });
      }
    } finally {
      if (mounted) setState(() => _updatingFollow = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Discussão da questão',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (_topicFollow != null)
            TextButton.icon(
              onPressed: _updatingFollow ? null : _toggleTopicFollow,
              icon: _updatingFollow
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _topicFollow!.isFollowing
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_outlined,
                    ),
              label: Text(
                _topicFollow!.isFollowing ? 'Seguindo' : 'Seguir assunto',
              ),
            ),
        ],
      ),
      if (_error != null) ...[
        Semantics(
          liveRegion: true,
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ),
      ],
      if (_loading)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(
              semanticsLabel: 'Carregando discussão',
            ),
          ),
        )
      else if (_comments.isEmpty && _error == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Ainda não há comentários nesta questão.'),
        )
      else
        for (final comment in _comments)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text(comment.authorName.characters.first.toUpperCase()),
            ),
            title: Text(comment.authorName),
            subtitle: Text(
              '${_formatDate(context, comment.createdAt)}\n${comment.body}',
            ),
            isThreeLine: true,
          ),
      const SizedBox(height: 8),
      TextField(
        controller: _comment,
        maxLength: 2000,
        minLines: 2,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Escreva um comentário',
          alignLabelWithHint: true,
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _posting ? null : _publishComment,
          icon: _posting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
          label: Text(
            _posting
                ? 'Publicando'
                : Supabase.instance.client.auth.currentUser == null
                ? 'Entrar e comentar'
                : 'Publicar comentário',
          ),
        ),
      ),
    ],
  );

  String _formatDate(BuildContext context, DateTime date) {
    final local = date.toLocal();
    final day = MaterialLocalizations.of(context).formatShortDate(local);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$day · $time';
  }
}
