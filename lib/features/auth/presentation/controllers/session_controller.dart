import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video/features/auth/domain/entities/app_session.dart';
import 'package:video/features/auth/domain/repositories/auth_repository.dart';
import 'package:video/features/auth/domain/usecases/sign_in_demo_user.dart';
import 'package:video/features/auth/domain/usecases/sign_out.dart';
import 'package:video/features/auth/domain/usecases/update_premium_access.dart';
import 'package:video/features/auth/domain/usecases/watch_session.dart';

class SessionController extends ChangeNotifier {
  SessionController({
    required AuthRepository authRepository,
    required WatchSessionUseCase watchSessionUseCase,
    required SignInDemoUserUseCase signInDemoUserUseCase,
    required SignOutUseCase signOutUseCase,
    required UpdatePremiumAccessUseCase updatePremiumAccessUseCase,
  }) : _session = authRepository.currentSession,
       _watchSessionUseCase = watchSessionUseCase,
       _signInDemoUserUseCase = signInDemoUserUseCase,
       _signOutUseCase = signOutUseCase,
       _updatePremiumAccessUseCase = updatePremiumAccessUseCase {
    _subscription = _watchSessionUseCase().listen((AppSession session) {
      _session = session;
      notifyListeners();
    });
  }

  final WatchSessionUseCase _watchSessionUseCase;
  final SignInDemoUserUseCase _signInDemoUserUseCase;
  final SignOutUseCase _signOutUseCase;
  final UpdatePremiumAccessUseCase _updatePremiumAccessUseCase;

  late final StreamSubscription<AppSession> _subscription;
  AppSession _session;
  bool _isBusy = false;

  AppSession get session => _session;

  bool get isBusy => _isBusy;

  Future<void> signInDemoUser() {
    return _run(_signInDemoUserUseCase.call);
  }

  Future<void> signOut() {
    return _run(_signOutUseCase.call);
  }

  Future<void> setPremiumAccess(bool isActive) {
    return _run(() => _updatePremiumAccessUseCase(isActive));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isBusy) {
      return;
    }

    _isBusy = true;
    notifyListeners();

    try {
      await action();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
