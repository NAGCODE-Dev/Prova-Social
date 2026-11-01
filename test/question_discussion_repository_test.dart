import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prova_social/core/backend/question_discussion_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'loads only visible question comments with public display names',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.test',
        'public-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode([
              {
                'id': 'comment-1',
                'body': 'Explicação da alternativa.',
                'created_at': '2026-10-31T12:00:00Z',
                'profiles': {'display_name': 'Ana'},
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);

      final comments = await QuestionDiscussionRepository(client: client)
          .comments('question-1');

      expect(comments.single.authorName, 'Ana');
      expect(comments.single.body, 'Explicação da alternativa.');
      expect(
        requests.single.url.queryParameters['question_id'],
        'eq.question-1',
      );
      expect(requests.single.url.queryParameters['status'], 'eq.visible');
      expect(requests.single.url.queryParameters['limit'], '100');
    },
  );

  test(
    'preserves RLS owner identity and trims validated comment text',
    () async {
      http.Request? inserted;
      final client = SupabaseClient(
        'https://example.test',
        'public-key',
        httpClient: MockClient((request) async {
          inserted = request;
          return http.Response('', 201, request: request);
        }),
      );
      addTearDown(client.dispose);

      await QuestionDiscussionRepository(
        client: client,
        currentUserId: () => 'authenticated-user',
      ).addComment('question-1', '  Comentário útil  ');

      expect(inserted?.method, 'POST');
      expect(jsonDecode(inserted!.body) as Map<String, dynamic>, {
        'question_id': 'question-1',
        'author_id': 'authenticated-user',
        'body': 'Comentário útil',
        'status': 'visible',
      });
    },
  );

  test('rejects visitors and does not create missing topics', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.test',
      'public-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('[]', 200, request: request);
      }),
    );
    addTearDown(client.dispose);
    final repository = QuestionDiscussionRepository(
      client: client,
      currentUserId: () => null,
    );

    await expectLater(
      repository.addComment('question-1', 'Texto preservado'),
      throwsA(isA<AuthException>()),
    );
    expect(await repository.topicFollow('Assunto sem cadastro'), isNull);
    expect(requests, hasLength(1));
    expect(requests.single.url.path, contains('/topics'));
  });
}
