// screens/create_room_screen.dart
import 'package:flutter/material.dart';
import 'package:refine_trpg/models/room.dart'; // Ensure room.dart is updated
import 'package:refine_trpg/services/room_service.dart'; // Ensure room_service.dart is updated
import 'package:refine_trpg/services/navigation_service.dart';
import 'dart:io'; // For SocketException
import 'dart:async'; // For TimeoutException
import 'package:flutter/foundation.dart'; // For debugPrint

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form state variables
  String _roomName = '';
  String _password = ''; // Store password from form
  int _capacity = 2; // Default capacity
  String _selectedSystem = 'coc7e'; // Default TRPG system

  bool _isLoading = false; // Loading indicator state

  // Decrement capacity (min 2)
  void _decrementCapacity() {
    if (_capacity > 2 && mounted) {
      setState(() => _capacity--);
    }
  }

  // Increment capacity (max 8)
  void _incrementCapacity() {
    if (_capacity < 8 && mounted) {
      setState(() => _capacity++);
    }
  }

  /// Handles form submission: Calls RoomService.createRoom()
  Future<void> _submitForm() async {
    // Validate form inputs
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save(); // Save form field values to state variables

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Create a Room object with basic info (password is handled separately now)
      // [수정됨] password -> hasPassword 로 변경하고, _password 변수 사용
      final newRoomData = Room(
        name: _roomName,
        hasPassword: _password.isNotEmpty, // Set based on password input
        maxParticipants: _capacity,
        systemId: _selectedSystem,
        // currentParticipants, participants, creator are set by backend
      );

      // [수정됨] Call createRoom with roomData and the actual password string
      final createdRoomResponse = await RoomService.createRoom(
        newRoomData,
        password: _password.isNotEmpty ? _password : null, // Pass password here
      );

      if (!mounted) return;
      debugPrint("Room created successfully: ${createdRoomResponse.id}");

      // Navigate to the created room screen
      NavigationService.navigateToRoom(createdRoomResponse);

    } on RoomServiceException catch (e) {
      debugPrint("Room creation failed: ${e.message} (Code: ${e.statusCode})");
      if (!mounted) return;
      // Provide more user-friendly messages based on potential errors
      String errorMessage = '방 생성 실패: ${e.message}'; // Default
      // You can add more specific checks based on backend error messages/codes if needed
      // e.g., if (e.message.contains('SOME_BACKEND_ERROR_CODE')) { ... }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.redAccent));
    } on SocketException {
      debugPrint("Room creation failed: Network error");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('네트워크 연결을 확인해주세요.')));
    } on TimeoutException {
      debugPrint("Room creation failed: Timeout");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('서버 응답 시간이 초과되었습니다.')));
    } catch (e) { // Catch any other unexpected errors
      debugPrint("Room creation failed: Unexpected error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('방 생성 중 예상치 못한 오류가 발생했습니다.')));
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
        // backgroundColor: const Color(0xFF8C7853), // Or use theme color
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
               NavigationService.goBack();
            }
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
              // 1) Room Name Input
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '방 이름',
                  hintText: '1~50자 사이로 입력',
                  border: OutlineInputBorder(),
                  counterText: "", // Hide default counter
                ),
                maxLength: 50,
                onSaved: (val) => _roomName = val?.trim() ?? '', // Trim and handle null
                validator: (val) {
                  final trimmed = val?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return '방 이름을 입력하세요.';
                  }
                  if (trimmed.length > 50) {
                    return '방 이름은 50자 이내로 입력하세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 2) Password Input (Optional)
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '비밀번호 (선택)',
                  hintText: '입력하지 않으면 공개 방',
                  border: OutlineInputBorder(),
                   counterText: "", // Hide default counter
                ),
                obscureText: true, // Hide password input
                maxLength: 20, // Max password length
                onSaved: (val) => _password = val?.trim() ?? '', // Trim and handle null
                validator: (val) {
                  // Password can be empty, but if provided, must be <= 20 chars
                  if (val != null && val.trim().length > 20) {
                    return '비밀번호는 20자 이내여야 합니다.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 3) Capacity Selector (2-8)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text('인원 수', style: Theme.of(context).textTheme.titleMedium),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        tooltip: '인원 감소',
                        // Disable if already at min capacity
                        onPressed: _capacity > 2 ? _decrementCapacity : null,
                        color: _capacity <= 2 ? Colors.grey : Theme.of(context).iconTheme.color,
                      ),
                      Text('$_capacity', style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: '인원 증가',
                        // Disable if already at max capacity
                        onPressed: _capacity < 8 ? _incrementCapacity : null,
                         color: _capacity >= 8 ? Colors.grey : Theme.of(context).iconTheme.color,
                      ),
                    ],
                  ),
                ],
              ),
              const Text(
                '최소 2명 ~ 최대 8명',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.end,
              ),
              const SizedBox(height: 24),

              // 4) TRPG System Selector
              DropdownButtonFormField<String>(
                value: _selectedSystem,
                decoration: const InputDecoration(
                  labelText: 'TRPG 시스템',
                  border: OutlineInputBorder(),
                ),
                // Provide items based on supported systems
                items: const [
                  DropdownMenuItem(value: 'coc7e', child: Text('크툴루의 부름 7판 (CoC 7e)')),
                  DropdownMenuItem(value: 'dnd5e', child: Text('던전 앤 드래곤 5판 (D&D 5e)')),
                  // Add more systems here if supported by backend/frontend
                ],
                onChanged: (value) {
                  if (value != null && mounted) {
                    setState(() => _selectedSystem = value);
                  }
                },
                // Add validator if needed (though default ensures selection)
                // validator: (val) => val == null ? '시스템을 선택하세요.' : null,
              ),
              const SizedBox(height: 32),

              // 5) Create Room Button
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('방 만들기', style: TextStyle(fontSize: 18)),
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        // backgroundColor: const Color(0xFFD4AF37), // Or use theme color
                        // foregroundColor: const Color(0xFF2A3439),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size(double.infinity, 50), // Make button wider
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}