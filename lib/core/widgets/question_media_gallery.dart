import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/backend/exam_media_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/exam.dart';

class QuestionMediaGallery extends StatelessWidget {
  const QuestionMediaGallery({required this.media, super.key});

  final List<QuestionMedia> media;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in media)
          _QuestionMediaItem(
            key: ValueKey('${item.id}:${item.sha256}'),
            media: item,
          ),
      ],
    );
  }
}

class _QuestionMediaItem extends StatefulWidget {
  const _QuestionMediaItem({required this.media, super.key});

  final QuestionMedia media;

  @override
  State<_QuestionMediaItem> createState() => _QuestionMediaItemState();
}

class _QuestionMediaItemState extends State<_QuestionMediaItem> {
  late Future<Uint8List> _image;

  @override
  void initState() {
    super.initState();
    _image = _load();
  }

  Future<Uint8List> _load() => widget.media.localBytes != null
      ? Future.value(widget.media.localBytes!)
      : ExamMediaRepository.shared.download({
          'id': widget.media.id,
          'object_key': widget.media.objectKey,
          'sha256': widget.media.sha256,
        });

  void _retry() => setState(() => _image = _load());

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: FutureBuilder<Uint8List>(
      future: _image,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Não foi possível carregar esta imagem.'),
              TextButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando imagem da questão',
              ),
            ),
          );
        }
        final label = widget.media.altText.trim().isEmpty
            ? 'Imagem da questão'
            : widget.media.altText.trim();
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
            semanticLabel: label,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => Semantics(
              liveRegion: true,
              child: Text(
                'A imagem "$label" está indisponível.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    ),
  );
}
