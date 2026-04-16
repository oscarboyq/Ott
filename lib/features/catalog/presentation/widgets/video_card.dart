import 'package:flutter/material.dart';
import 'package:video/features/catalog/domain/entities/video_item.dart';
import 'package:video/features/catalog/domain/usecases/resolve_video_access.dart';

class VideoCard extends StatelessWidget {
  const VideoCard({
    required this.video,
    required this.decision,
    required this.onTap,
    super.key,
  });

  final VideoItem video;
  final VideoAccessDecision decision;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = _hexToColor(video.accentHex);
    final ThemeData theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              colors: <Color>[accent, Color.lerp(accent, Colors.black, 0.22)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _PillLabel(label: video.category),
                    _PillLabel(label: video.isFree ? 'Free' : 'Premium'),
                    if (video.isFeatured) const _PillLabel(label: 'Featured'),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  video.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  video.tagline,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
                const Spacer(),
                Text(
                  '${video.durationLabel}  •  ${video.releaseLabel}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(decision.cardLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
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
