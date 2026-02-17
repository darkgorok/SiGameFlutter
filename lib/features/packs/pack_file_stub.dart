Future<String?> pickPackJsonTextImpl() async {
  throw UnsupportedError('Pack file import is not supported on this platform');
}

Future<bool> savePackJsonTextImpl({
  required String suggestedFileName,
  required String content,
}) async {
  throw UnsupportedError('Pack file export is not supported on this platform');
}
