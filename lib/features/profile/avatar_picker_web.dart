import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<Uint8List?> pickAvatarBytesImpl() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: true,
  );
  return result?.files.single.bytes;
}
