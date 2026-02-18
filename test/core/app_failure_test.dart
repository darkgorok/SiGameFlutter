import 'package:flutter_test/flutter_test.dart';
import 'package:si_game_flutter/core/errors/app_exception.dart';
import 'package:si_game_flutter/core/errors/app_failure.dart';

void main() {
  test('maps app exception permission-denied to permission_denied', () {
    final failure = mapErrorToFailure(
      const AppException(message: 'denied', code: 'permission-denied'),
    );
    expect(failure.code, 'permission_denied');
  });

  test('maps app exception unavailable to network_error', () {
    final failure = mapErrorToFailure(
      const AppException(message: 'offline', code: 'unavailable'),
    );
    expect(failure.code, 'network_error');
  });
}
