import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

class ContentPackage {
  const ContentPackage({
    required this.bytes,
    required this.sha256,
    required this.uncompressedBytes,
  });

  final Uint8List bytes;
  final String sha256;
  final int uncompressedBytes;
}

class ContentPackageService {
  ContentPackage create(Map<String, Object?> payload) {
    final raw = utf8.encode(jsonEncode(payload));
    final compressed = Uint8List.fromList(GZipEncoder().encode(raw));
    return ContentPackage(
      bytes: compressed,
      sha256: sha256.convert(compressed).toString(),
      uncompressedBytes: raw.length,
    );
  }

  Map<String, dynamic> open(List<int> compressed) {
    final raw = GZipDecoder().decodeBytes(compressed);
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(raw)) as Map);
  }
}
