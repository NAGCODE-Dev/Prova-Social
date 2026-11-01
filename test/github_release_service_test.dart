import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/update/github_release_service.dart';

void main() {
  test('identifica uma versão mais recente', () {
    expect(GithubReleaseService.isNewer('0.2.1', '0.2.0'), isTrue);
    expect(GithubReleaseService.isNewer('1.0.0', '0.9.9'), isTrue);
    expect(GithubReleaseService.isNewer('0.2.0', '0.2.0'), isFalse);
    expect(GithubReleaseService.isNewer('0.1.9', '0.2.0'), isFalse);
  });

  test('prefers the ABI-specific APK and falls back to the universal APK', () {
    final assets = [
      {'name': 'prova-social-android.apk', 'browser_download_url': 'universal'},
      {'name': 'app-arm64-v8a-release.apk', 'browser_download_url': 'arm64'},
      {'name': 'app-x86_64-release.apk', 'browser_download_url': 'x64'},
    ];

    expect(
      GithubReleaseService.selectApkAsset(
        assets,
        abi: 'arm64-v8a',
      )?['browser_download_url'],
      'arm64',
    );
    expect(
      GithubReleaseService.selectApkAsset(
        assets,
        abi: 'x86_64',
      )?['browser_download_url'],
      'x64',
    );
    expect(
      GithubReleaseService.selectApkAsset(
        assets,
        abi: 'unknown',
      )?['browser_download_url'],
      'universal',
    );
    expect(
      GithubReleaseService.selectApkAsset([
        {'name': 'app-arm64-v8a-release.apk'},
      ], abi: 'x86_64'),
      isNull,
    );
  });
}
