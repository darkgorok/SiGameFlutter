class AppFailure {
  AppFailure({required this.message, this.code});

  final String message;
  final String? code;
}

AppFailure mapErrorToFailure(Object error) {
  final text = error.toString();
  if (text.contains('permission') || text.contains('PERMISSION_DENIED')) {
    return AppFailure(message: text, code: 'permission_denied');
  }
  if (text.contains('network') || text.contains('unavailable')) {
    return AppFailure(message: text, code: 'network_error');
  }
  return AppFailure(message: text.replaceFirst('Exception: ', ''));
}
