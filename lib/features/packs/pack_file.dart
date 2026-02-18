import 'pack_file_stub.dart'
    if (dart.library.html) 'pack_file_web.dart'
    if (dart.library.io) 'pack_file_io.dart';
import '../game/game_models.dart';

class PickedMediaFile {
  const PickedMediaFile({
    required this.fileName,
    required this.dataUrl,
    required this.mediaType,
  });

  final String fileName;
  final String dataUrl;
  final QuestionMediaType mediaType;
}

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

Future<PickedMediaFile?> pickQuestionMediaFile() => pickQuestionMediaFileImpl();
