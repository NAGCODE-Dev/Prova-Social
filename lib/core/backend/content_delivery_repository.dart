import 'dart:collection';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'content_package_service.dart';

class ContentDeliveryRepository {
  ContentDeliveryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const bucket = 'exam-content';
  static const _maxCacheBytes = 16 * 1024 * 1024;
  static const _maxPackageBytes = 25 * 1024 * 1024;
  static const _maxUncompressedBytes = 16 * 1024 * 1024;
  final SupabaseClient _client;
  final LinkedHashMap<String, Uint8List> _memoryCache = LinkedHashMap();
  final Map<String, Future<Uint8List>> _pendingDownloads = {};
  int _cachedBytes = 0;

  Future<Map<String, dynamic>> uploadExamPackage({
    required String examId,
    required String fileName,
    required ContentPackage package,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) throw const AuthException('Faça login para publicar.');
    if (package.bytes.isEmpty ||
        package.bytes.length > _maxPackageBytes ||
        package.uncompressedBytes < 1 ||
        package.uncompressedBytes > _maxUncompressedBytes) {
      throw const FormatException(
        'Pacote de prova excede os limites permitidos.',
      );
    }
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
    final cached = _memoryCache.remove(fileId);
    if (cached != null) {
      _memoryCache[fileId] = cached;
      return cached;
    }
    final pending = _pendingDownloads[fileId];
    if (pending != null) return pending;
    final future = _downloadAndCache(fileId);
    _pendingDownloads[fileId] = future;
    try {
      return await future;
    } finally {
      if (identical(_pendingDownloads[fileId], future)) {
        _pendingDownloads.remove(fileId);
      }
    }
  }

  Future<List<Map<String, dynamic>>> readyPackagesForExam(
    String examId,
  ) async => List<Map<String, dynamic>>.from(
    await _client
        .from('content_files')
        .select('id,original_name,created_at')
        .eq('exam_id', examId)
        .eq('status', 'ready')
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 15)),
  );

  Future<Uint8List> _downloadAndCache(String fileId) async {
    final metadata = await _client
        .from('content_files')
        .select('object_key,sha256,compressed_bytes,uncompressed_bytes')
        .eq('id', fileId)
        .eq('status', 'ready')
        .single();
    final expectedSize = (metadata['compressed_bytes'] as num?)?.toInt();
    final expectedUncompressed = (metadata['uncompressed_bytes'] as num?)
        ?.toInt();
    if (expectedSize == null ||
        expectedSize < 1 ||
        expectedSize > _maxPackageBytes ||
        expectedUncompressed == null ||
        expectedUncompressed < 1 ||
        expectedUncompressed > _maxUncompressedBytes) {
      throw const FormatException('Pacote de prova excede o limite permitido.');
    }
    final bytes = await _client.storage
        .from(bucket)
        .download(metadata['object_key'] as String);
    if (bytes.length != expectedSize ||
        sha256.convert(bytes).toString() != metadata['sha256']) {
      throw const FormatException(
        'O pacote baixado não passou na verificação de integridade.',
      );
    }
    if (bytes.length <= _maxCacheBytes) {
      while (_cachedBytes + bytes.length > _maxCacheBytes) {
        final oldest = _memoryCache.keys.first;
        _cachedBytes -= _memoryCache.remove(oldest)!.length;
      }
      _memoryCache[fileId] = bytes;
      _cachedBytes += bytes.length;
    }
    return bytes;
  }
}
