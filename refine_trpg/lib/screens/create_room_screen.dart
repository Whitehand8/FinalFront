// screens/create_room_screen.dart
import 'package:flutter/material.dart';
import '../models/room.dart';
import '../services/room_service.dart';
import '../services/navigation_service.dart';
import 'dart:io'; // SocketException용
import 'dart:async'; // TimeoutException용

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();

  // 화면 상태 변수 (폼에 바인딩)
  String _roomName = '';
  String _password = '';
  int _capacity = 2; // 백엔드 최소값 2로 변경
  String _selectedSystem = 'coc7e'; // TRPG 시스템 선택

  bool _isLoading = false; // API 호출 중 로딩 인디케이터 표시

  // 인원 수 감소 (최소 2명)
  void _decrementCapacity() {
    if (_capacity > 2) {
      setState(() {
        _capacity--;
      });
    }
  }

  // 인원 수 증가 (최대 8명)
  void _incrementCapacity() {
    if (_capacity < 8) {
      setState(() {
        _capacity++;
      });
    }
  }

  /// 폼 제출: RoomService.createRoom() 호출
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final newRoom = Room(
        name: _roomName,
        password: _password.isNotEmpty ? _password : null,
        maxParticipants: _capacity,
        systemId: _selectedSystem,
      );

      final created = await RoomService.createRoom(newRoom);
      if (!mounted) return;

      // 수정된 네비게이션 사용
      NavigationService.navigateToRoom(created);
    } on RoomServiceException catch (e) {
      if (!mounted) return;

      String errorMessage = '방 생성 실패';
      if (e.message.contains('INVALID_MAX_PARTICIPANTS')) {
        errorMessage = '인원 수는 2~8명 사이만 가능합니다';
      } else if (e.message.contains('PASSWORD_REQUIRED')) {
        errorMessage = '비밀번호는 필수 입력값입니다';
      } else if (e.message.contains('INVALID_ROOM_NAME')) {
        errorMessage = '방 이름은 1~50자로 입력해주세요';
      } else {
        errorMessage = '방 생성 실패: ${e.message}';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } on SocketException {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('네트워크 연결을 확인해주세요.')));
    } on TimeoutException {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('서버 응답 시간이 초과되었습니다.')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('방 생성 중 오류가 발생했습니다.')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
          onPressed: () {
            NavigationService.goBack();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1) 방 이름 입력
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '방 이름 (1~50자)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 50, // 백엔드 maxLength 50 반영
                onSaved: (val) => _roomName = val!.trim(),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return '방 이름을 입력하세요.';
                  }
                  if (val.trim().length > 50) {
                    return '방 이름은 50자 이내로 입력하세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 2) 비밀번호 입력 (선택 사항)
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '비밀번호 (입력하지 않으면 공개 방)',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                maxLength: 20,
                onSaved: (val) => _password = val!.trim(),
                validator: (val) {
                  if (val != null && val.trim().length > 20) {
                    // ← trim() 후 길이 체크
                    return '비밀번호는 20자 이내여야 합니다';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 3) 인원 수 선택 (2~8명)
              Text('인원 수 ($_capacity 명)', style: const TextStyle(fontSize: 16)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _capacity > 2 ? _decrementCapacity : null,
                    color: _capacity <= 2 ? Colors.grey : null,
                  ),
                  const SizedBox(width: 24),
                  Text('$_capacity', style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 24),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _capacity < 8 ? _incrementCapacity : null,
                    color: _capacity >= 8 ? Colors.grey : null,
                  ),
                ],
              ),
              const Text(
                '※ 최소 2명 ~ 최대 8명 가능',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // 4) TRPG 시스템 선택
              DropdownButtonFormField<String>(
                value: _selectedSystem,
                decoration: const InputDecoration(
                  labelText: 'TRPG 시스템',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'coc7e',
                    child: Text('크툴루의 부름 7판'),
                  ),
                  DropdownMenuItem(
                    value: 'dnd5e',
                    child: Text('던전 앤 드래곤 5판'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedSystem = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 32),

              // 5) 방 만들기 버튼
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
