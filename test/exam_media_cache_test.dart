import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/backend/exam_media_repository.dart';

void main() {
  test('keeps recently used images and evicts least-recently-used bytes', () {
    final cache = MediaByteCache(maxBytes: 8);
    final first = Uint8List(3);
    final second = Uint8List(3);
    final third = Uint8List(4);

    cache['first'] = first;
    cache['second'] = second;
    expect(cache['first'], same(first));
    cache['third'] = third;

    expect(cache['second'], isNull);
    expect(cache['first'], same(first));
    expect(cache['third'], same(third));
    expect(cache.currentBytes, 7);
  });

  test('does not retain any image set larger than the cache budget', () {
    final cache = MediaByteCache(maxBytes: 8);
    final tooLarge = Uint8List(9);

    cache['large'] = tooLarge;

    expect(cache['large'], isNull);
    expect(cache.currentBytes, 0);
  });
}
