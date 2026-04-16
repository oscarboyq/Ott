import 'package:video/features/admin/domain/repositories/admin_video_repository.dart';
import 'package:video/features/catalog/domain/entities/video_item.dart';

class GetAdminCatalogUseCase {
  const GetAdminCatalogUseCase(this._repository);

  final AdminVideoRepository _repository;

  Future<List<VideoItem>> call() {
    return _repository.getAdminCatalog();
  }
}
