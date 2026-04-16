import 'package:video/features/auth/domain/repositories/auth_repository.dart';

class UpdatePremiumAccessUseCase {
  const UpdatePremiumAccessUseCase(this._authRepository);

  final AuthRepository _authRepository;

  Future<void> call(bool isActive) {
    return _authRepository.updatePremiumAccess(isActive);
  }
}
