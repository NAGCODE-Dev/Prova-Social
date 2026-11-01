import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.name,
    required this.notes,
    required this.downloadUrl,
    required this.releaseUrl,
  });

  final String version;
  final String name;
  final String notes;
  final Uri downloadUrl;
  final Uri releaseUrl;
}

class GithubReleaseService {
  const GithubReleaseService();

  static const _deviceChannel = MethodChannel(
    'dev.nagcode/prova_social/device',
  );

  static const _latestRelease =
      'https://api.github.com/repos/NAGCODE-Dev/Prova-Social/releases/latest';

  Future<ReleaseInfo?> findUpdate() async {
    final package = await PackageInfo.fromPlatform();
    final response = await http
        .get(
          Uri.parse(_latestRelease),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'User-Agent': 'Prova-Social-App',
          },
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String? ?? '').replaceFirst('v', '');
    if (tag.isEmpty || !isNewer(tag, package.version)) return null;

    final assets = (json['assets'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final abi = await _androidAbi();
    final apk = selectApkAsset(assets, abi: abi);

    final releaseUrl = Uri.tryParse(json['html_url'] as String? ?? '');
    final downloadUrl = Uri.tryParse(
      apk?['browser_download_url'] as String? ?? '',
    );
    if (releaseUrl == null) return null;

    return ReleaseInfo(
      version: tag,
      name: json['name'] as String? ?? 'Prova Social $tag',
      notes: json['body'] as String? ?? '',
      downloadUrl: downloadUrl ?? releaseUrl,
      releaseUrl: releaseUrl,
    );
  }

  Future<String?> _androidAbi() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _deviceChannel.invokeMethod<String>('androidAbi');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Prefer the device-specific split; retain the universal APK as a safe
  /// fallback for old releases and unsupported Android ABIs.
  static Map<String, dynamic>? selectApkAsset(
    List<Map<String, dynamic>> assets, {
    required String? abi,
  }) {
    if (abi != null &&
        const {'arm64-v8a', 'armeabi-v7a', 'x86_64'}.contains(abi)) {
      for (final asset in assets) {
        if (asset['name'] == 'app-$abi-release.apk') return asset;
      }
    }
    for (final asset in assets) {
      if (asset['name'] == 'prova-social-android.apk' ||
          asset['name'] == 'app-release.apk') {
        return asset;
      }
    }
    return null;
  }

  static bool isNewer(String available, String installed) {
    final remote = _numbers(available);
    final local = _numbers(installed);
    final length = remote.length > local.length ? remote.length : local.length;
    for (var index = 0; index < length; index++) {
      final remotePart = index < remote.length ? remote[index] : 0;
      final localPart = index < local.length ? local[index] : 0;
      if (remotePart != localPart) return remotePart > localPart;
    }
    return false;
  }

  static List<int> _numbers(String value) => value
      .split('+')
      .first
      .split('.')
      .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}
