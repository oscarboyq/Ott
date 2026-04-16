import 'package:video/features/auth/domain/entities/app_session.dart';

abstract class AuthRepository {
  AppSession get currentSession;

  Stream<AppSession> watchSession();

  Future<void> signInDemoUser();

  Future<void> signOut();

  Future<void> updatePremiumAccess(bool isActive);
}
