import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prova_social/core/backend/content_package_service.dart';
import 'package:prova_social/core/backend/digital_exam_service.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'downloads, decompresses and saves the exam plus its images offline',
    () async {
      const examId = 'exam-1';
      const questionId = 'question-1';
      const assetId = 'asset-1';
      final image = [0xff, 0xd8, 0xff, 0xd9];
      final imageHash = sha256.convert(image).toString();
      final packages = ContentPackageService();
      final questionsPackage = packages.create({
        'schemaVersion': 1,
        'examId': examId,
        'questions': [
          {
            'id': questionId,
            'position': 1,
            'topic': 'Geografia',
            'statement': 'Identifique a figura abaixo.',
            'options': ['Mapa A', 'Mapa B'],
          },
        ],
      });
      final manifestPackage = packages.create({
        'schemaVersion': 1,
        'examId': examId,
        'title': 'Prova compactada',
        'category': 'Conhecimentos gerais',
        'sourceName': 'Banca',
        'sourceType': 'official',
        'durationMinutes': 75,
        'media': [
          {
            'id': assetId,
            'questionId': questionId,
            'objectKey': 'owner/media/map.jpg',
            'sha256': imageHash,
            'mimeType': 'image/jpeg',
            'questionPosition': 1,
            'altText': 'Mapa da questão',
          },
        ],
      });
      final packagePayloads = {
        'manifest': manifestPackage,
        'questions': questionsPackage,
      };
      final requestLog = <String>[];
      final client = SupabaseClient(
        'https://example.test',
        'public-key',
        httpClient: MockClient((request) async {
          requestLog.add(request.url.path);
          if (request.url.path.endsWith('/rest/v1/content_files')) {
            final idFilter = request.url.queryParameters['id'];
            if (idFilter == null) {
              return http.Response(
                jsonEncode([
                  {'id': 'manifest', 'original_name': 'manifest.json.gz'},
                  {'id': 'questions', 'original_name': 'questions.json.gz'},
                ]),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            final id = idFilter.substring('eq.'.length);
            final package = packagePayloads[id]!;
            return http.Response(
              jsonEncode({
                'object_key': 'packages/$id.json.gz',
                'sha256': package.sha256,
                'compressed_bytes': package.bytes.length,
                'uncompressed_bytes': package.uncompressedBytes,
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          if (request.url.path.contains('/storage/v1/object/') &&
              request.url.path.endsWith('map.jpg')) {
            return http.Response.bytes(image, 200, request: request);
          }
          if (request.url.path.contains('/storage/v1/object/')) {
            final id = request.url.path.contains('/manifest.json.gz')
                ? 'manifest'
                : 'questions';
            return http.Response.bytes(
              packagePayloads[id]!.bytes,
              200,
              request: request,
            );
          }
          return http.Response('unexpected request', 500, request: request);
        }),
      );
      addTearDown(client.dispose);

      final downloaded = await DigitalExamService(client: client).download(
        const Exam(
          id: examId,
          title: 'Relational fallback',
          category: 'General',
          description: '',
          author: 'Banca antiga',
          durationMinutes: 60,
          attempts: 0,
          questions: [],
        ),
      );

      expect(downloaded.downloaded, isTrue);
      expect(downloaded.title, 'Prova compactada');
      expect(downloaded.durationMinutes, 75);
      expect(downloaded.exam.isLocal, isFalse);
      expect(downloaded.exam.questions.single.id, questionId);
      expect(downloaded.exam.questions.single.correctIndex, isNull);
      expect(downloaded.exam.questions.single.media.single.id, assetId);
      expect(downloaded.exam.questions.single.media.single.localBytes, image);
      expect(
        requestLog.where((path) => path.contains('/storage/v1/object/')),
        hasLength(3),
      );
    },
  );
}
