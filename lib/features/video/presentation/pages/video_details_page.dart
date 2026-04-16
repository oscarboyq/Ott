import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:video/features/auth/domain/entities/app_session.dart';
import 'package:video/features/auth/presentation/controllers/session_controller.dart';
import 'package:video/features/catalog/domain/entities/video_item.dart';
import 'package:video/features/catalog/domain/usecases/resolve_video_access.dart';
import 'package:video/features/catalog/presentation/controllers/catalog_controller.dart';

class VideoDetailsPage extends StatelessWidget {
  const VideoDetailsPage({required this.videoId, super.key});

  final String videoId;

  @override
  Widget build(BuildContext context) {
    final CatalogController catalogController = GetIt.I<CatalogController>();
    final SessionController sessionController = GetIt.I<SessionController>();
    final ResolveVideoAccessUseCase accessResolver =
        GetIt.I<ResolveVideoAccessUseCase>();

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        catalogController,
        sessionController,
      ]),
      builder: (BuildContext context, Widget? child) {
        final VideoItem? video = catalogController.findById(videoId);

        if (video == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Video not found',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'The selected title is missing from the current catalog.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Back to home'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final AppSession session = sessionController.session;
        final VideoAccessDecision decision = accessResolver(
          video: video,
          session: session,
        );
        final Color accent = _hexToColor(video.accentHex);
        final List<VideoItem> recommendations = catalogController.videos
            .where((VideoItem item) => item.id != video.id)
            .take(6)
            .toList();

        return Scaffold(
          appBar: AppBar(title: Text(video.title)),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xFF070B12),
                  Color(0xFF0B111C),
                  Color(0xFF070B12),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1220),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: LinearGradient(
                            colors: <Color>[
                              Color.lerp(accent, Colors.black, 0.14)!,
                              Color.lerp(
                                accent,
                                const Color(0xFF09111B),
                                0.74,
                              )!,
                              const Color(0xFF070B12),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                final bool stacked = constraints.maxWidth < 900;
                                final Widget details = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: <Widget>[
                                        _InfoPill(label: video.category),
                                        _InfoPill(label: video.durationLabel),
                                        _InfoPill(label: video.releaseLabel),
                                        _InfoPill(
                                          label: video.isFree
                                              ? 'Free title'
                                              : 'Premium title',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      video.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            height: 0.96,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      video.tagline,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.76,
                                            ),
                                          ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      video.description,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.80,
                                            ),
                                          ),
                                    ),
                                    const SizedBox(height: 22),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: <Widget>[
                                        FilledButton.icon(
                                          onPressed: sessionController.isBusy
                                              ? null
                                              : () async {
                                                  if (decision.needsLogin) {
                                                    await sessionController
                                                        .signInDemoUser();
                                                    return;
                                                  }

                                                  if (decision.needsUpgrade) {
                                                    context.push('/plans');
                                                  }
                                                },
                                          icon: Icon(
                                            decision.canWatch
                                                ? Icons.play_arrow_rounded
                                                : decision.needsLogin
                                                ? Icons.login
                                                : Icons
                                                      .workspace_premium_outlined,
                                          ),
                                          label: Text(
                                            decision.primaryActionLabel,
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              context.push('/plans'),
                                          icon: const Icon(
                                            Icons.workspace_premium_outlined,
                                          ),
                                          label: const Text('View plans'),
                                        ),
                                      ],
                                    ),
                                  ],
                                );

                                if (stacked) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      details,
                                      const SizedBox(height: 22),
                                      _SideAccessPanel(
                                        decision: decision,
                                        session: session,
                                      ),
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(flex: 6, child: details),
                                    const SizedBox(width: 22),
                                    Expanded(
                                      flex: 4,
                                      child: _SideAccessPanel(
                                        decision: decision,
                                        session: session,
                                      ),
                                    ),
                                  ],
                                );
                              },
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (decision.canWatch)
                        _StreamPlayerCard(videoUrl: video.videoUrl)
                      else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Playback is currently locked',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  decision.needsLogin
                                      ? 'This title follows your rule exactly: the viewer must sign in before they can continue toward paid access.'
                                      : 'This title is premium-only. Once entitlement is active, the same screen can open the stream without changing architecture.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints constraints) {
                          final bool stacked = constraints.maxWidth < 900;

                          if (stacked) {
                            return const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _FactCard(
                                  title: 'Access rule',
                                  body:
                                      'Free titles open immediately. Premium titles first check login, then membership.',
                                ),
                                SizedBox(height: 16),
                                _FactCard(
                                  title: 'Backend note',
                                  body:
                                      'Later this page should request a secure playback URL from the backend after access validation.',
                                ),
                                SizedBox(height: 16),
                                _FactCard(
                                  title: 'Admin workflow',
                                  body:
                                      'Only the admin uploads the file, saves metadata, and decides whether a title is free or premium.',
                                ),
                              ],
                            );
                          }

                          return const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: _FactCard(
                                  title: 'Access rule',
                                  body:
                                      'Free titles open immediately. Premium titles first check login, then membership.',
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _FactCard(
                                  title: 'Backend note',
                                  body:
                                      'Later this page should request a secure playback URL from the backend after access validation.',
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _FactCard(
                                  title: 'Admin workflow',
                                  body:
                                      'Only the admin uploads the file, saves metadata, and decides whether a title is free or premium.',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'More Like This',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'A recommendation rail keeps the detail page feeling closer to a real OTT screen.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.64),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 240,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: recommendations.length,
                          separatorBuilder: (BuildContext context, int index) =>
                              const SizedBox(width: 14),
                          itemBuilder: (BuildContext context, int index) {
                            final VideoItem item = recommendations[index];
                            return _RecommendationCard(video: item);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SideAccessPanel extends StatelessWidget {
  const _SideAccessPanel({required this.decision, required this.session});

  final VideoAccessDecision decision;
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Access status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(decision.supportingMessage),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    session.isAuthenticated
                        ? Icons.verified_user_outlined
                        : Icons.person_off_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      session.isAuthenticated
                          ? session.hasPremiumAccess
                                ? 'Logged in with premium access'
                                : 'Logged in without premium access'
                          : 'Guest viewer',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactCard extends StatelessWidget {
  const _FactCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(body),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.video});

  final VideoItem video;

  @override
  Widget build(BuildContext context) {
    final Color accent = _hexToColor(video.accentHex);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => context.push('/video/${video.id}'),
      child: Ink(
        width: 168,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: <Color>[accent, Color.lerp(accent, Colors.black, 0.34)!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(video.isFree ? 'Free' : 'Premium'),
            ),
            const Spacer(),
            Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${video.category}  •  ${video.durationLabel}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StreamPlayerCard extends StatefulWidget {
  const _StreamPlayerCard({required this.videoUrl});

  final String videoUrl;

  @override
  State<_StreamPlayerCard> createState() => _StreamPlayerCardState();
}

class _StreamPlayerCardState extends State<_StreamPlayerCard> {
  VideoPlayerController? _controller;
  Future<void>? _initialization;
  Object? _error;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _startStreaming() async {
    if (_controller != null) {
      if (_controller!.value.isPlaying) {
        await _controller!.pause();
      } else {
        await _controller!.play();
      }

      if (mounted) {
        setState(() {});
      }
      return;
    }

    final VideoPlayerController controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );

    setState(() {
      _controller = controller;
      _initialization = controller.initialize();
      _error = null;
    });

    try {
      await _initialization;
      await controller.play();
    } catch (error) {
      _error = error;
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Streaming window',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            const Text(
              'The interface now feels more OTT, but the player is still using a public sample source until we connect secure backend playback.',
            ),
            const SizedBox(height: 18),
            if (_error != null)
              Text(
                'Playback could not start on this device.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              )
            else if (controller == null)
              Container(
                height: 360,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF0B1321), Color(0xFF05070D)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 80,
                  ),
                ),
              )
            else
              FutureBuilder<void>(
                future: _initialization,
                builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
                  if (snapshot.connectionState != ConnectionState.done ||
                      !controller.value.isInitialized) {
                    return const AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final double aspectRatio = controller.value.aspectRatio == 0
                      ? 16 / 9
                      : controller.value.aspectRatio;

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: AspectRatio(
                      aspectRatio: aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _startStreaming,
                  icon: Icon(
                    controller?.value.isPlaying == true
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                  ),
                  label: Text(
                    controller?.value.isPlaying == true
                        ? 'Pause'
                        : controller == null
                        ? 'Start stream'
                        : 'Play',
                  ),
                ),
                if (controller != null)
                  OutlinedButton(
                    onPressed: () async {
                      await controller.seekTo(Duration.zero);
                      await controller.pause();
                      if (mounted) {
                        setState(() {});
                      }
                    },
                    child: const Text('Restart'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Color _hexToColor(String hex) {
  final String sanitized = hex.replaceFirst('#', '');
  final String value = sanitized.length == 6 ? 'FF$sanitized' : sanitized;
  return Color(int.parse(value, radix: 16));
}
