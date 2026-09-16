import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/update/github_release_service.dart';

void main() {
  test('identifica uma versão mais recente', () {
    expect(GithubReleaseService.isNewer('0.2.1', '0.2.0'), isTrue);
    expect(GithubReleaseService.isNewer('1.0.0', '0.9.9'), isTrue);
    expect(GithubReleaseService.isNewer('0.2.0', '0.2.0'), isFalse);
    expect(GithubReleaseService.isNewer('0.1.9', '0.2.0'), isFalse);
  });
}
