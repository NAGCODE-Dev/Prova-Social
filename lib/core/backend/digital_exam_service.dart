import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/exam.dart';
import '../import/imported_document.dart';
import '../import/question_parser.dart';
import 'content_delivery_repository.dart';
import 'content_package_service.dart';
import 'exam_media_repository.dart';
import 'local_exam_store.dart';

class DigitalExamUpload {
  const DigitalExamUpload({
    required this.manifestFile,
    required this.questionsFile,
    required this.mediaAssets,
  });

  final Map<String, dynamic> manifestFile;
  final Map<String, dynamic> questionsFile;
  final List<Map<String, dynamic>> mediaAssets;
}

class DigitalExamService {
  DigitalExamService({
    SupabaseClient? client,
    ContentPackageService? packages,
    ContentDeliveryRepository? content,
    ExamMediaRepository? media,
  }) : _packages = packages ?? ContentPackageService(),
       _content = content ?? ContentDeliveryRepository(client: client),
       _media = media ?? ExamMediaRepository(client: client);

  final ContentPackageService _packages;
  final ContentDeliveryRepository _content;
  final ExamMediaRepository _media;

  Future<DigitalExamUpload> upload({
    required String examId,
    required Map<String, Object?> manifest,
    required List<Map<String, Object?>> questions,
    List<ExamMediaInput> media = const [],
  }) async {
    final uploadedMedia = <Map<String, dynamic>>[];
    for (final item in media) {
      uploadedMedia.add(await _media.attach(examId: examId, media: item));
    }

    final mediaIndex = List.generate(uploadedMedia.length, (index) {
      final asset = uploadedMedia[index];
      final source = media[index];
      return {
        'id': asset['id'],
        'questionId': asset['question_id'],
        'objectKey': asset['object_key'],
        'sha256': asset['sha256'],
        'mimeType': asset['mime_type'],
        'width': asset['width'],
        'height': asset['height'],
        'questionPosition': source.questionPosition,
        'altText': source.altText,
      };
    }, growable: false);

    final questionsPayload = _packages.create({
      'schemaVersion': 1,
      'examId': examId,
      'questions': questions,
    });
    final questionsFile = await _content.uploadExamPackage(
      examId: examId,
      fileName: 'questions.json.gz',
      package: questionsPayload,
    );

    final manifestPayload = _packages.create({
      ...manifest,
      'schemaVersion': 1,
      'examId': examId,
      'questionsFileId': questionsFile['id'],
      'media': mediaIndex,
    });
    final manifestFile = await _content.uploadExamPackage(
      examId: examId,
      fileName: 'manifest.json.gz',
      package: manifestPayload,
    );

    return DigitalExamUpload(
      manifestFile: manifestFile,
      questionsFile: questionsFile,
      mediaAssets: uploadedMedia,
    );
  }

  /// Downloads and validates the compressed public package, then stores a
  /// self-contained offline copy. Relational rows remain the compatibility
  /// fallback for older seeded exams without packages.
  Future<LocalExam> download(Exam fallback) async {
    Map<String, dynamic>? manifest;
    List<Map<String, dynamic>> packageQuestions = const [];
    try {
      final files = await _content.readyPackagesForExam(fallback.id);
      final manifestFile = files
          .where((file) => file['original_name'] == 'manifest.json.gz')
          .firstOrNull;
      final latestQuestionsFile = files
          .where((file) => file['original_name'] == 'questions.json.gz')
          .firstOrNull;
      if (manifestFile != null && latestQuestionsFile != null) {
        final manifestPayload = _packages.open(
          await _content.downloadPackage(manifestFile['id'] as String),
          maxUncompressedBytes: 16 * 1024 * 1024,
        );
        final referencedQuestionsFileId = manifestPayload['questionsFileId'];
        final questionsFile = referencedQuestionsFileId is String
            ? files
                  .where((file) => file['id'] == referencedQuestionsFileId)
                  .firstOrNull
            : latestQuestionsFile;
        if (questionsFile == null ||
            questionsFile['original_name'] != 'questions.json.gz') {
          throw const FormatException(
            'Pacote de questões referenciado não existe.',
          );
        }
        final questionsPayload = _packages.open(
          await _content.downloadPackage(questionsFile['id'] as String),
          maxUncompressedBytes: 16 * 1024 * 1024,
        );
        if (manifestPayload['examId'] != fallback.id ||
            questionsPayload['examId'] != fallback.id ||
            manifestPayload['schemaVersion'] != 1 ||
            questionsPayload['schemaVersion'] != 1 ||
            questionsPayload['questions'] is! List) {
          throw const FormatException('Pacote pertence a outra prova.');
        }
        packageQuestions = List<Map<String, dynamic>>.from(
          (questionsPayload['questions'] as List).whereType<Map>(),
        );
        if (packageQuestions.isEmpty || packageQuestions.length > 300) {
          throw const FormatException(
            'Quantidade inválida de questões no pacote.',
          );
        }
        manifest = manifestPayload;
      }
    } catch (error) {
      // Keep older packages usable from the authoritative relational catalog.
      debugPrint(
        '[EXAM_DOWNLOAD] Pacote indisponível; usando catálogo: ${error.runtimeType}',
      );
      manifest = null;
      packageQuestions = const [];
    }

    final sourceQuestions = packageQuestions.isEmpty
        ? [
            for (var index = 0; index < fallback.questions.length; index++)
              {
                'id': fallback.questions[index].id,
                'position': index + 1,
                'topic': fallback.questions[index].topic,
                'statement': fallback.questions[index].statement,
                'options': fallback.questions[index].options,
              },
          ]
        : packageQuestions;
    if (sourceQuestions.isEmpty || sourceQuestions.length > 300) {
      throw const FormatException('Prova sem questões válidas para download.');
    }
    final importedQuestions = <ImportedQuestion>[];
    for (var index = 0; index < sourceQuestions.length; index++) {
      final row = sourceQuestions[index];
      final statement = row['statement'];
      final optionsRaw = row['options'];
      if (statement is! String ||
          statement.trim().length < 2 ||
          optionsRaw is! List) {
        throw const FormatException('Questão inválida no pacote.');
      }
      final options = optionsRaw
          .map(
            (option) => option is Map ? '${option['text'] ?? ''}' : '$option',
          )
          .toList(growable: false);
      if (options.length < 2 ||
          options.length > 8 ||
          options.any((v) => v.trim().isEmpty)) {
        throw const FormatException('Alternativas inválidas no pacote.');
      }
      importedQuestions.add(
        ImportedQuestion(
          id: row['id'] as String? ?? '${fallback.id}-${index + 1}',
          statement: statement,
          options: options,
          number: (row['position'] as num?)?.toInt() ?? index + 1,
          topic: row['topic'] as String? ?? 'Geral',
          confidence: 1,
          reviewState: QuestionReviewState.reviewed,
        ),
      );
    }

    final packageMedia = manifest?['media'] is List
        ? List<Map<String, dynamic>>.from(
            (manifest!['media'] as List).whereType<Map>(),
          )
        : <Map<String, dynamic>>[];
    final relationalMedia = [
      for (var index = 0; index < fallback.questions.length; index++)
        for (final asset in fallback.questions[index].media)
          {
            'id': asset.id,
            'objectKey': asset.objectKey,
            'sha256': asset.sha256,
            'mimeType': asset.mimeType,
            'questionId': fallback.questions[index].id,
            'questionPosition': index + 1,
            'altText': asset.altText,
          },
    ];
    final mediaEntries =
        packageMedia.isEmpty ||
            packageMedia.any((entry) => entry['objectKey'] is! String)
        ? relationalMedia
        : packageMedia;
    if (mediaEntries.length > 900) {
      throw const FormatException('Quantidade excessiva de imagens no pacote.');
    }
    final pages = <ImportedDocumentPage>[];
    var totalMediaBytes = 0;
    for (final entry in mediaEntries) {
      final position = (entry['questionPosition'] as num?)?.toInt();
      final questionId = entry['questionId'];
      final idIndex = questionId is String
          ? importedQuestions.indexWhere(
              (question) => question.id == questionId,
            )
          : -1;
      final positionIndex = position == null ? -1 : position - 1;
      if (questionId is String && idIndex < 0) {
        throw const FormatException(
          'A questão da imagem não existe no pacote.',
        );
      }
      if (idIndex >= 0 && positionIndex >= 0 && idIndex != positionIndex) {
        throw const FormatException('O ID e a posição da imagem divergem.');
      }
      final questionIndex = idIndex >= 0 ? idIndex : positionIndex;
      if (questionIndex < 0 || questionIndex >= importedQuestions.length) {
        throw const FormatException('Vínculo de imagem inválido no pacote.');
      }
      final assetId = entry['id'];
      final objectKey = entry['objectKey'];
      final hash = entry['sha256'];
      final mimeType = entry['mimeType'];
      if (assetId is! String ||
          objectKey is! String ||
          hash is! String ||
          mimeType is! String) {
        throw const FormatException('Referência de imagem inválida no pacote.');
      }
      final bytes = await _media.download({
        'id': assetId,
        'object_key': objectKey,
        'sha256': hash,
      });
      totalMediaBytes += bytes.length;
      if (totalMediaBytes > 12 * 1024 * 1024) {
        throw const FormatException('As imagens da prova excedem 12 MiB.');
      }
      final pageNumber = pages.length + 1;
      importedQuestions[questionIndex].sourcePages.add(pageNumber);
      pages.add(
        ImportedDocumentPage(
          number: pageNumber,
          text: '',
          source: 'downloaded-package',
          previewBytes: Uint8List.fromList(bytes),
          mediaAssetId: assetId,
          mediaObjectKey: objectKey,
          mediaMimeType: mimeType,
          mediaSha256: hash,
          mediaAltText: entry['altText'] as String? ?? '',
        ),
      );
    }
    final title = manifest?['title'] as String? ?? fallback.title;
    final category = manifest?['category'] as String? ?? fallback.category;
    final source = manifest?['sourceName'] as String? ?? fallback.author;
    return LocalExam(
      id: fallback.id,
      title: title,
      category: category,
      source: source,
      sourceUrl: manifest?['sourceUrl'] as String? ?? fallback.sourceUrl,
      durationMinutes:
          (manifest?['durationMinutes'] as num?)?.toInt() ??
          fallback.durationMinutes,
      year: (manifest?['year'] as num?)?.toInt(),
      downloaded: true,
      sourceType: ExamSourceType.fromDatabase(
        manifest?['sourceType'] ?? fallback.sourceType.name,
      ),
      questions: importedQuestions,
      importedDocument: ImportedDocument(
        metadata: {'examId': fallback.id, 'offlinePackage': true},
        pages: pages,
        questions: const [],
      ),
    );
  }
}
