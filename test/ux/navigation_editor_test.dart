import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prova_social/core/backend/local_exam_store.dart';
import 'package:prova_social/core/theme/app_theme.dart';
import 'package:prova_social/core/backend/exam_publication_service.dart';
import 'package:prova_social/core/backend/attempt_repository.dart';
import 'package:prova_social/core/backend/attempt_submission.dart';
import 'package:prova_social/core/import/question_parser.dart';
import 'package:prova_social/features/home/home_page.dart';
import 'package:prova_social/features/auth/auth_page.dart';
import 'package:prova_social/features/publish/publish_page.dart';

final requests = <http.Request>[];
final user = {
  'id': '00000000-0000-4000-8000-000000000001',
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': 'test@example.test',
  'created_at': '2026-01-01T00:00:00Z',
  'app_metadata': <String, dynamic>{},
  'user_metadata': {'display_name': 'Pessoa Teste'},
};
Future<void> login() async {
  await Supabase.instance.client.auth.recoverSession(
    jsonEncode({
      'access_token': 'test-token',
      'refresh_token': 'test-refresh',
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
      'user': user,
    }),
  );
}

ImportReviewPage editor() => ImportReviewPage(
  title: 'Prova privada',
  category: 'Matemática',
  source: 'Criação própria',
  durationMinutes: 30,
  questions: [
    ImportedQuestion(
      statement: 'Quanto é dois mais dois?',
      options: ['Quatro', 'Cinco'],
      correctIndex: 0,
    ),
  ],
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.test',
      anonKey: 'public-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/logout')) {
          return http.Response('{}', 200);
        }
        if (request.url.path.endsWith('/user')) {
          return http.Response(jsonEncode(user), 200);
        }
        return http.Response('[]', 200);
      }),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  setUp(() async {
    await Supabase.instance.client.auth.signOut();
    SharedPreferences.setMockInitialValues({});
    requests.clear();
  });
  tearDownAll(() => Supabase.instance.dispose());
  for (final width in [320.0, 1280.0]) {
    testWidgets('avatar guest and signed-in, layout $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const HomePage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Entrar na conta'));
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsOneWidget);
      await tester.runAsync(() async {
        await login();
      });
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsNothing);
      expect(find.text('Pessoa Teste'), findsWidgets);
      await tester.tap(find.byTooltip('Abrir perfil'));
      await tester.pumpAndSettle();
      final profileException = tester.takeException();
      if (profileException != null) {
        debugPrint('===== PROFILE EXCEPTION START =====');
        debugPrint(profileException.toString());
        if (profileException is FlutterError) {
          debugPrint(profileException.toStringDeep());
        }
        debugPrint('===== PROFILE EXCEPTION END =====');
      }
      expect(profileException, isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('desktop menu closes on Escape, outside click and selection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const HomePage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    expect(find.text('Ajuda / sobre'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Ajuda / sobre'), findsNothing);
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(600, 100));
    await tester.pumpAndSettle();
    expect(find.text('Ajuda / sobre'), findsNothing);
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajuda / sobre'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutDialog), findsOneWidget);
    expect(find.text('Ajuda / sobre'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'guest creates, persists, restores and login preserves private publication',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: editor()));
      await tester.pumpAndSettle();
      expect((await LocalExamStore().load()).single.title, 'Prova privada');
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
      await tester.scrollUntilVisible(
        find.text('Publicar para todos — requer conta'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Publicar para todos — requer conta'));
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsOneWidget);
      expect((await LocalExamStore().load()).single.pendingPublication, isTrue);
      await tester.runAsync(() async {
        await login();
      });
      await tester.pumpAndSettle();
      expect(find.text('Publicar para todos?'), findsOneWidget);
      expect(
        (await LocalExamStore().load()).single.questions.single.statement,
        'Quanto é dois mais dois?',
      );
      expect(requests.where((r) => r.url.path.contains('/rpc/')), isEmpty);
      await tester.tap(find.text('Manter privada'));
      await tester.pumpAndSettle();
      expect(
        (await LocalExamStore().load()).single.pendingPublication,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const HomePage(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Biblioteca').last);
      await tester.pumpAndSettle();
      expect(find.text('Prova privada'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'OAuth reload restores pending draft but never publishes automatically',
    (tester) async {
      await LocalExamStore().save(
        LocalExam(
          id: 'local-reload',
          title: 'Recuperada',
          category: 'Matemática',
          source: 'Origem',
          durationMinutes: 30,
          questions: editor().questions,
          pendingPublication: true,
        ),
      );
      await login();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const HomePage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ImportReviewPage), findsOneWidget);
      expect(find.text('Publicar para todos?'), findsOneWidget);
      expect(requests.where((r) => r.url.path.contains('/rpc/')), isEmpty);
      await tester.tap(find.text('Manter privada'));
      await tester.pumpAndSettle();
      expect(
        (await LocalExamStore().load()).single.pendingPublication,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'public publication is rejected before any network request for guest',
    () async {
      await expectLater(
        ExamPublicationService().publish(
          title: 'Prova',
          category: 'Matéria',
          source: 'Origem',
          durationMinutes: 20,
          questions: editor().questions,
        ),
        throwsA(isA<AuthException>()),
      );
      expect(requests, isEmpty);
    },
  );
  test('local exam answers cannot be sent to backend', () async {
    final local = LocalExam(
      id: 'local-1',
      title: 'Privada',
      category: 'Matéria',
      source: 'Origem',
      durationMinutes: 20,
      questions: editor().questions,
    );
    await expectLater(
      AttemptRepository().submit(
        AttemptSubmission(
          clientAttemptId: 'id',
          exam: local.exam,
          answers: {0: 0},
          markedForReview: {},
          durationSeconds: 3,
          finishedAt: DateTime.now(),
        ),
      ),
      throwsStateError,
    );
    expect(requests, isEmpty);
  });
  for (final width in [320.0, 1280.0]) {
    testWidgets('manual editor works without account and fits $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: width == 320 ? AppTheme.light : AppTheme.dark,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: const PublishPage(),
          ),
        ),
      );
      await tester.tap(find.text('Criar manualmente'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Título'),
        'Minha criação',
      );
      await tester.scrollUntilVisible(
        find.text('Adicionar questão'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Adicionar questão'));
      await tester.pumpAndSettle();
      expect((await LocalExamStore().load()).single.questions.length, 1);
      expect(tester.takeException(), isNull);
      expect(requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
