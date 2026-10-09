import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/navigation/share_link_service.dart';

void main() {
  const examId = '6a9212b2-9d58-83ea-aaf0-31857216bc8c';
  const questionId = '1a9212b2-9d58-83ea-aaf0-31857216bc8c';

  test('builds and parses exam and question URLs', () {
    final examUrl = ShareLinkService.exam(examId);
    final questionUrl = ShareLinkService.question(examId, questionId);

    expect(examUrl.toString(), 'https://prova-social.pages.dev/provas/$examId');
    expect(ShareLinkService.parse(examUrl.path)?.examId, examId);
    final question = ShareLinkService.parse(questionUrl.path)!;
    expect(question.examId, examId);
    expect(question.questionId, questionId);
  });

  test('rejects unknown routes and malformed identifiers', () {
    expect(ShareLinkService.parse('/outro/$examId'), isNull);
    expect(ShareLinkService.parse('/provas/../../secrets'), isNull);
  });
}
