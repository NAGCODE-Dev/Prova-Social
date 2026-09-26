import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prova_social/core/backend/exam_repository.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:prova_social/features/search/search_page.dart';

Map<String, dynamic> row(String title) => {
  'id': 'exam-id',
  'title': title,
  'description': '',
  'category': 'Concurso municipal',
  'source_name': 'Instituição',
  'duration_minutes': 60,
  'attempts_count': 0,
};
Exam exam(String title) => ExamRepository.mapPublishedExam(row(title), []);
void main() {
  for (final field in ['title', 'category', 'source_name', 'topic']) {
    test('remote search matches $field and restricts public content', () async {
      final requests = <Uri>[];
      final client = SupabaseClient(
        'https://example.test',
        'public-key',
        httpClient: MockClient((request) async {
          requests.add(request.url);
          final params = request.url.queryParameters;
          if (params[field]?.startsWith('ilike.') == true) {
            return http.Response(
              jsonEncode(
                field == 'topic'
                    ? [
                        {'exams': row('Encontrada')},
                      ]
                    : [row('Encontrada')],
              ),
              200,
              request: request,
            );
          }
          return http.Response('[]', 200, request: request);
        }),
      );
      final result = await ExamRepository(client: client).search('municipal');
      expect(result.single.title, 'Encontrada');
      expect(
        requests
            .where((u) => u.path.endsWith('exams'))
            .every(
              (u) =>
                  u.queryParameters['status'] == 'eq.published' &&
                  u.queryParameters['is_public'] == 'eq.true',
            ),
        isTrue,
      );
      expect(
        requests.any((u) => u.queryParameters['topic'] == 'ilike.%municipal%'),
        isTrue,
      );
      await client.dispose();
    });
  }
  testWidgets(
    'debounce, loading, stale results, empty, error, retry and open',
    (tester) async {
      final requests = <String, Completer<List<Exam>>>{};
      Exam? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: SearchPage(
            search: (query) {
              final completer = Completer<List<Exam>>();
              requests[query] = completer;
              return completer.future;
            },
            onOpen: (value) => opened = value,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 100));
      expect(requests, isEmpty);
      await tester.enterText(find.byType(TextField), 'antiga');
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'nova');
      await tester.pump(const Duration(milliseconds: 350));
      requests['nova']!.complete([exam('Nova prova')]);
      await tester.pump();
      requests['antiga']!.complete([exam('Antiga prova')]);
      await tester.pump();
      expect(find.text('Antiga prova'), findsNothing);
      await tester.tap(find.text('Nova prova'));
      expect(opened?.title, 'Nova prova');
      await tester.enterText(find.byType(TextField), 'vazio');
      await tester.pump(const Duration(milliseconds: 350));
      requests['vazio']!.complete([]);
      await tester.pump();
      expect(find.text('Nenhum resultado encontrado.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'erro');
      await tester.pump(const Duration(milliseconds: 350));
      requests['erro']!.completeError(Exception('offline'));
      await tester.pump();
      expect(find.byTooltip('Tentar novamente'), findsOneWidget);
      await tester.tap(find.byTooltip('Tentar novamente'));
      await tester.pump(const Duration(milliseconds: 350));
      requests['erro']!.complete([]);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final width in [320.0, 1280.0]) {
    testWidgets('search fits $width with large text', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: SearchPage(search: (_) async => [], onOpen: (_) {}),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
