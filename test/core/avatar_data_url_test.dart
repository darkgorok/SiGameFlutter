import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:si_game_flutter/core/avatar_data_url.dart';

void main() {
  test('buildAvatarDataUrl returns empty string for null bytes', () {
    expect(buildAvatarDataUrl(null), isEmpty);
  });

  test('detectImageMime detects png signature', () {
    final bytes = Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0]);
    expect(detectImageMime(bytes), 'image/png');
  });
}
