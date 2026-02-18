import 'app_exception.dart';

class AppFailure {
  AppFailure({required this.message, this.code});

  final String message;
  final String? code;
}

AppFailure mapErrorToFailure(Object error) {
  if (error is AppException) {
    final normalized = error.code?.replaceAll('-', '_');
    if (normalized == 'permission_denied') {
      return AppFailure(message: error.message, code: 'permission_denied');
    }
    if (normalized == 'unavailable' || normalized == 'network_error') {
      return AppFailure(message: error.message, code: 'network_error');
    }
    return AppFailure(message: error.message, code: normalized);
  }
  final text = error.toString();
  if (text.contains('permission') || text.contains('PERMISSION_DENIED')) {
    return AppFailure(message: text, code: 'permission_denied');
  }
  if (text.contains('network') || text.contains('unavailable')) {
    return AppFailure(message: text, code: 'network_error');
  }
  return AppFailure(message: text.replaceFirst('Exception: ', ''));
}
