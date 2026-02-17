import 'pack_file_stub.dart'
    if (dart.library.html) 'pack_file_web.dart'
    if (dart.library.io) 'pack_file_io.dart';

Future<String?> pickPackJsonText() => pickPackJsonTextImpl();

Future<bool> savePackJsonText({
  required String suggestedFileName,
  required String content,
}) {
  return savePackJsonTextImpl(
    suggestedFileName: suggestedFileName,
    content: content,
  );
}
