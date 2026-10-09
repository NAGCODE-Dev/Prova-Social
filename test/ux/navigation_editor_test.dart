import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prova_social/core/backend/local_exam_store.dart';
import 'package:prova_social/core/backend/local_exam_payload_store.dart';
import 'package:prova_social/core/theme/app_theme.dart';
import 'package:prova_social/core/backend/exam_publication_service.dart';
import 'package:prova_social/core/backend/attempt_repository.dart';
import 'package:prova_social/core/backend/attempt_submission.dart';
import 'package:prova_social/core/import/question_parser.dart';
import 'package:prova_social/features/home/home_page.dart';
import 'package:prova_social/features/auth/auth_page.dart';
import 'package:prova_social/features/publish/publish_page.dart';

final requests = <http.Request>[];
bool failCatalogRequest = false;

class FailingPayloadStore implements ExamPayloadStorage {
  String? current;
  String? backup;

  @override
  bool get fileBacked => true;

  @override
  Future<String?> read() async => current;
  @override
  Future<String?> readBackup() async => backup;
  @override
  Future<bool> migrate(String payload) async => false;
  @override
  Future<bool> write(String payload, {String? backupPayload}) async =>
      throw StateError('offline');
}

class PreferencesPayloadStore implements ExamPayloadStorage {
  @override
  bool get fileBacked => false;

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(LocalExamStore.key);
  @override
  Future<String?> readBackup() async => (await SharedPreferences.getInstance())
      .getString('${LocalExamStore.key}_backup');
  @override
  Future<bool> migrate(String payload) async => write(payload);
  @override
  Future<bool> write(String payload, {String? backupPayload}) async => false;
}

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

ImportReviewPage editor({
  String? localId,
  List<ImportedQuestion>? questions,
  int reviewIndex = 0,
}) => ImportReviewPage(
  title: 'Prova privada',
  category: 'Matemática',
  source: 'Criação própria',
  durationMinutes: 30,
  localId: localId,
  reviewIndex: reviewIndex,
  questions:
      questions ??
      [
        ImportedQuestion(
          statement: 'Quanto é dois mais dois?',
          options: ['Quatro', 'Cinco'],
          correctIndex: 0,
          confidence: 1,
        ),
      ],
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.test',
      publishableKey: 'public-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (failCatalogRequest && request.url.path.endsWith('/exams')) {
          throw http.ClientException(
            'Failed to fetch, uri=${request.url}',
            request.url,
          );
        }
        if (request.url.path.endsWith('/logout')) {
          return http.Response('{}', 200, request: request);
        }
        if (request.url.path.endsWith('/user')) {
          return http.Response(jsonEncode(user), 200, request: request);
        }
        if (request.url.path.contains('/rpc/')) {
          return http.Response(
            jsonEncode('published-exam-id'),
            200,
            request: request,
          );
        }
        return http.Response('[]', 200, request: request);
      }),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  setUp(() async {
    await Supabase.instance.client.auth.signOut();
    SharedPreferences.setMockInitialValues({});
    LocalExamStore.storageOverride = PreferencesPayloadStore();
    requests.clear();
    failCatalogRequest = false;
  });
  tearDownAll(() => Supabase.instance.dispose());

  testWidgets('editor offers exit using last saved version after save fails', (
    tester,
  ) async {
    final storage = FailingPayloadStore();
    storage.current = jsonEncode([
      LocalExam(
        id: 'local-exit-test',
        title: 'Prova privada',
        category: 'Matemática',
        source: 'Criação própria',
        durationMinutes: 30,
        questions: editor().questions,
      ).toJson(),
    ]);
    LocalExamStore.storageOverride = storage;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => editor(localId: 'local-exit-test'),
                ),
              ),
              child: const Text('Abrir editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir editor'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível salvar'), findsOneWidget);
    await tester.tap(find.text('Sair com a última versão salva'));
    await tester.pumpAndSettle();
    expect(find.text('Editar e revisar prova'), findsNothing);
  });
  testWidgets(
    '200-question review builds one question and restores its cursor',
    (tester) async {
      final questions = List.generate(
        200,
        (index) => ImportedQuestion(
          statement: 'Enunciado da questão ${index + 1}?',
          options: const ['Primeira', 'Segunda'],
          confidence: .80,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: editor(questions: questions),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Questão 1 de 200'), findsOneWidget);
      final editorScroll = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Enunciado'),
        300,
        scrollable: editorScroll,
      );
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Questão 200'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Marcar questão como revisada'),
        300,
        scrollable: editorScroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar questão como revisada'));
      await tester.pumpAndSettle();

      await tester.drag(editorScroll, const Offset(0, 600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ir para questão'));
      await tester.pumpAndSettle();
      final target = find.text('200 ○');
      await tester.scrollUntilVisible(
        target,
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Questão 200 de 200'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      final restored = (await LocalExamStore().load()).single;
      expect(restored.reviewIndex, 199);
      expect(
        restored.questions.first.reviewState,
        QuestionReviewState.reviewed,
      );
      expect(restored.questions.last.reviewState, QuestionReviewState.inReview);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('visitor can open a truthful profile without signing in', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const HomePage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Abrir perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Você está explorando sem conta'), findsOneWidget);
    expect(find.byType(AuthPage), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('catalog network failure shows a friendly retry message', (
    tester,
  ) async {
    failCatalogRequest = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const HomePage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Verifique sua conexão e tente carregar novamente.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('https://example.test/rest/v1/exams'),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
  });
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
      await tester.tap(find.byTooltip('Abrir perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Você está explorando sem conta'), findsOneWidget);
      expect(find.byType(AuthPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Entrar ou criar conta'));
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await login();
      });
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsNothing);
      expect(find.text('Pessoa Teste'), findsWidgets);
      await tester.tap(find.byTooltip('Abrir perfil'));
      await tester.pumpAndSettle();
      final profileException = tester.takeException();
      expect(profileException, isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('desktop navigation respects dark theme surfaces', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const HomePage()),
    );
    await tester.pumpAndSettle();

    final sidebar = tester.widget<Container>(
      find.byKey(const ValueKey('desktop-sidebar')),
    );
    final decoration = sidebar.decoration! as BoxDecoration;
    expect(decoration.color, AppTheme.dark.colorScheme.surface);
    expect(decoration.border, isA<Border>());
    expect(
      (decoration.border! as Border).right.color,
      AppTheme.dark.colorScheme.outline,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
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
      final publishButton = find.text('Publicar para todos — requer conta');
      await tester.scrollUntilVisible(
        publishButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(publishButton);
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
  testWidgets('publication waits for human confirmation below 99%', (
    tester,
  ) async {
    final question = ImportedQuestion(
      statement: 'Questão com confiança intermediária?',
      options: const ['Sim', 'Não'],
      correctIndex: 0,
      confidence: .80,
    );
    await tester.pumpWidget(MaterialApp(home: editor(questions: [question])));
    await tester.pumpAndSettle();

    final publishButton = find.text('Publicar para todos — requer conta');
    await tester.scrollUntilVisible(
      publishButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(publishButton);
    await tester.pumpAndSettle();
    await tester.tap(publishButton);
    await tester.pumpAndSettle();

    expect(find.byType(AuthPage), findsNothing);
    expect(find.text('Publicar para todos?'), findsNothing);
    expect(requests.where((request) => request.method == 'POST'), isEmpty);
    expect(
      (await LocalExamStore().load()).single.questions.single.reviewState,
      QuestionReviewState.inReview,
    );
    await tester.pumpWidget(const SizedBox());
  });
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
  test('publication validates forged answer indices before RPC', () async {
    await login();
    final invalidQuestion = ImportedQuestion(
      statement: 'Enunciado válido?',
      options: const ['Primeira', 'Segunda'],
      correctIndex: 2,
    );
    await expectLater(
      ExamPublicationService().publish(
        title: 'Prova válida',
        category: 'Matéria',
        source: 'Origem',
        durationMinutes: 30,
        questions: [invalidQuestion],
      ),
      throwsFormatException,
    );
    await expectLater(
      ExamPublicationService().publish(
        title: 'x',
        category: 'Matéria',
        source: 'Origem',
        durationMinutes: 30,
        questions: editor().questions,
      ),
      throwsFormatException,
    );
    expect(
      requests.where((request) => request.url.path.contains('/rpc/')),
      isEmpty,
    );
  });
  test('publication preserves an optional HTTPS source URL', () async {
    await login();
    await expectLater(
      ExamPublicationService().publish(
        title: 'Prova válida',
        category: 'Matéria',
        source: 'Instituição',
        sourceUrl: 'http://example.org/prova',
        durationMinutes: 30,
        questions: editor().questions,
      ),
      throwsFormatException,
    );
    expect(
      requests.where((request) => request.url.path.contains('/rpc/')),
      isEmpty,
    );

    final examId = await ExamPublicationService().publish(
      title: 'Prova válida',
      category: 'Matéria',
      source: 'Instituição',
      sourceUrl: '  https://example.org/prova/2026  ',
      durationMinutes: 30,
      questions: editor().questions,
    );
    expect(examId, 'published-exam-id');
    final request = requests.singleWhere(
      (request) =>
          request.url.path.endsWith('/rpc/publish_exam_with_source_url'),
    );
    expect(
      jsonDecode(request.body)['p_source_url'],
      'https://example.org/prova/2026',
    );
  });
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
      final createManually = find.text('Criar manualmente');
      await tester.scrollUntilVisible(
        createManually,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(createManually);
      await tester.pumpAndSettle();
      final titleField = find.widgetWithText(TextField, 'Título');
      await tester.ensureVisible(titleField);
      await tester.pumpAndSettle();
      await tester.enterText(titleField, 'Minha criação');
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
