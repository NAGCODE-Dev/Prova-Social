import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prova_social/core/backend/exam_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> examRow(String id, String createdAt) => {
  'id': id,
  'title': 'Exam $id',
  'description': '',
  'category': 'General',
  'source_name': 'Community',
  'source_type': 'community',
  'duration_minutes': 60,
  'attempts_count': 0,
  'created_at': createdAt,
  'questions': [
    {
      'id': 'question-$id',
      'exam_id': id,
      'position': 1,
      'topic': 'Math',
      'statement': 'A question with enough text?',
      'options': [
        {'text': 'First'},
        {'text': 'Second'},
      ],
    },
  ],
};

void main() {
  test('maps the submitting profile separately from the exam source', () {
    final exam = ExamRepository.mapPublishedExam({
      ...examRow('authored', '2026-09-29T10:00:00+00:00'),
      'profiles': {'display_name': 'Ana'},
    }, const []);

    expect(exam.author, 'Community');
    expect(exam.uploaderName, 'Ana');
  });

  test('maps question media to the stable question record', () {
    final exam = ExamRepository.mapPublishedExam(
      examRow('media', '2026-09-29T10:00:00+00:00'),
      [
        {
          ...examRow('media', '2026-09-29T10:00:00+00:00')['questions'][0]
              as Map<String, dynamic>,
          'exam_media': [
            {
              'question_id': 'question-media',
              'question_position': 1,
              'role': 'question_figure',
              'alt_text': 'Página original da questão',
              'media_assets': {
                'id': 'asset-1',
                'object_key': 'owner/media/hash.jpg',
                'mime_type': 'image/jpeg',
                'sha256': 'a' * 64,
              },
            },
          ],
        },
      ],
    );

    expect(exam.questions.single.id, 'question-media');
    expect(exam.questions.single.media.single.id, 'asset-1');
    expect(
      exam.questions.single.media.single.altText,
      'Página original da questão',
    );
  });

  test(
    'catalog pages are keyset-paginated and include questions in one query',
    () async {
      final requests = <Uri>[];
      final client = SupabaseClient(
        'https://example.test',
        'public-key',
        httpClient: MockClient((request) async {
          requests.add(request.url);
          final page = request.url.queryParameters.containsKey('or')
              ? [examRow('z', '2026-09-28T10:00:00+00:00')]
              : [
                  examRow('b', '2026-09-29T10:00:00+00:00'),
                  examRow('a', '2026-09-29T10:00:00+00:00'),
                ];
          return http.Response(
            jsonEncode(page),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = ExamRepository(client: client);

      final first = await repository.publishedExamPage(pageSize: 1);
      expect(first.exams.single.questions.single.id, 'question-b');
      expect(first.hasMore, isTrue);
      expect(first.nextCursor?.id, 'b');
      expect(requests, hasLength(1));
      expect(requests.single.queryParameters['status'], 'eq.published');
      expect(requests.single.queryParameters['is_public'], 'eq.true');
      expect(requests.single.queryParameters['select'], contains('questions('));
      expect(
        requests.single.queryParameters['select'],
        contains('profiles!exams_author_id_fkey(display_name)'),
      );
      expect(
        requests.single.queryParameters['questions.order'],
        'position.asc.nullslast',
      );

      final second = await repository.publishedExamPage(
        after: first.nextCursor,
        pageSize: 1,
      );
      expect(second.exams.single.id, 'z');
      expect(second.hasMore, isFalse);
      expect(requests, hasLength(2));
      expect(requests.last.queryParameters['or'], contains('created_at.lt.'));
      expect(requests.last.queryParameters['or'], contains('id.lt.b'));
      expect(
        requests.last.queryParameters['questions.order'],
        'position.asc.nullslast',
      );
    },
  );

  test('catalog rejects invalid page sizes before making a request', () async {
    var requested = false;
    final client = SupabaseClient(
      'https://example.test',
      'public-key',
      httpClient: MockClient((request) async {
        requested = true;
        return http.Response('[]', 200, request: request);
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      ExamRepository(client: client).publishedExamPage(pageSize: 0),
      throwsArgumentError,
    );
    expect(requested, isFalse);
  });
}
