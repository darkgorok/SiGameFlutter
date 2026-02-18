// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'package:file_picker/file_picker.dart';

import '../game/game_models.dart';
import 'pack_file.dart';

Future<String?> pickPackJsonTextImpl() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['blitz'],
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
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = suggestedFileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}

Future<PickedMediaFile?> pickQuestionMediaFileImpl() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.media,
    allowMultiple: false,
    withData: true,
  );
  final file = result?.files.single;
  final bytes = file?.bytes;
  if (file == null || bytes == null || bytes.isEmpty) {
    return null;
  }

  final fileName = file.name;
  final lower = fileName.toLowerCase();
  final mediaType =
      lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.gif') ||
          lower.endsWith('.webp') ||
          lower.endsWith('.bmp') ||
          lower.endsWith('.svg')
      ? QuestionMediaType.image
      : lower.endsWith('.mp3') ||
            lower.endsWith('.wav') ||
            lower.endsWith('.ogg') ||
            lower.endsWith('.m4a') ||
            lower.endsWith('.aac') ||
            lower.endsWith('.flac')
      ? QuestionMediaType.audio
      : QuestionMediaType.video;

  final ext = file.extension?.toLowerCase() ?? '';
  final mimeType = _mimeFromExtension(ext, mediaType);
  final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';

  return PickedMediaFile(
    fileName: fileName,
    dataUrl: dataUrl,
    mediaType: mediaType,
  );
}

String _mimeFromExtension(String extension, QuestionMediaType mediaType) {
  final ext = extension.toLowerCase();
  if (ext == 'png') return 'image/png';
  if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
  if (ext == 'gif') return 'image/gif';
  if (ext == 'webp') return 'image/webp';
  if (ext == 'bmp') return 'image/bmp';
  if (ext == 'svg') return 'image/svg+xml';
  if (ext == 'mp3') return 'audio/mpeg';
  if (ext == 'wav') return 'audio/wav';
  if (ext == 'ogg') return 'audio/ogg';
  if (ext == 'm4a') return 'audio/mp4';
  if (ext == 'aac') return 'audio/aac';
  if (ext == 'flac') return 'audio/flac';
  if (ext == 'mp4') return 'video/mp4';
  if (ext == 'webm') return 'video/webm';
  if (ext == 'mov') return 'video/quicktime';
  return mediaType == QuestionMediaType.image
      ? 'image/*'
      : mediaType == QuestionMediaType.audio
      ? 'audio/*'
      : 'video/*';
}
