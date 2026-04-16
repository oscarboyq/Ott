import 'dart:async';

import 'package:video/features/auth/domain/entities/app_session.dart';
import 'package:video/features/auth/domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  MockAuthRepository();

  final StreamController<AppSession> _sessionController =
      StreamController<AppSession>.broadcast();

  AppSession _currentSession = const AppSession.guest();

  @override
  AppSession get currentSession => _currentSession;

  @override
  Stream<AppSession> watchSession() async* {
    yield _currentSession;
    yield* _sessionController.stream;
  }

  @override
  Future<void> signInDemoUser() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _emit(
      const AppSession.authenticated(
        userId: 'demo-viewer',
        displayName: 'Demo Viewer',
      ),
    );
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _emit(const AppSession.guest());
  }

  @override
  Future<void> updatePremiumAccess(bool isActive) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (!_currentSession.isAuthenticated) {
      return;
    }

    _emit(_currentSession.copyWith(hasPremiumAccess: isActive));
  }

  void _emit(AppSession session) {
    _currentSession = session;
    _sessionController.add(_currentSession);
  }
}
