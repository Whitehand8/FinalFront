// lib/screens/room_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart'; // Provider import
import 'package:shared_preferences/shared_preferences.dart';
import 'package:refine_trpg/models/room.dart';
import 'package:refine_trpg/models/participant.dart'; // 수정된 Participant 모델 import
import 'package:refine_trpg/router/routers.dart';
import 'package:refine_trpg/services/room_service.dart';
import 'package:refine_trpg/services/auth_service.dart'; // AuthService for user ID

// --- ✨ NPC 관련 Import ---
import 'package:refine_trpg/models/npc.dart';
import 'package:refine_trpg/providers/npc_provider.dart'; // NpcProvider import
import 'package:refine_trpg/widgets/npc/npc_list_item.dart'; // NPC 목록 아이템 위젯
import 'package:refine_trpg/widgets/npc/npc_create_modal.dart'; // NPC 생성 모달
import 'package:refine_trpg/widgets/npc/npc_detail_modal.dart'; // NPC 상세/수정 모달
// --- ✨ ---

class RoomScreen extends StatefulWidget {
  final Room room;
  const RoomScreen({super.key, required this.room});

  // --- ✨ Provider 제공 추가 ---
  /// RoomScreen을 생성할 때 NpcProvider를 함께 제공하는 정적 메서드
  static Widget create({required Room room}) {
    if (room.id == null) {
      return const Scaffold(
        body: Center(child: Text('유효한 방 ID가 없습니다.')),
      );
    }
    // ChangeNotifierProvider를 사용하여 NpcProvider 생성 및 주입
    return ChangeNotifierProvider(
      create: (_) => NpcProvider(room.id!), // 생성 시 roomId 전달 및 NPC 로딩 시작
      child: RoomScreen(room: room),
    );
  }
  // --- ✨ ---

  // byId 생성자도 RoomScreen.create를 사용하도록 수정
  static Widget byId({required String roomId}) {
    return FutureBuilder<Room>(
      future: RoomService.getRoom(roomId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('오류')),
            body: Center(child: Text('방을 불러올 수 없습니다: ${snapshot.error}')),
          );
        }
        // ✨ RoomScreen.create 메서드를 사용하여 Provider와 함께 생성
        return RoomScreen.create(room: snapshot.data!);
      },
    );
  }

  @override
  RoomScreenState createState() => RoomScreenState();
}

class RoomScreenState extends State<RoomScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _chatController = TextEditingController();
  late Room _room;
  List<Participant> _participants = [];
  bool _isParticipantsLoading = false;

  // --- ✨ GM 플래그 및 사용자 ID 추가 ---
  bool _isCurrentUserGm = false;
  int? _currentUserId; // 현재 로그인된 사용자의 ID (from AuthService, int)
  // --- ✨ ---

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _room = widget.room;
    _initializeScreen(); // ✨ 초기화 로직 통합
  }

  // --- ✨ 초기화 함수: 사용자 ID 로드 -> 참여자 로드 (역할 확인 포함) ---
  Future<void> _initializeScreen() async {
    await _loadCurrentUserId(); // AuthService에서 사용자 ID 가져오기
    await _loadParticipants(); // 참여자 목록 로드 (내부에서 _checkCurrentUserRole 호출)
    // NpcProvider는 RoomScreen.create에서 생성될 때 자동으로 fetchNpcs()를 호출함
  }
  // --- ✨ ---

  // --- ✨ 현재 사용자 ID 로드 함수 ---
  Future<void> _loadCurrentUserId() async {
    // AuthService 싱글톤 인스턴스를 통해 ID 가져오기
    final userId = await AuthService.instance.getCurrentUserId();
    if (mounted) {
      setState(() {
        _currentUserId = userId; // 상태 변수에 저장
      });
    }
  }
  // --- ✨ ---

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _validateRoomStillExists();
      // ✨ 앱 복귀 시 Provider 데이터 갱신 (선택적)
      context.read<NpcProvider>().fetchNpcs();
      _loadParticipants(); // 참여자 목록도 갱신
    }
  }

  // 방 유효성 검사 (기존과 동일)
  Future<void> _validateRoomStillExists() async {
    final roomId = _room.id;
    if (roomId == null) return;
    try {
      await RoomService.getRoom(roomId);
    } on RoomServiceException catch (e) {
      if (e.statusCode == 404 && mounted) {
        _showError('방이 삭제되어 더 이상 접근할 수 없습니다.');
        context.go(Routes.rooms); // 방 목록 화면으로 이동
      }
    }
  }

  // 참여자 목록 로드 및 역할 확인 (수정됨)
  Future<void> _loadParticipants() async {
    if (_room.id == null) return;
    if (!mounted) return;
    setState(() => _isParticipantsLoading = true);
    try {
      final participants = await RoomService.getParticipants(_room.id!);
      if (mounted) {
        setState(() => _participants = participants);
        _checkCurrentUserRole(); // ✨ 참여자 로드 후 역할 확인
      }
    } catch (e) {
      if(mounted) _showError('참여자 목록 로딩 실패: $e');
    } finally {
      if (mounted) setState(() => _isParticipantsLoading = false);
    }
  }

  // --- ✨ 현재 사용자 역할 확인 로직 (Participant.id와 _currentUserId 비교) ---
  void _checkCurrentUserRole() {
    // _currentUserId가 로드되었고 참여자 목록이 있을 때만 실행
    if (_currentUserId != null && _participants.isNotEmpty) {
      // 참여자 목록에서 현재 사용자 ID(int)와 Participant.id(int)가 일치하는 Participant 찾기
      // 🚨 Participant.id가 User ID를 의미한다고 가정
      final currentUserParticipant = _participants.firstWhere(
        (p) => p.id == _currentUserId,
        // 못 찾을 경우 기본값 (PLAYER) 반환
        orElse: () => Participant(id: 0, nickname: '', name: '', role: 'PLAYER'),
      );
      // 현재 상태와 다를 경우에만 setState 호출
      final isGm = currentUserParticipant.role == 'GM';
      if (mounted && _isCurrentUserGm != isGm) {
        setState(() {
          _isCurrentUserGm = isGm;
        });
      }
    } else if (mounted && _isCurrentUserGm != false) {
      // 사용자 ID가 없거나 참여자 목록이 비어있으면 GM 아님
      setState(() {
        _isCurrentUserGm = false;
      });
    }
  }
  // --- ✨ ---

  // --- 방 관리 함수들 ---
  Future<void> _leaveRoom() async { /* ... 기존과 동일 ... */ }
  void _showCannotLeaveAsCreatorDialog() { /* ... 기존과 동일 ... */ }
  void _showLeaveRoomDialog() { /* ... 기존과 동일 ... */ }
  Future<void> _deleteRoom() async { /* ... 기존과 동일 ... */ }
  void _showDeleteRoomDialog() { /* ... 기존과 동일 ... */ }
  Future<void> _transferCreator(int newCreatorId) async { /* ... 기존과 동일 ... */ }
  void _showTransferCreatorDialog() { /* ... 기존과 동일 ... */ }

  // ✨ 역할 업데이트: Participant ID (int) 사용
  Future<void> _updateParticipantRole(int participantId, String newRole) async {
     try {
       // RoomService.updateParticipantRole 호출 시 participantId (int) 전달
       await RoomService.updateParticipantRole(_room.id!, participantId.toString(), newRole); // API가 String ID를 받을 경우 .toString()
       if (!mounted) return;
       _showSuccess('역할이 변경되었습니다.');
       _loadParticipants(); // 목록 새로고침
     } on RoomServiceException catch (e) {
       if (!mounted) return;
       _showError('역할 변경 실패: ${e.message}');
     }
  }

  // ✨ 역할 업데이트 다이얼로그: Participant ID 입력받도록 수정
  void _showUpdateRoleDialog() {
    final participantIdController = TextEditingController(); // Participant ID 입력용
    final roleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('참여자 역할 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField( // Participant ID 입력 필드
                controller: participantIdController,
                keyboardType: TextInputType.number, // 숫자 입력
                decoration: const InputDecoration(labelText: 'Participant ID')), // 레이블 변경
            TextField( // 역할 입력 필드
                controller: roleController,
                decoration: const InputDecoration(labelText: '새 역할 (GM/PLAYER)')),
          ],
        ),
        actions: [
          TextButton(onPressed: Navigator.of(context).pop, child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              final idText = participantIdController.text.trim();
              final roleText = roleController.text.trim().toUpperCase(); // 역할은 대문자로
              final participantId = int.tryParse(idText); // int로 변환 시도

              if (participantId == null) { // 유효한 숫자인지 확인
                  _showError('유효한 Participant ID를 입력해주세요.');
                  return;
              }
              if (roleText != 'GM' && roleText != 'PLAYER') { // 역할 유효성 검사
                 _showError('역할은 GM 또는 PLAYER 여야 합니다.');
                 return;
              }
              Navigator.of(context).pop(); // 다이얼로그 닫기
              _updateParticipantRole(participantId, roleText); // 업데이트 함수 호출
            },
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }
  // --- ---

  // --- ✨ NPC 관련 UI 호출 함수 (Provider 활용, 변경 없음) ---
  void _showNpcListModal() { /* ... 이전 코드와 동일 ... */
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer<NpcProvider>(
          builder: (context, npcProvider, child) {
            final npcs = npcProvider.npcs;
            final isLoading = npcProvider.isLoading;
            final error = npcProvider.error;
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('NPC 목록'),
                  isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(icon: const Icon(Icons.refresh), tooltip: '새로고침',
                          onPressed: () => context.read<NpcProvider>().fetchNpcs()),
                ],
              ),
              content: SizedBox( /* ... ListView ... */
                 width: double.maxFinite,
                 child: error != null
                    ? Center(child: Text('오류: $error', style: const TextStyle(color: Colors.red)))
                    : npcs.isEmpty && !isLoading
                        ? const Center(child: Text('등록된 NPC가 없습니다.'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: npcs.length,
                            itemBuilder: (context, index) {
                              final npc = npcs[index];
                              return NpcListItem(
                                npc: npc,
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  _showNpcDetailModal(npc);
                                },
                              );
                            },
                          ),
              ),
              actions: [
                TextButton(onPressed: Navigator.of(dialogContext).pop, child: const Text('닫기')),
              ],
            );
          },
        );
      },
    );
  }
  void _showNpcDetailModal(Npc npc) { /* ... 이전 코드와 동일 ... */
    showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<NpcProvider>(),
        child: NpcDetailModal(npc: npc, isGm: _isCurrentUserGm),
      ),
    );
  }
  void _showCreateNpcModal() { /* ... 이전 코드와 동일 ... */
    if (!_isCurrentUserGm) {
      _showError('NPC 생성은 GM만 가능합니다.');
      return;
    }
    showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<NpcProvider>(),
        child: NpcCreateModal(roomId: _room.id!),
      ),
    );
  }
  // --- ✨ ---


  // === UI 빌드 ===
  @override
  Widget build(BuildContext context) {
    // ✨ NpcProvider 에러 상태 감시 및 SnackBar 표시
    final npcError = context.select((NpcProvider p) => p.error);
    if (npcError != null && ModalRoute.of(context)?.isCurrent == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
         _showError('NPC 오류: $npcError');
         context.read<NpcProvider>().clearError(); // 에러 메시지 클리어
      });
    }

    return Scaffold(
      key: _scaffoldKey,
      // --- ✨ AppBar: 기존 구조 유지 + NPC 버튼 추가 ---
      appBar: AppBar(
        title: Text(_room.name),
        backgroundColor: const Color(0xFF8C7853), // 테마 색상 적용
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(), // 뒤로가기
        ),
        actions: [
          // 주사위 버튼 (기존)
          IconButton(
            icon: const Icon(Icons.casino),
            tooltip: '주사위 굴리기',
            onPressed: () { /* ... */ },
          ),
          // ✨ NPC 목록 버튼 (추가됨)
          IconButton(
            icon: const Icon(Icons.book_outlined), // 아이콘 변경
            tooltip: 'NPC 목록',
            onPressed: _showNpcListModal, // NPC 목록 모달 호출
          ),
          // 참여자 목록 버튼 (기존)
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: '참여자 목록',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          // --- ✨ 방 관리 메뉴: ListTile title 수정 ---
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'leave': _showLeaveRoomDialog(); break;
                case 'delete': _showDeleteRoomDialog(); break;
                case 'transfer': _showTransferCreatorDialog(); break;
                case 'updateRole': _showUpdateRoleDialog(); break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'leave',
                child: ListTile(leading: Icon(Icons.exit_to_app), title: Text('방 나가기')),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(leading: Icon(Icons.delete_forever, color: Colors.red), title: Text('방 삭제', style: TextStyle(color: Colors.red))),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'transfer',
                child: ListTile(leading: Icon(Icons.person_pin_circle_outlined), title: Text('방장 위임')),
              ),
              const PopupMenuItem<String>(
                value: 'updateRole',
                child: ListTile(leading: Icon(Icons.admin_panel_settings_outlined), title: Text('참여자 역할 변경')),
              ),
            ],
          ),
          // --- ✨ ---
        ],
      ),
      // --- ✨ Body: Consumer 사용, VTT/채팅 영역 표시 (구현 필요) ---
      body: Consumer<NpcProvider>( // NpcProvider 상태 변화 감지
        builder: (context, npcProvider, child) {
          // 초기 로딩 시 (NPC 목록 비어있을 때만)
          if (npcProvider.isLoading && npcProvider.npcs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          // 여기에 VTT Canvas, 채팅 목록 등 실제 화면 구성
          return Stack(
            children: [
              // --- VTT Canvas 영역 (구현 필요) ---
              // Positioned.fill(child: VttCanvasWidget()), // VttCanvas 위젯
              const Center(child: Text('VTT Canvas 영역')), // 임시 텍스트

              // --- 채팅 UI 영역 (구현 필요) ---
              // Positioned(bottom: 0, left: 0, right: 0, child: ChatListWidget()),
            ],
          );
        }
      ),
      // --- ---
      // --- ✨ 참여자 Drawer: Participant.id, Participant.nickname 사용 ---
      endDrawer: Drawer(
        child: Column(
          children: [
            AppBar(title: const Text('참여자'), automaticallyImplyLeading: false, /* ... */ ),
            ListTile(
               title: const Text('참여자 목록'),
              trailing: _isParticipantsLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(icon: const Icon(Icons.refresh), tooltip: '새로고침', onPressed: _loadParticipants),
            ),
            Expanded( // 참여자 리스트
              child: _participants.isEmpty
                  ? const Center(child: Text('참여자가 없습니다.'))
                  : ListView.builder(
                      itemCount: _participants.length,
                      itemBuilder: (context, index) {
                        final p = _participants[index];
                        // ✨ 방장 ID와 Participant ID 비교 (Room.creatorId 타입 확인 필요)
                        final bool isCreator = _room.creatorId != null && p.id == _room.creatorId;
                        return ListTile(
                          // ✨ Participant.nickname 사용
                          leading: CircleAvatar(child: Text(p.nickname.isNotEmpty ? p.nickname[0].toUpperCase() : '?')),
                          title: Text(p.nickname),
                          // ✨ Participant.id 표시
                          subtitle: Text('ID: ${p.id} / Role: ${p.role}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [ // 방장/GM 아이콘
                              if (isCreator) const Tooltip(message: '방장', child: Icon(Icons.shield_moon_sharp, color: Colors.blue)),
                              if (p.role == 'GM') const Tooltip(message: 'GM', child: Icon(Icons.star, color: Colors.amber)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      // --- ✨ ---
      // --- ✨ 하단 바: BottomAppBar + 채팅 입력창 ---
      bottomNavigationBar: _buildBottomBar(),
      // --- ✨ GM 전용 NPC 생성 버튼 ---
      floatingActionButton: _isCurrentUserGm ? FloatingActionButton(
        onPressed: _showCreateNpcModal, // NPC 생성 모달 호출
        tooltip: 'NPC 생성',
        child: const Icon(Icons.add),
        backgroundColor: Colors.brown[700], // 색상 조정
      ) : null, // GM 아니면 숨김
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked, // 버튼 위치 조정
      // --- ✨ ---
    );
  }

  // 하단 바 (BottomAppBar + 채팅 입력)
  Widget _buildBottomBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(), // FAB 부분 홈 파기 (선택적)
      notchMargin: 6.0, // 홈 간격 (선택적)
      child: _buildBottomChatBar(),
    );
  }

  // 채팅 입력 바 (키보드 높이 감안)
  Widget _buildBottomChatBar() {
    return Container(
      padding: EdgeInsets.only(
         left: 12.0, right: 8.0, top: 4.0,
         bottom: MediaQuery.of(context).viewInsets.bottom + 4.0 // 키보드 패딩
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              decoration: const InputDecoration(
                hintText: '메시지 입력...',
                border: InputBorder.none,
                isDense: true, // 높이 줄이기
              ),
              onSubmitted: (_) => _handleSendChat(), // Enter로 전송
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            tooltip: '메시지 전송',
            onPressed: _handleSendChat, // 전송 버튼
          ),
        ],
      ),
    );
  }

  // 채팅 메시지 전송 핸들러 (임시)
  void _handleSendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return; // 빈 메시지 무시

    // TODO: 실제 ChatService와 연동하여 메시지 전송 로직 구현
    print('Sending chat message: $text'); // 디버그용 출력
    _chatController.clear(); // 입력창 비우기
    _showSuccess('메시지 전송됨 (구현 필요)'); // 임시 피드백
  }

  // 에러 메시지 표시 (SnackBar)
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar(); // 기존 스낵바 닫기
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  // 성공 메시지 표시 (SnackBar)
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
} // End of RoomScreenState