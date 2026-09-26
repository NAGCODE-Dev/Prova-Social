import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'content_package_service.dart';

class ContentDeliveryRepository {
  ContentDeliveryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const bucket = 'exam-content';
  final SupabaseClient _client;
  final Map<String, Uint8List> _memoryCache = {};

  Future<Map<String, dynamic>> uploadExamPackage({
    required String examId,
    required String fileName,
    required ContentPackage package,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) throw const AuthException('Faça login para publicar.');
    final objectKey =
        '${session.user.id}/exams/$examId/content/${package.sha256}.json.gz';

    await _client.storage
        .from(bucket)
        .uploadBinary(
          objectKey,
          package.bytes,
          fileOptions: const FileOptions(
            contentType: 'application/gzip',
            upsert: false,
          ),
        );

    try {
      return await _client
          .from('content_files')
          .insert({
            'owner_id': session.user.id,
            'exam_id': examId,
            'provider': 'supabase_storage',
            'object_key': objectKey,
            'original_name': fileName,
            'mime_type': 'application/json',
            'content_encoding': 'gzip',
            'sha256': package.sha256,
            'uncompressed_bytes': package.uncompressedBytes,
            'compressed_bytes': package.bytes.length,
            'status': 'ready',
          })
          .select()
          .single();
    } catch (_) {
      await _client.storage.from(bucket).remove([objectKey]);
      rethrow;
    }
  }

  Future<Uint8List> downloadPackage(String fileId) async {
    final cached = _memoryCache[fileId];
    if (cached != null) return cached;
    final metadata = await _client
        .from('content_files')
        .select('object_key')
        .eq('id', fileId)
        .eq('status', 'ready')
        .single();
    final bytes = await _client.storage
        .from(bucket)
        .download(metadata['object_key'] as String);
    _memoryCache[fileId] = bytes;
    return bytes;
  }
}
