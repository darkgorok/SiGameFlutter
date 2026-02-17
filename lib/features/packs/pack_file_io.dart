import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

Future<String?> pickPackJsonTextImpl() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['json'],
    allowMultiple: false,
    withData: true,
  );
  final bytes = result?.files.single.bytes;
  if (bytes == null || bytes.isEmpty) {
    return null;
  }
  return utf8.decode(bytes, allowMalformed: true);
}

Future<bool> savePackJsonTextImpl({
  required String suggestedFileName,
  required String content,
}) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Сохранить пак',
    fileName: suggestedFileName,
    type: FileType.custom,
    allowedExtensions: const ['json'],
    bytes: utf8.encode(content),
  );
  if (path == null || path.isEmpty) {
    return false;
  }
  await File(path).writeAsString(content);
  return true;
}
