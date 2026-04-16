import 'package:file_picker/file_picker.dart';
import 'package:video/core/utils/picked_image_file.dart';

Future<PickedImageFile?> pickImageFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: true,
  );

  if (result == null || result.files.isEmpty) {
    return null;
  }

  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) {
    throw Exception('Could not read image bytes from the selected file.');
  }

  return PickedImageFile(name: file.name, bytes: bytes);
}
