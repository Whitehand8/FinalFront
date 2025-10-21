// lib/screens/create_room_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/room.dart';
import '../services/room_service.dart';
import '../screens/room_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  static const routeName = '/create-room';

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
      password: _password,
      maxParticipants: _capacity,
    );

    final created = await RoomService.createRoom(newRoom);

    if (!mounted) return;

    // 필수: id가 null이거나 빈 문자열이면 에러 처리
    if (created.id == null || created.id!.isEmpty) {
      throw Exception('서버가 생성된 방의 UUID를 반환하지 않았습니다.');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('방 생성 성공! ID=${created.id}')),
    );
    context.go('${RoomScreen.routeName}/${created.id}');
  } catch (e, st) {
    if (!mounted) return;

    String errorMessage = '방 생성 실패';
    final errorStr = e.toString();

    if (errorStr.contains('INVALID_MAX_PARTICIPANTS')) {
      errorMessage = '인원 수는 2~8명 사이만 가능합니다';
    } else if (errorStr.contains('PASSWORD_REQUIRED')) {
      errorMessage = '비밀번호는 필수 입력값입니다';
    } else if (errorStr.contains('INVALID_ROOM_NAME')) {
      errorMessage = '방 이름은 1~50자로 입력해주세요';
    } else {
      errorMessage = '방 생성 실패: $errorStr';
      print('Error stack: $st');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('방 만들기')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1) 방 이름 입력
              TextFormField(
                decoration: InputDecoration(
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
              SizedBox(height: 16),

              // 2) 비밀번호 입력 (모든 방에 필수)
              TextFormField(
                decoration: InputDecoration(
                  labelText: '비밀번호 (1~20자)',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                maxLength: 20,
                onSaved: (val) => _password = val!.trim(),
               validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return '비밀번호는 필수 입력값입니다';
                  }
                  if (val.trim().length > 20) { // ← trim() 후 길이 체크
                  return '비밀번호는 1~20자여야 합니다';
                  }
                  return null;
                  },
                  ),
                  SizedBox(height: 16),
              // 3) 인원 수 선택 (2~8명)
              Text('인원 수 ($_capacity 명)', style: TextStyle(fontSize: 16)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline),
                    onPressed: _capacity > 2 ? _decrementCapacity : null,
                    color: _capacity <= 2 ? Colors.grey : null,
                  ),
                  SizedBox(width: 24),
                  Text('$_capacity', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 24),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline),
                    onPressed: _capacity < 8 ? _incrementCapacity : null,
                    color: _capacity >= 8 ? Colors.grey : null,
                  ),
                ],
              ),
              Text(
                '※ 최소 2명 ~ 최대 8명 가능',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),

              // 4) 방 만들기 버튼
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text('방 만들기', style: TextStyle(fontSize: 18)),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}