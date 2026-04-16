import 'package:video/features/admin/domain/repositories/admin_video_repository.dart';

class UpdateFeaturedStatusUseCase {
  const UpdateFeaturedStatusUseCase(this._repository);

  final AdminVideoRepository _repository;

  Future<void> call({required String videoId, required bool isFeatured}) {
    return _repository.updateFeaturedStatus(
      videoId: videoId,
      isFeatured: isFeatured,
    );
  }
}
