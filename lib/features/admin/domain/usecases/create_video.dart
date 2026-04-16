import 'package:video/features/admin/domain/entities/admin_video_draft.dart';
import 'package:video/features/admin/domain/repositories/admin_video_repository.dart';

class CreateVideoUseCase {
  const CreateVideoUseCase(this._repository);

  final AdminVideoRepository _repository;

  Future<void> call(AdminVideoDraft draft) {
    return _repository.createVideo(draft);
  }
}
