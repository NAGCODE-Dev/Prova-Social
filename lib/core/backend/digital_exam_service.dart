import 'content_delivery_repository.dart';
import 'content_package_service.dart';
import 'exam_media_repository.dart';

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
    ContentPackageService? packages,
    ContentDeliveryRepository? content,
    ExamMediaRepository? media,
  }) : _packages = packages ?? ContentPackageService(),
       _content = content ?? ContentDeliveryRepository(),
       _media = media ?? ExamMediaRepository();

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
}
