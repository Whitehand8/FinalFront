import 'package:flutter/material.dart';
import '../services/navigation_service.dart';
import '../services/room_service.dart';
import '../models/room.dart';

class FindRoomScreen extends StatefulWidget {
  static const String routeName = '/find-room';

  const FindRoomScreen({super.key});

  @override
  State<FindRoomScreen> createState() => _FindRoomScreenState();
}

class _FindRoomScreenState extends State<FindRoomScreen> {
  // 폼 유효성 검사와 입력값 접근을 위한 키와 컨트롤러
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

  // 방 입장 처리 메서드
  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    setState(() => _loading = true);
    try {
      final roomId = _roomIdCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      // RoomService를 통해 방에 입장 시도
      final Room joined =
          await RoomService.joinRoom(roomId, password: password);
      if (!mounted) return;

      // 수정된 네비게이션 사용
      NavigationService.navigateToRoom(joined);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('입장 실패: $e')));
    } finally {
      // 로딩 상태 해제
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
          onPressed: () {
            NavigationService.goBack();
          },
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
                // 방 코드 입력 필드 (UUID 형식 검증)
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
                    final uuidLike = RegExp(r'^[0-9a-fA-F-]{10,}$');
                    if (!uuidLike.hasMatch(v)) return '유효한 UUID 형식이 아닙니다.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 비밀번호 입력 필드
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

                // 입장 버튼 (로딩 중에는 비활성화)
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
