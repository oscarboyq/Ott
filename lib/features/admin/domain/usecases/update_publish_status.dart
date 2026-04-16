import 'package:video/features/admin/domain/repositories/admin_video_repository.dart';

class UpdatePublishStatusUseCase {
  const UpdatePublishStatusUseCase(this._repository);

  final AdminVideoRepository _repository;

  Future<void> call({required String videoId, required bool isPublished}) {
    return _repository.updatePublishStatus(
      videoId: videoId,
      isPublished: isPublished,
    );
  }
}
