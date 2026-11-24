import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';

import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/control_bar.dart';
import '../widgets/participant_tile.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    required this.credentials,
    this.startCamera = true,
    this.startMicrophone = true,
  });

  final JoinCredentials credentials;
  final bool startCamera;
  final bool startMicrophone;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  bool _connecting = true;
  bool _reconnecting = false;
  bool _leaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
  }

  @override
  void dispose() {
    _room?.removeListener(_refresh);
    final listener = _listener;
    final room = _room;
    unawaited(() async {
      await listener?.dispose();
      await room?.dispose();
    }());
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _connect() async {
    final previousRoom = _room;
    final previousListener = _listener;
    if (previousRoom != null) previousRoom.removeListener(_refresh);
    unawaited(previousListener?.dispose());
    unawaited(previousRoom?.dispose());

    setState(() {
      _connecting = true;
      _reconnecting = false;
      _error = null;
    });

    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    _room = room;

    final listener = room.createListener();
    _listener = listener;
    listener
      ..on<RoomConnectedEvent>((_) {
        if (mounted) {
          setState(() {
            _connecting = false;
            _reconnecting = false;
            _error = null;
          });
        }
      })
      ..on<RoomReconnectingEvent>((_) {
        if (mounted) setState(() => _reconnecting = true);
      })
      ..on<RoomResumingEvent>((_) {
        if (mounted) setState(() => _reconnecting = true);
      })
      ..on<RoomReconnectedEvent>((_) {
        if (mounted) setState(() => _reconnecting = false);
      })
      ..on<RoomDisconnectedEvent>(_handleDisconnected)
      ..on<ParticipantConnectedEvent>((_) => _refresh())
      ..on<ParticipantDisconnectedEvent>((_) => _refresh())
      ..on<TrackSubscribedEvent>((_) => _refresh())
      ..on<TrackUnsubscribedEvent>((_) => _refresh())
      ..on<TrackMutedEvent>((_) => _refresh())
      ..on<TrackUnmutedEvent>((_) => _refresh())
      ..on<LocalTrackPublishedEvent>((_) => _refresh())
      ..on<LocalTrackUnpublishedEvent>((_) => _refresh())
      ..on<ActiveSpeakersChangedEvent>((_) => _refresh());

    room.addListener(_refresh);

    try {
      await room.connect(widget.credentials.url, widget.credentials.token);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = '连接房间失败：$error';
      });
      return;
    }

    if (!mounted) return;

    if (widget.startCamera) await _publishCamera(true, silent: true);
    if (widget.startMicrophone) await _publishMicrophone(true, silent: true);

    if (!mounted) return;
    setState(() => _connecting = false);
  }

  void _handleDisconnected(RoomDisconnectedEvent event) {
    if (!mounted || _leaving) return;
    setState(() {
      _connecting = false;
      _reconnecting = false;
      _error = event.reason == null ? '连接已断开' : '连接已断开（${event.reason}）';
    });
  }

  Future<void> _leave() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    try {
      await _room?.disconnect();
    } catch (_) {
      // Ignore teardown errors, the room is being closed anyway.
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _publishCamera(bool enabled, {bool silent = false}) async {
    final participant = _room?.localParticipant;
    if (participant == null) return;
    try {
      await participant.setCameraEnabled(enabled);
    } catch (error) {
      if (!silent) _showMessage('切换摄像头失败：${_describeError(error)}');
    }
    _refresh();
  }

  Future<void> _publishMicrophone(bool enabled, {bool silent = false}) async {
    final participant = _room?.localParticipant;
    if (participant == null) return;
    try {
      await participant.setMicrophoneEnabled(enabled);
    } catch (error) {
      if (!silent) _showMessage('切换麦克风失败：${_describeError(error)}');
    }
    _refresh();
  }

  Future<void> _toggleScreenShare() async {
    final participant = _room?.localParticipant;
    if (participant == null) return;
    try {
      await participant.setScreenShareEnabled(!participant.isScreenShareEnabled());
    } catch (error) {
      _showMessage('屏幕共享失败：${_describeError(error)}');
    }
    _refresh();
  }

  String _describeError(Object error) {
    final text = error.toString();
    return text.length > 160 ? '${text.substring(0, 160)}…' : text;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyInvite() async {
    final text =
        '${widget.credentials.name} 邀请你加入 LiveKit Meet\n'
        '房间号：${widget.credentials.room}\n'
        '服务地址：${widget.credentials.url}';
    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('邀请信息已复制');
  }

  List<Participant> _participants() {
    final room = _room;
    if (room == null) return const [];
    final local = room.localParticipant;
    final remotes = room.remoteParticipants.values.toList()
      ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    return [?local, ...remotes];
  }

  bool get _canShareScreen =>
      defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows;

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final participants = _participants();
    final local = room?.localParticipant;
    final connected = !_connecting && _error == null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0A1020), AppColors.background],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(room, participants.length),
                Expanded(child: _buildBody(participants)),
                if (connected) ...[
                  if (participants.length <= 1) _buildInviteHint(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                    child: Center(
                      child: ControlBar(
                        microphoneEnabled: local?.isMicrophoneEnabled() ?? false,
                        cameraEnabled: local?.isCameraEnabled() ?? false,
                        screenShareEnabled: local?.isScreenShareEnabled() ?? false,
                        canShareScreen: _canShareScreen,
                        onToggleMicrophone: () => _publishMicrophone(!(local?.isMicrophoneEnabled() ?? false)),
                        onToggleCamera: () => _publishCamera(!(local?.isCameraEnabled() ?? false)),
                        onToggleScreenShare: _toggleScreenShare,
                        onLeave: _leave,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Room? room, int participantCount) {
    final statusColor = _error != null
        ? AppColors.danger
        : _reconnecting
        ? Colors.orangeAccent
        : _connecting
        ? AppColors.textMuted
        : AppColors.accent;
    final statusText = _error != null
        ? '已断开'
        : _reconnecting
        ? '正在重连…'
        : _connecting
        ? '连接中…'
        : '已连接';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _leave,
            tooltip: '离开房间',
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '# ${widget.credentials.room}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.group_rounded, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  '$participantCount 人',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _copyInvite,
            tooltip: '复制邀请信息',
            icon: const Icon(Icons.ios_share_rounded, color: AppColors.textMuted, size: 20),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildBody(List<Participant> participants) {
    if (_connecting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              '正在加入 #${widget.credentials.room}',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              '正在建立音视频连接…',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded, color: Color(0xFFFF8A8A), size: 30),
              ),
              const SizedBox(height: 18),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: FilledButton.icon(
                  onPressed: _connect,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('重新连接'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _leave,
                child: const Text('返回首页', style: TextStyle(color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      );
    }

    if (participants.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        child: ParticipantTile(
          key: ValueKey(participants.first.identity),
          participant: participants.first,
          isLocal: participants.first is LocalParticipant,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = participants.length;
        final maxColumns = width >= 1100
            ? 3
            : width >= 640
            ? 2
            : 2;
        final columns = count < maxColumns ? count : maxColumns;
        final aspectRatio = width < 640 ? 3 / 4 : 16 / 10;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemCount: count,
          itemBuilder: (context, index) {
            final participant = participants[index];
            return ParticipantTile(
              key: ValueKey(participant.identity),
              participant: participant,
              isLocal: participant is LocalParticipant,
            );
          },
        );
      },
    );
  }

  Widget _buildInviteHint() {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded, size: 14, color: AppColors.accent),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                '房间已就绪，复制邀请信息发给好友即可加入',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
