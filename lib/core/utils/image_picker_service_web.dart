import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:video/core/utils/picked_image_file.dart';

Future<PickedImageFile?> pickImageFile() async {
  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.click();

  await input.onChange.first;

  final file = input.files?.isNotEmpty == true ? input.files!.first : null;
  if (file == null) {
    return null;
  }

  final reader = html.FileReader();
  final completer = Completer<Uint8List>();

  reader.onLoad.listen((_) {
    final result = reader.result;
    if (result is ByteBuffer) {
      completer.complete(Uint8List.view(result));
      return;
    }
    if (result is Uint8List) {
      completer.complete(result);
      return;
    }
    completer.completeError(Exception('Unsupported browser file result.'));
  });

  reader.onError.listen((_) {
    completer.completeError(Exception('Failed to read selected image file.'));
  });

  reader.readAsArrayBuffer(file);
  final bytes = await completer.future;
  return PickedImageFile(name: file.name, bytes: bytes);
}
