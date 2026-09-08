import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';

Future<XFile?> pickVideoFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.video,
    allowMultiple: false,
    withData: false,
  );

  if (result == null || result.files.isEmpty) {
    return null;
  }

  final file = result.files.single;
  final path = file.path;
  if (path == null || path.isEmpty) {
    throw Exception('Selected video file has no valid filesystem path.');
  }

  return XFile(path, name: file.name, length: file.size);
}
