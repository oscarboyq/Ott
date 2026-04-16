import 'package:video/features/auth/domain/repositories/auth_repository.dart';

class SignInDemoUserUseCase {
  const SignInDemoUserUseCase(this._authRepository);

  final AuthRepository _authRepository;

  Future<void> call() {
    return _authRepository.signInDemoUser();
  }
}
