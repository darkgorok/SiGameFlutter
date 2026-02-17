// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> pickAvatarBytesImpl() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;
  input.style.display = 'none';
  html.document.body?.append(input);

  final completer = Completer<Uint8List?>();

  void completeWith(Uint8List? bytes) {
    if (!completer.isCompleted) {
      completer.complete(bytes);
    }
  }

  void completeError(Object error) {
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
  }

  input.onChange.first
      .then((_) {
        final files = input.files;
        if (files == null || files.isEmpty) {
          completeWith(null);
          return;
        }
        final file = files.first;
        final reader = html.FileReader();
        reader.onError.first.then((_) {
          completeError(Exception('Не удалось прочитать файл'));
        });
        reader.onLoadEnd.first.then((_) {
          final result = reader.result;
          if (result is ByteBuffer) {
            completeWith(Uint8List.view(result));
          } else {
            completeError(Exception('Некорректный формат данных файла'));
          }
        });
        reader.readAsArrayBuffer(file);
      })
      .catchError((error) {
        completeError(error);
        return null;
      });

  input.click();
  return completer.future.whenComplete(() {
    input.remove();
  });
}
