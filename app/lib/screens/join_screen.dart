import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../theme.dart';
import 'room_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _serverController;
  late final TextEditingController _roomController;
  late final TextEditingController _nameController;

  bool _cameraEnabled = true;
  bool _microphoneEnabled = true;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController(text: AppConfig.apiBaseUrl);
    _roomController = TextEditingController(text: AppConfig.defaultRoom);
    _nameController = TextEditingController(text: '游客${1000 + Random().nextInt(9000)}');
  }

  @override
  void dispose() {
    _serverController.dispose();
    _roomController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_joining || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      final api = ApiClient(baseUrl: _serverController.text.trim());
      final credentials = await api.join(
        room: _roomController.text.trim(),
        name: _nameController.text.trim(),
      );

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RoomScreen(
            credentials: credentials,
            startCamera: _cameraEnabled,
            startMicrophone: _microphoneEnabled,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = '加入房间失败：$error');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _JoinBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Brand(),
                      const SizedBox(height: 28),
                      _buildCard(),
                      const SizedBox(height: 20),
                      const Text(
                        '请先启动 server 中的 Token API 与 LiveKit Server，详见 README',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              maxLength: 32,
              decoration: const InputDecoration(
                labelText: '昵称',
                hintText: '其他人看到的名字',
                prefixIcon: Icon(Icons.person_outline_rounded),
                counterText: '',
              ),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return '请输入昵称';
                if (name.length > 32) return '昵称不能超过 32 个字符';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _roomController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '房间号',
                hintText: '例如 demo-room',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
              validator: (value) {
                final room = value?.trim() ?? '';
                if (room.isEmpty) return '请输入房间号';
                if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(room)) {
                  return '仅支持字母、数字、下划线和中划线（1-64 位）';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _serverController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _join(),
              decoration: const InputDecoration(
                labelText: '后端服务地址',
                hintText: 'http://localhost:8080',
                prefixIcon: Icon(Icons.dns_outlined),
                helperText: '获取 LiveKit 访问凭证的 Token API 地址',
              ),
              validator: (value) {
                final uri = Uri.tryParse(value?.trim() ?? '');
                if (uri == null || !uri.hasScheme || uri.host.isEmpty) return '请输入有效的服务地址';
                if (uri.scheme != 'http' && uri.scheme != 'https') return '仅支持 http / https';
                return null;
              },
            ),
            const SizedBox(height: 18),
            _ToggleRow(
              icon: Icons.videocam_outlined,
              title: '加入时开启摄像头',
              value: _cameraEnabled,
              onChanged: (value) => setState(() => _cameraEnabled = value),
            ),
            const SizedBox(height: 6),
            _ToggleRow(
              icon: Icons.mic_none_rounded,
              title: '加入时开启麦克风',
              value: _microphoneEnabled,
              onChanged: (value) => setState(() => _microphoneEnabled = value),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              child: _error == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFFF8A8A)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Color(0xFFFFB4B4), fontSize: 12.5, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _joining ? null : _join,
              child: _joining
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_forward_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('加入房间'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.accent],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.videocam_rounded, size: 34, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          'LiveKit Meet',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Flutter 全平台实时音视频',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _JoinBackground extends StatelessWidget {
  const _JoinBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1020), AppColors.background, Color(0xFF0B1424)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _Glow(color: AppColors.primary.withValues(alpha: 0.35), size: 380),
          ),
          Positioned(
            bottom: -140,
            right: -100,
            child: _Glow(color: AppColors.accent.withValues(alpha: 0.22), size: 420),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
