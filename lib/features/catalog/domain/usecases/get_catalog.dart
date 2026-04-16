import 'package:video/features/catalog/domain/entities/video_item.dart';
import 'package:video/features/catalog/domain/repositories/video_repository.dart';

class GetCatalogUseCase {
  const GetCatalogUseCase(this._videoRepository);

  final VideoRepository _videoRepository;

  Future<List<VideoItem>> call() {
    return _videoRepository.getCatalog();
  }
}
