import 'package:video/features/auth/domain/entities/app_session.dart';
import 'package:video/features/auth/domain/repositories/auth_repository.dart';

class WatchSessionUseCase {
  const WatchSessionUseCase(this._authRepository);

  final AuthRepository _authRepository;

  Stream<AppSession> call() {
    return _authRepository.watchSession();
  }
}
