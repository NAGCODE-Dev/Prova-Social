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

  Map<String, dynamic> open(List<int> compressed, {int? maxUncompressedBytes}) {
    if (maxUncompressedBytes != null) {
      if (maxUncompressedBytes < 1 || compressed.length < 18) {
        throw const FormatException('Pacote comprimido inválido.');
      }
      final trailer = compressed.length - 4;
      final declaredSize =
          (compressed[trailer] |
              (compressed[trailer + 1] << 8) |
              (compressed[trailer + 2] << 16) |
              (compressed[trailer + 3] << 24)) >>>
          0;
      if (declaredSize > maxUncompressedBytes) {
        throw const FormatException('Conteúdo descompactado excede o limite.');
      }
    }
    final raw = GZipDecoder().decodeBytes(compressed, verify: true);
    if (maxUncompressedBytes != null && raw.length > maxUncompressedBytes) {
      throw const FormatException('Conteúdo descompactado excede o limite.');
    }
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(raw)) as Map);
  }
}
