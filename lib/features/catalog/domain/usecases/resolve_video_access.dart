import 'package:equatable/equatable.dart';
import 'package:video/features/auth/domain/entities/app_session.dart';
import 'package:video/features/catalog/domain/entities/video_item.dart';

enum VideoGateAction { watch, login, upgrade }

class VideoAccessDecision extends Equatable {
  const VideoAccessDecision._(this.action);

  const VideoAccessDecision.watch() : this._(VideoGateAction.watch);

  const VideoAccessDecision.login() : this._(VideoGateAction.login);

  const VideoAccessDecision.upgrade() : this._(VideoGateAction.upgrade);

  final VideoGateAction action;

  bool get canWatch => action == VideoGateAction.watch;

  bool get needsLogin => action == VideoGateAction.login;

  bool get needsUpgrade => action == VideoGateAction.upgrade;

  String get cardLabel {
    switch (action) {
      case VideoGateAction.watch:
        return 'Open details';
      case VideoGateAction.login:
        return 'Login required';
      case VideoGateAction.upgrade:
        return 'Premium only';
    }
  }

  String get primaryActionLabel {
    switch (action) {
      case VideoGateAction.watch:
        return 'Start streaming';
      case VideoGateAction.login:
        return 'Login as demo user';
      case VideoGateAction.upgrade:
        return 'Open premium plan';
    }
  }

  String get supportingMessage {
    switch (action) {
      case VideoGateAction.watch:
        return 'This viewer can stream the full video now.';
      case VideoGateAction.login:
        return 'Log in first to continue toward paid access.';
      case VideoGateAction.upgrade:
        return 'This title is reserved for premium members.';
    }
  }

  @override
  List<Object?> get props => <Object?>[action];
}

class ResolveVideoAccessUseCase {
  VideoAccessDecision call({
    required VideoItem video,
    required AppSession session,
  }) {
    if (video.isFree) {
      return const VideoAccessDecision.watch();
    }

    if (!session.isAuthenticated) {
      return const VideoAccessDecision.login();
    }

    if (!session.hasPremiumAccess) {
      return const VideoAccessDecision.upgrade();
    }

    return const VideoAccessDecision.watch();
  }
}
