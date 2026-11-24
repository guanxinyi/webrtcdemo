import 'package:material_ui/material_ui.dart';
import 'package:livekit_client/livekit_client.dart';

import '../theme.dart';

/// Video tile for a single participant, rebuilt whenever the participant
/// notifies a change (speaking, mute, track published, ...).
class ParticipantTile extends StatefulWidget {
  const ParticipantTile({
    super.key,
    required this.participant,
    required this.isLocal,
  });

  final Participant participant;
  final bool isLocal;

  @override
  State<ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends State<ParticipantTile> {
  @override
  void initState() {
    super.initState();
    widget.participant.addListener(_onParticipantChanged);
  }

  @override
  void didUpdateWidget(covariant ParticipantTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant != widget.participant) {
      oldWidget.participant.removeListener(_onParticipantChanged);
      widget.participant.addListener(_onParticipantChanged);
    }
  }

  @override
  void dispose() {
    widget.participant.removeListener(_onParticipantChanged);
    super.dispose();
  }

  void _onParticipantChanged() {
    if (mounted) setState(() {});
  }

  ({VideoTrack track, bool isScreenShare})? _activeVideo() {
    final publications = widget.participant.videoTrackPublications;
    for (final source in const [TrackSource.camera, TrackSource.screenShareVideo]) {
      for (final publication in publications) {
        final track = publication.track;
        if (publication.source == source && !publication.muted && track is VideoTrack) {
          return (track: track, isScreenShare: source == TrackSource.screenShareVideo);
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final participant = widget.participant;
    final video = _activeVideo();
    final track = video?.track;
    final isScreenShare = video?.isScreenShare ?? false;
    final isSpeaking = participant.isSpeaking;
    final displayName = participant.name.isNotEmpty ? participant.name : participant.identity;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSpeaking ? AppColors.accent : Colors.white10,
          width: isSpeaking ? 2 : 1,
        ),
        boxShadow: isSpeaking
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.28),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (track != null)
            VideoTrackRenderer(
              track,
              fit: isScreenShare ? VideoViewFit.contain : VideoViewFit.cover,
              mirrorMode: widget.isLocal && !isScreenShare ? VideoViewMirrorMode.auto : VideoViewMirrorMode.off,
              placeholderBuilder: (_) => const _TilePlaceholder(),
            )
          else
            _AvatarPlaceholder(name: displayName),
          Positioned(
            top: 10,
            right: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isScreenShare)
                  const _Badge(icon: Icons.monitor, label: '屏幕共享'),
                if (widget.isLocal) ...[
                  if (isScreenShare) const SizedBox(width: 6),
                  const _Badge(label: '我'),
                ],
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 28, 12, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    participant.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    size: 16,
                    color: participant.isMuted ? AppColors.danger : AppColors.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _SignalBars(quality: participant.connectionQuality),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TilePlaceholder extends StatelessWidget {
  const _TilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.4),
          radius: 1.1,
          colors: [Color(0xFF23324F), AppColors.surface],
        ),
      ),
      child: Center(
        child: Container(
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.accent],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({this.icon, required this.label});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppColors.accent),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.quality});

  final ConnectionQuality quality;

  @override
  Widget build(BuildContext context) {
    final (active, color) = switch (quality) {
      ConnectionQuality.excellent => (3, AppColors.accent),
      ConnectionQuality.good => (2, const Color(0xFF4ADE80)),
      ConnectionQuality.poor => (1, Colors.orangeAccent),
      _ => (0, AppColors.danger),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (index) {
        final filled = index < active;
        return Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Container(
            width: 3,
            height: 5.0 + index * 3,
            decoration: BoxDecoration(
              color: filled ? color : Colors.white24,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      }),
    );
  }
}
