import 'package:video/features/catalog/domain/entities/video_item.dart';

abstract class VideoRepository {
  Future<List<VideoItem>> getCatalog();
}
