class AppFailure {
  AppFailure({required this.message, this.code});

  final String message;
  final String? code;
}

AppFailure mapErrorToFailure(Object error) {
  final text = error.toString();
  if (text.contains('permission') || text.contains('PERMISSION_DENIED')) {
    return AppFailure(
      message: 'Недостаточно прав для действия.',
      code: 'permission_denied',
    );
  }
  if (text.contains('network') || text.contains('unavailable')) {
    return AppFailure(
      message: 'Проблема с сетью. Проверьте интернет и попробуйте снова.',
      code: 'network_error',
    );
  }
  return AppFailure(message: text.replaceFirst('Exception: ', ''));
}
