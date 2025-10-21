import 'package:flutter/material.dart';
import 'package:frontend/screens/room_screen.dart';
import 'package:go_router/go_router.dart';
import '../services/room_service.dart';
import '../models/room.dart';

class FindRoomScreen extends StatefulWidget {
  static const routeName = '/find-room';

  const FindRoomScreen({super.key});

  @override
  State<FindRoomScreen> createState() => _FindRoomScreenState();
}

class _FindRoomScreenState extends State<FindRoomScreen> {
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
  final form = _formKey.currentState;
  if (form == null) return;
  if (!form.validate()) return;

  setState(() => _loading = true);
  try {
    final roomId = _roomIdCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final Room joined = await RoomService.joinRoom(
      roomId,
      password: password,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('입장 성공: ${joined.name}'))
    );

    // GoRouter 방식으로 이동 — roomId를 path parameter로 전달
    context.go('${RoomScreen.routeName}/${joined.id}');
  } catch (e) {
    if (!mounted) return; // ← 추가
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('입장 실패: $e'))
    );
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('방 참가')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1) 방 코드 입력 (UUID)
                TextFormField(
                  controller: _roomIdCtrl,
                  decoration: const InputDecoration(
                    labelText: '방 코드 (UUID)',
                    hintText: '예: 3d0c2b19-...-...-...-...',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (val) {
                    final v = val?.trim() ?? '';
                    if (v.isEmpty) return '방 코드를 입력하세요.';
                    // 간단한 UUID 형식 체크(대략)
                    final uuidLike = RegExp(r'^[0-9a-fA-F-]{10,}$');
                    if (!uuidLike.hasMatch(v)) return '유효한 UUID 형식이 아닙니다.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 2) 비밀번호 입력
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (val) {
                    final v = val?.trim() ?? '';
                    if (v.isEmpty) return '비밀번호를 입력하세요.';
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _loading ? null : _submit,
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
