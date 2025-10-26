// screens/create_room_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/room.dart';
import '../router/routers.dart';
import '../services/room_service.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  String _roomName = '';
  String _password = '';
  int _capacity = 2;
  String _selectedSystem = 'coc7e';
  bool _isLoading = false;

  void _decrementCapacity() {
    if (_capacity > 2) setState(() => _capacity--);
  }

  void _incrementCapacity() {
    if (_capacity < 8) setState(() => _capacity++);
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final newRoom = Room(
        name: _roomName,
        password: _password,
        maxParticipants: _capacity,
        system: _selectedSystem,
      );

      final created = await RoomService.createRoom(newRoom);

      // 방 생성 성공 시 last_room_id 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_room_id', created.id!);

      if (!mounted) return;
      context.go(Routes.roomById(created.id!));
    } on RoomServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('방 생성 실패: ${e.message}')));
      // 실패 시 SharedPreferences 수정하지 않음
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('방 만들기'),
        backgroundColor: const Color(0xFF8C7853),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.rooms),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                    labelText: '방 이름 (1~50자)', border: OutlineInputBorder()),
                maxLength: 50,
                onSaved: (val) => _roomName = val!.trim(),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return '방 이름을 입력하세요.';
                  if (val.trim().length > 50) return '방 이름은 50자 이내로 입력하세요';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // ✅ 비밀번호 필수 입력
              TextFormField(
                decoration: const InputDecoration(
                    labelText: '비밀번호', border: OutlineInputBorder()),
                obscureText: true,
                maxLength: 20,
                onSaved: (val) => _password = val!.trim(),
                validator: (val) {
                  final v = val?.trim() ?? '';
                  if (v.isEmpty) return '비밀번호를 입력하세요.'; // ← 필수
                  if (v.length > 20) return '비밀번호는 20자 이내여야 합니다';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('인원 수 ($_capacity 명)', style: const TextStyle(fontSize: 16)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _capacity > 2 ? _decrementCapacity : null),
                  const SizedBox(width: 24),
                  Text('$_capacity', style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 24),
                  IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _capacity < 8 ? _incrementCapacity : null),
                ],
              ),
              const Text('※ 최소 2명 ~ 최대 8명 가능',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedSystem,
                decoration: const InputDecoration(
                    labelText: 'TRPG 시스템', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'coc7e', child: Text('크툴루의 부름 7판')),
                  DropdownMenuItem(value: 'dnd5e', child: Text('던전 앤 드래곤 5판')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _selectedSystem = value);
                },
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: const Color(0xFF2A3439),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child:
                          const Text('방 만들기', style: TextStyle(fontSize: 18)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
