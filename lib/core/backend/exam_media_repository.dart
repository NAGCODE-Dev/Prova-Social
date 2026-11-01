import 'dart:collection';
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

class PreparedExamMediaAsset {
  const PreparedExamMediaAsset({required this.asset, required this.created});
  final Map<String, dynamic> asset;
  final bool created;
}

class ExamMediaRepository {
  ExamMediaRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const bucket = 'exam-content';
  static final shared = ExamMediaRepository();
  static const allowedMimeTypes = {
    'image/webp': 'webp',
    'image/svg+xml': 'svg',
    'image/png': 'png',
    'image/jpeg': 'jpg',
  };

  final SupabaseClient _client;
  final MediaByteCache _memoryCache = MediaByteCache(
    maxBytes: 24 * 1024 * 1024,
  );
  final Map<String, Future<Uint8List>> _pendingDownloads = {};

  Future<Map<String, dynamic>> attach({
    required String examId,
    required ExamMediaInput media,
  }) async {
    final prepared = await prepareAsset(media);
    final asset = prepared.asset;
    try {
      final relation = {
        'exam_id': examId,
        'asset_id': asset['id'],
        'question_position': media.questionPosition,
        'role': 'question_figure',
        'alt_text': media.altText,
      };
      try {
        final result = await _client
            .from('exam_media')
            .upsert(relation)
            .select('question_id')
            .single();
        asset['question_id'] = result['question_id'];
      } on PostgrestException catch (error) {
        if (error.code != '42703' && error.code != 'PGRST204') rethrow;
        await _client.from('exam_media').upsert(relation);
      }
    } catch (_) {
      await discardIfUnattached(prepared);
      rethrow;
    }
    return asset;
  }

  Future<PreparedExamMediaAsset> prepareAsset(ExamMediaInput media) async {
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
    var created = false;
    if (existing != null) {
      asset = Map<String, dynamic>.from(existing);
    } else {
      final objectKey = '${user.id}/media/$hash.$extension';
      try {
        await _client.storage
            .from(bucket)
            .uploadBinary(
              objectKey,
              media.bytes,
              fileOptions: FileOptions(
                contentType: media.mimeType,
                upsert: false,
              ),
            );
      } catch (_) {
        // Another session may have uploaded the same content-addressed asset.
        for (var attempt = 0; attempt < 3; attempt++) {
          await Future<void>.delayed(
            Duration(milliseconds: 100 * (attempt + 1)),
          );
          final raced = await _client
              .from('media_assets')
              .select()
              .eq('owner_id', user.id)
              .eq('sha256', hash)
              .maybeSingle();
          if (raced != null) {
            return PreparedExamMediaAsset(
              asset: Map<String, dynamic>.from(raced),
              created: false,
            );
          }
        }
        rethrow;
      }
      try {
        asset = await _client
            .from('media_assets')
            .insert({
              'owner_id': user.id,
              'object_key': objectKey,
              'sha256': hash,
              'mime_type': media.mimeType,
              'byte_size': media.bytes.length,
              'width': media.width,
              'height': media.height,
            })
            .select()
            .single();
        created = true;
      } catch (_) {
        // A concurrent import may have created the same owner/hash row.
        final raced = await _client
            .from('media_assets')
            .select()
            .eq('owner_id', user.id)
            .eq('sha256', hash)
            .maybeSingle();
        if (raced != null) {
          asset = Map<String, dynamic>.from(raced);
        } else {
          await _client.storage.from(bucket).remove([objectKey]);
          rethrow;
        }
      }
    }
    return PreparedExamMediaAsset(asset: asset, created: created);
  }

  Future<void> discardIfUnattached(PreparedExamMediaAsset prepared) async {
    if (!prepared.created) return;
    final user = _client.auth.currentUser;
    if (user == null) return;
    final id = prepared.asset['id'] as String;
    final objectKey = prepared.asset['object_key'] as String;
    final deleted = await _client
        .from('media_assets')
        .delete()
        .eq('id', id)
        .eq('owner_id', user.id)
        .select('id');
    if (deleted.isNotEmpty) {
      await _client.storage.from(bucket).remove([objectKey]);
    }
  }

  Future<Uint8List> download(Map<String, dynamic> asset) async {
    final id = asset['id'] as String;
    final cached = _memoryCache[id];
    if (cached != null) return cached;
    final existing = _pendingDownloads[id];
    if (existing != null) return existing;
    final pending = _downloadAndCache(id, asset);
    _pendingDownloads[id] = pending;
    try {
      return await pending;
    } finally {
      if (identical(_pendingDownloads[id], pending)) {
        _pendingDownloads.remove(id);
      }
    }
  }

  Future<Uint8List> _downloadAndCache(
    String id,
    Map<String, dynamic> asset,
  ) async {
    final bytes = await _client.storage
        .from(bucket)
        .download(asset['object_key'] as String);
    final expectedHash = asset['sha256'];
    if (expectedHash is String &&
        sha256.convert(bytes).toString() != expectedHash) {
      throw const FormatException(
        'A imagem baixada não passou na verificação de integridade.',
      );
    }
    _memoryCache[id] = bytes;
    return bytes;
  }
}

/// LRU cache with a hard byte budget so opening many exam figures cannot grow
/// the process heap without bound. Assets larger than the budget are returned
/// to the caller but are not retained.
class MediaByteCache {
  MediaByteCache({required this.maxBytes}) : assert(maxBytes > 0);

  final int maxBytes;
  final LinkedHashMap<String, Uint8List> _entries = LinkedHashMap();
  int _currentBytes = 0;

  int get currentBytes => _currentBytes;

  Uint8List? operator [](String id) {
    final bytes = _entries.remove(id);
    if (bytes == null) return null;
    _entries[id] = bytes;
    return bytes;
  }

  void operator []=(String id, Uint8List bytes) {
    final previous = _entries.remove(id);
    if (previous != null) _currentBytes -= previous.length;
    if (bytes.length > maxBytes) return;
    while (_currentBytes + bytes.length > maxBytes) {
      final oldestId = _entries.keys.first;
      _currentBytes -= _entries.remove(oldestId)!.length;
    }
    _entries[id] = bytes;
    _currentBytes += bytes.length;
  }
}
