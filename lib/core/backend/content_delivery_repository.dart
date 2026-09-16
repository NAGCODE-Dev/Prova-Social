import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'content_package_service.dart';

class ContentDeliveryRepository {
  ContentDeliveryRepository({SupabaseClient? client, http.Client? httpClient})
      : _client = client ?? Supabase.instance.client,
        _http = httpClient ?? http.Client();

  static const signerUrl = String.fromEnvironment('R2_SIGNER_URL');
  final SupabaseClient _client;
  final http.Client _http;

  Future<Map<String, dynamic>> uploadExamPackage({
    required String examId,
    required String fileName,
    required ContentPackage package,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) throw const AuthException('Faça login para publicar.');
    if (signerUrl.isEmpty) {
      throw StateError('O endpoint privado do Cloudflare R2 ainda não foi configurado.');
    }

    final signResponse = await _http.post(
      Uri.parse(signerUrl),
      headers: {
        'authorization': 'Bearer ${session.accessToken}',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'examId': examId,
        'fileName': fileName,
        'sha256': package.sha256,
        'contentType': 'application/json',
        'contentEncoding': 'gzip',
        'contentLength': package.bytes.length,
      }),
    );
    if (signResponse.statusCode != 200) {
      throw StateError('Não foi possível preparar o envio do arquivo.');
    }

    final signed = Map<String, dynamic>.from(jsonDecode(signResponse.body) as Map);
    final uploadResponse = await _http.put(
      Uri.parse(signed['uploadUrl'] as String),
      headers: const {
        'content-type': 'application/json',
        'content-encoding': 'gzip',
      },
      body: package.bytes,
    );
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw StateError('O envio do arquivo não foi concluído.');
    }

    return await _client.from('content_files').insert({
      'owner_id': session.user.id,
      'exam_id': examId,
      'object_key': signed['objectKey'],
      'original_name': fileName,
      'mime_type': 'application/json',
      'content_encoding': 'gzip',
      'sha256': package.sha256,
      'uncompressed_bytes': package.uncompressedBytes,
      'compressed_bytes': package.bytes.length,
      'status': 'ready',
    }).select().single();
  }
}
