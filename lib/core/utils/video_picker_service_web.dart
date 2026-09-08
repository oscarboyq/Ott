import 'dart:async';
import 'dart:html' as html;

import 'package:cross_file/cross_file.dart';

Future<XFile?> pickVideoFile() async {
  final input = html.FileUploadInputElement()
    ..accept = 'video/*,.mp4,.mov,.webm,.mkv,.avi';
  input.style.display = 'none';
  html.document.body?.children.add(input);

  final completer = Completer<XFile?>();
  bool completed = false;

  void finish(XFile? result) {
    if (!completed) {
      completed = true;
      input.remove();
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }
  }

  input.onChange.listen((_) {
    final files = input.files;
    if (files != null && files.isNotEmpty) {
      final file = files.first;
      final blobUrl = html.Url.createObjectUrlFromBlob(file);
      final xFile = XFile(
        blobUrl,
        name: file.name,
        length: file.size,
        mimeType: file.type.isNotEmpty ? file.type : 'video/mp4',
      );
      finish(xFile);
    } else {
      finish(null);
    }
  });

  input.addEventListener('cancel', (_) {
    Future.delayed(const Duration(milliseconds: 300), () => finish(null));
  });

  html.window.addEventListener('focus', (_) {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!completed && (input.files == null || input.files!.isEmpty)) {
        finish(null);
      }
    });
  });

  input.click();
  return completer.future;
}
