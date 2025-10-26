import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../router/routers.dart';

/// 방 메뉴 화면 (로그인된 사용자 전용)
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String? _lastRoomId;

  @override
  void initState() {
    super.initState();
    _loadLastRoomId();
  }

  Future<void> _loadLastRoomId() async {
    final prefs = await SharedPreferences.getInstance();
    final roomId = prefs.getString('last_room_id');
    if (mounted) {
      setState(() {
        _lastRoomId = roomId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8C7853),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'TRPG에 오신 것을 환영합니다!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 64),
              ElevatedButton.icon(
                onPressed: () => context.go(Routes.createRoom),
                icon: const Icon(Icons.add, color: Color(0xFF2A3439)),
                label: const Text('방 만들기',
                    style: TextStyle(color: Color(0xFF2A3439), fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.go(Routes.joinRoom),
                icon: const Icon(Icons.vpn_key, color: Color(0xFF2A3439)),
                label: const Text('방 참가',
                    style: TextStyle(color: Color(0xFF2A3439), fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (_lastRoomId != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.go(Routes.roomById(_lastRoomId!)),
                  icon: const Icon(Icons.restore, color: Color(0xFF2A3439)),
                  label: const Text('이전 방으로 돌아가기',
                      style: TextStyle(color: Color(0xFF2A3439), fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.go(Routes.options),
                icon: const Icon(Icons.settings, color: Color(0xFF2A3439)),
                label: const Text('설정',
                    style: TextStyle(color: Color(0xFF2A3439), fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
}
