import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExamMediaInput {
  const ExamMediaInput({
    required this.bytes,
    required this.mimeType,
    required this.questionPosition,
    required this.altText,
    this.width,
    this.height,
  });

  final Uint8List bytes;
  final String mimeType;
  final int questionPosition;
  final String altText;
  final int? width;
  final int? height;
}

class ExamMediaRepository {
  ExamMediaRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const bucket = 'exam-content';
  static const allowedMimeTypes = {
    'image/webp': 'webp',
    'image/svg+xml': 'svg',
    'image/png': 'png',
    'image/jpeg': 'jpg',
  };

  final SupabaseClient _client;
  final Map<String, Uint8List> _memoryCache = {};

  Future<Map<String, dynamic>> attach({
    required String examId,
    required ExamMediaInput media,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Faça login para publicar.');
    final extension = allowedMimeTypes[media.mimeType];
    if (extension == null) {
      throw ArgumentError('Formato de imagem não permitido: ${media.mimeType}');
    }
    if (media.bytes.isEmpty || media.bytes.length > 5242880) {
      throw ArgumentError('Cada imagem deve ter no máximo 5 MB.');
    }

    final hash = sha256.convert(media.bytes).toString();
    final existing = await _client
        .from('media_assets')
        .select()
        .eq('owner_id', user.id)
        .eq('sha256', hash)
        .maybeSingle();

    Map<String, dynamic> asset;
    if (existing != null) {
      asset = Map<String, dynamic>.from(existing);
    } else {
      final objectKey = '${user.id}/media/$hash.$extension';
      await _client.storage.from(bucket).uploadBinary(
            objectKey,
            media.bytes,
            fileOptions: FileOptions(contentType: media.mimeType, upsert: false),
          );
      try {
        asset = await _client.from('media_assets').insert({
          'owner_id': user.id,
          'object_key': objectKey,
          'sha256': hash,
          'mime_type': media.mimeType,
          'byte_size': media.bytes.length,
          'width': media.width,
          'height': media.height,
        }).select().single();
      } catch (_) {
        await _client.storage.from(bucket).remove([objectKey]);
        rethrow;
      }
    }

    await _client.from('exam_media').upsert({
      'exam_id': examId,
      'asset_id': asset['id'],
      'question_position': media.questionPosition,
      'role': 'question_figure',
      'alt_text': media.altText,
    });
    return asset;
  }

  Future<Uint8List> download(Map<String, dynamic> asset) async {
    final id = asset['id'] as String;
    final cached = _memoryCache[id];
    if (cached != null) return cached;
    final bytes = await _client.storage
        .from(bucket)
        .download(asset['object_key'] as String);
    _memoryCache[id] = bytes;
    return bytes;
  }
}
