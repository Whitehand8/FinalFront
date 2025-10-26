// lib/screens/create_room_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../router/routers.dart';
import '../services/room_service.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _roomIdCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final roomId = _roomIdCtrl.text.trim();
      final password = _passwordCtrl.text.trim();
      final room = await RoomService.joinRoom(roomId, password: password);

      // 성공 시 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_room_id', room.id!);

      if (!mounted) return;
      context.go(Routes.roomById(room.id!));
    } on RoomServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('입장 실패: ${e.message}')));
      // 실패 시 저장하지 않음
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('방 참가'),
        backgroundColor: const Color(0xFF8C7853),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.rooms),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _roomIdCtrl,
                  decoration: const InputDecoration(
                      labelText: '방 코드 (UUID)', border: OutlineInputBorder()),
                  validator: (val) {
                    final v = val?.trim() ?? '';
                    if (v.isEmpty) return '방 코드를 입력하세요.';
                    final uuidLike = RegExp(r'^[0-9a-fA-F-]{10,}$');
                    if (!uuidLike.hasMatch(v)) return '유효한 UUID 형식이 아닙니다.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(
                      labelText: '비밀번호', border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (val) {
                    final v = val?.trim() ?? '';
                    if (v.isEmpty) return '비밀번호를 입력하세요.'; // ← 필수
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: const Color(0xFF2A3439),
                  ),
                  child: Text(_loading ? '입장 중...' : '입장하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
