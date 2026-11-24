import 'package:material_ui/material_ui.dart';

import '../theme.dart';

class ControlBar extends StatelessWidget {
  const ControlBar({
    super.key,
    required this.microphoneEnabled,
    required this.cameraEnabled,
    required this.screenShareEnabled,
    required this.canShareScreen,
    required this.onToggleMicrophone,
    required this.onToggleCamera,
    required this.onToggleScreenShare,
    required this.onLeave,
  });

  final bool microphoneEnabled;
  final bool cameraEnabled;
  final bool screenShareEnabled;
  final bool canShareScreen;
  final VoidCallback onToggleMicrophone;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleScreenShare;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final showLabels = MediaQuery.sizeOf(context).width >= 720;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: microphoneEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
            label: microphoneEnabled ? '静音' : '取消静音',
            danger: !microphoneEnabled,
            showLabel: showLabels,
            onPressed: onToggleMicrophone,
          ),
          _ActionButton(
            icon: cameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            label: cameraEnabled ? '关闭视频' : '开启视频',
            danger: !cameraEnabled,
            showLabel: showLabels,
            onPressed: onToggleCamera,
          ),
          if (canShareScreen)
            _ActionButton(
              icon: screenShareEnabled ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded,
              label: screenShareEnabled ? '停止共享' : '共享屏幕',
              active: screenShareEnabled,
              showLabel: showLabels,
              onPressed: onToggleScreenShare,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(width: 1, height: 28, color: Colors.white12),
          ),
          _ActionButton(
            icon: Icons.call_end_rounded,
            label: '离开',
            danger: true,
            filled: true,
            showLabel: showLabels,
            onPressed: onLeave,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.danger = false,
    this.active = false,
    this.filled = false,
    this.showLabel = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool danger;
  final bool active;
  final bool filled;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final background = filled
        ? AppColors.danger
        : danger
        ? AppColors.danger.withValues(alpha: 0.16)
        : active
        ? AppColors.primary.withValues(alpha: 0.24)
        : Colors.white.withValues(alpha: 0.06);
    final foreground = filled
        ? Colors.white
        : danger
        ? const Color(0xFFFF8A8A)
        : active
        ? AppColors.accent
        : AppColors.textPrimary;

    final button = Material(
      color: background,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: showLabel ? 16 : 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: foreground),
              if (showLabel) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(color: foreground, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (showLabel) return Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: button);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(message: label, child: button),
    );
  }
}
