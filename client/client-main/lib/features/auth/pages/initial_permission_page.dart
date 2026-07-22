import 'package:flutter/material.dart';

import 'package:capstone_app/services/initial_permission_service.dart';

class InitialPermissionPage extends StatefulWidget {
  const InitialPermissionPage({required this.nextPage, super.key});

  final Widget nextPage;

  @override
  State<InitialPermissionPage> createState() => _InitialPermissionPageState();
}

class _InitialPermissionPageState extends State<InitialPermissionPage> {
  bool _requesting = false;
  InitialPermissionResult? _result;

  Future<void> _requestPermissions() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    final result = await InitialPermissionService.requestAll();
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _result = result;
    });
    if (result.allGranted) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted) _continue();
    }
  }

  void _continue() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => widget.nextPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      backgroundColor: const Color(0xFF100A06),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '모험 준비',
                style: TextStyle(
                  color: Color(0xFFFFD36A),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '걸음을 전투와 보상에 반영하려면 필요한 권한을 허용해주세요.',
                style: TextStyle(color: Colors.white70, height: 1.45),
              ),
              const SizedBox(height: 28),
              _permissionRow(
                icon: Icons.directions_walk_rounded,
                title: '신체 활동',
                description: '걸음 수를 측정해 공격 기회를 계산합니다.',
                granted: result?.activityGranted,
              ),
              const SizedBox(height: 12),
              _permissionRow(
                icon: Icons.location_on_rounded,
                title: '위치',
                description: '이동 거리를 확인하고 비정상 이동을 판별합니다.',
                granted: result?.locationGranted,
              ),
              const SizedBox(height: 12),
              _permissionRow(
                icon: Icons.notifications_active_rounded,
                title: '알림',
                description: '오프라인 공격 기회가 가득 차면 알려드립니다.',
                granted: result?.notificationGranted,
              ),
              const Spacer(),
              if (result != null && !result.allGranted) ...[
                const Text(
                  '허용하지 않은 기능은 걸음 및 거리 측정이 제한될 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFFF9D83), fontSize: 12),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: InitialPermissionService.openSettings,
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('앱 설정 열기'),
                ),
                const SizedBox(height: 10),
              ],
              FilledButton.icon(
                onPressed: _requesting
                    ? null
                    : (result == null ? _requestPermissions : _continue),
                icon: _requesting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        result == null
                            ? Icons.shield_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                label: Text(
                  _requesting
                      ? '권한 확인 중'
                      : (result == null ? '권한 허용하기' : '계속하기'),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: const Color(0xFF9A4F26),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionRow({
    required IconData icon,
    required String title,
    required String description,
    required bool? granted,
  }) {
    final statusColor = granted == null
        ? Colors.white38
        : granted
        ? const Color(0xFF79E28A)
        : const Color(0xFFFF765F);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C120C),
        border: Border.all(color: const Color(0xFF6D3B22)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD36A), size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            granted == true
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            color: statusColor,
          ),
        ],
      ),
    );
  }
}
