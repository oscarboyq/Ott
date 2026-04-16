import 'package:video/features/catalog/data/datasources/video_data_source.dart';
import 'package:video/features/catalog/domain/entities/video_item.dart';
import 'package:video/features/catalog/domain/repositories/video_repository.dart';

class MockVideoRepository implements VideoRepository {
  const MockVideoRepository(this._videoDataSource);

  final VideoDataSource _videoDataSource;

  @override
  Future<List<VideoItem>> getCatalog() async {
    final models = await _videoDataSource.getCatalog();
    return models.map((model) => model.toEntity()).toList(growable: false);
  }
}
