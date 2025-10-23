// lib/screens/room_screen.dart
import 'dart:convert';
import 'dart:developer';
import 'dart:math' hide log;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

// --- Models ---
import '../models/room.dart';
import '../models/character.dart';
import '../models/participant.dart';
// import '../models/chat.dart';

// --- Widgets ---
import '../services/room/widgets/room_app_bar.dart';
import '../services/room/widgets/room_body_stack.dart';
import '../services/room/widgets/info_drawer.dart';
import '../services/room/widgets/chat_input_bar.dart';

// --- Services & Providers ---
import '../routes.dart';
import '../services/navigation_service.dart';
import '../services/room_service.dart';
import '../services/chat_service.dart';
import '../services/character_service.dart';
import '../services/vtt_socket_service.dart';
import '../providers/npc_provider.dart';

// --- TRPG Systems ---
import '../features/character_sheet/systems.dart';
import '../systems/core/dice.dart';
import '../systems/core/rules_engine.dart';
import '../systems/dnd5e/dnd5e_rules.dart';
import '../systems/coc7e/coc7e_rules.dart';

class RoomScreen extends StatefulWidget {
  final Room room;

  const RoomScreen({super.key, required this.room});

  // --- Static Factory Constructor ---
  static Widget byId({required String roomId}) {
    return FutureBuilder<Room>(
      future: RoomService.getRoom(roomId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(appBar: AppBar(title: const Text('오류')), body: Center(child: Text('방을 불러올 수 없습니다: ${snapshot.error}')));
        }
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => VttSocketService(snapshot.data!.id!)),
            ChangeNotifierProvider(create: (_) => ChatService(snapshot.data!.id!)),
            ChangeNotifierProvider(create: (_) => NpcProvider(snapshot.data!.id!)),
          ],
          child: RoomScreen(room: snapshot.data!),
        );
      },
    );
  }

  @override
  _RoomScreenState createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  // --- State Variables ---
  late Room _room;

  // UI Controllers / Keys
  final ScrollController _msgScroll = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Feature Toggles & State
  bool _isDicePanelOpen = false;
  Character? _selectedCharacter;

  // Dice Panel Data
  final List<int> _diceFaces = [2, 4, 6, 8, 10, 20, 100];
  Map<int, int> _diceCounts = { for (var f in [2, 4, 6, 8, 10, 20, 100]) f: 0 };

  // TRPG System Specifics
  late final String _systemId;
  late final TrpgRules _rules;

  // Character Sheet Data
  Map<String, TextEditingController> _statControllers = {};
  Map<String, TextEditingController> _generalControllers = {};
  List<Character> _characters = [];
  final CharacterService _characterService = CharacterService();

  // Participants Data
  List<Participant> _participants = [];
  bool _isParticipantsLoading = false;
  Timer? _participantsRefreshTimer;

  // Current User ID (Placeholder - 실제 구현 필요)
  String _currentUserId = "placeholder_user_id"; // <<< --- !!! IMPORTANT: REPLACE THIS !!! --- >>>

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _systemId = _room.systemId;
    _rules = _initializeRules(_systemId);

    _initializeControllers();
    _loadInitialData();
    _setupPeriodicRefresh();
    _connectServices();
    _setupChatScrollListener();

    // TODO: Fetch current user ID
  }

  @override
  void dispose() {
    _participantsRefreshTimer?.cancel();
    _msgScroll.dispose();
    _generalControllers.values.forEach((c) => c.dispose());
    _statControllers.values.forEach((c) => c.dispose());
    if (mounted) {
       try {
         Provider.of<ChatService>(context, listen: false).removeListener(_scrollToBottom);
       } catch (e) {
         debugPrint("Error removing ChatService listener: $e");
       }
    }
    super.dispose();
  }

  // --- Initialization Helper Methods ---

  void _loadInitialData() {
    _loadCharacters();
    _loadParticipants();
  }

  void _setupPeriodicRefresh() {
    _participantsRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadParticipants());
  }

  void _connectServices() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<ChatService>(context, listen: false).connect();
      Provider.of<VttSocketService>(context, listen: false).connect();
    });
  }

   void _setupChatScrollListener() {
     WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
           Provider.of<ChatService>(context, listen: false).addListener(_scrollToBottom);
        }
     });
   }

  TrpgRules _initializeRules(String systemId) {
    switch (systemId) {
      case 'dnd5e': return Dnd5eRules();
      case 'coc7e': default: return Coc7eRules();
    }
  }

  void _initializeControllers({Character? character}) {
    _generalControllers.values.forEach((controller) => controller.dispose());
    _statControllers.values.forEach((controller) => controller.dispose());
    _generalControllers.clear();
    _statControllers.clear();

    final sourceData = character?.data ?? {};
    final systemDefaults = Systems.defaults(_systemId);
    final generalData = (sourceData['general'] as Map<String, dynamic>?) ?? {};
    final statsData = (sourceData['stats'] as Map<String, dynamic>?) ?? {};
    final skillKeys = Systems.skillKeys(_systemId);
    final generalKeys = Systems.generalKeys(_systemId);

    _statControllers = { for (final k in skillKeys) k: TextEditingController(text: '${statsData[k] ?? systemDefaults[k] ?? 0}') };
    _generalControllers = { for (final k in generalKeys) k: TextEditingController(text: '${generalData[k] ?? systemDefaults[k] ?? ''}') };

    setState(() {});
  }

  // --- Data Loading Methods ---

  Future<void> _loadCharacters() async {
    if (_room.id == null) return;
    try {
      final characters = await _characterService.getCharactersInRoom(_room.id!);
      if (mounted) setState(() => _characters = characters);
    } catch (e) {
      if (mounted) _showError('캐릭터 목록 로딩 실패: $e');
    }
  }

  Future<void> _loadParticipants() async {
    if (_room.id == null || !mounted) return;
    setState(() => _isParticipantsLoading = true);
    try {
      final participants = await RoomService.getParticipants(_room.id!);
      if (mounted) setState(() => _participants = participants);
    } catch (e) {
      if (mounted) {
        if (e is RoomServiceException && e.statusCode == 404) {
          _showError('방을 찾을 수 없습니다.');
          NavigationService.pushAndRemoveUntil(Routes.main);
        } else {
          _showError('참여자 목록을 불러올 수 없습니다: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _isParticipantsLoading = false);
    }
  }

  // --- Event Handler Methods ---

  void _handleSendMessage(String text) {
    if (text.isEmpty || !mounted) return;
    try {
      Provider.of<ChatService>(context, listen: false).sendMessage(text);
    } catch (e) {
      _showError('채팅 전송 실패: $e');
    }
  }

  void _handleDiceCountChanged(int face, bool increment) {
     setState(() {
         int currentCount = _diceCounts[face] ?? 0;
         if (increment) {
             _diceCounts[face] = currentCount + 1;
         } else {
             _diceCounts[face] = max(0, currentCount - 1);
         }
     });
  }

  void _handleRollDice() {
    final lines = <String>[];
    int totalAll = 0;
    bool hasError = false;

    _diceCounts.forEach((face, count) {
      if (hasError || face <= 0 || count <= 0) return;
      final expr = '${count}d$face';
      try {
        final r = Dice.roll(expr);
        totalAll += r.total;
        lines.add('$expr: ${r.detail} = ${r.total}');
      } catch (e) {
        if (mounted) _showError('주사위 굴림 오류 ($expr): $e');
        hasError = true;
      }
    });

    if (!hasError) {
        if (lines.isNotEmpty) {
            final msg = '[주사위]\n${lines.join('\n')}\n총합: $totalAll';
            _handleSendMessage(msg);
        } else {
            if (mounted) _showError('굴릴 주사위가 선택되지 않았습니다.');
        }
    }

    setState(() {
      _isDicePanelOpen = false;
      _diceCounts = {for (var f in _diceFaces) f: 0};
    });
  }


  void _handleAddCharacter() async {
    if (_room.id == null) return;
    try {
      final initialData = Systems.defaults(_systemId);
      final dataForDerive = {
         'stats': (initialData['stats'] as Map<String, dynamic>?) ?? initialData,
         'general': (initialData['general'] as Map<String, dynamic>?) ?? {},
      };
      final derivedStats = _rules.derive(dataForDerive);
      await _characterService.createCharacter(roomId: _room.id!, systemId: _systemId, data: initialData, derived: derivedStats);
      if (mounted) _showSuccess('새 캐릭터가 추가되었습니다!');
      _loadCharacters();
    } catch (e) {
      if (mounted) _showError('캐릭터 추가 실패: $e');
    }
  }

  void _handleSaveCharacter() async {
    if (_selectedCharacter == null || !mounted) return;
    final data = _collectCurrentData();
    final derived = _deriveCurrent();
    try {
      await _characterService.updateCharacter(characterId: _selectedCharacter!.id, data: data, derived: derived);
      if (mounted) {
          _showSuccess('저장 완료!');
          _loadCharacters();
          setState(() => _selectedCharacter = null);
      }
    } catch (e) {
      if (mounted) _showError('저장 실패: $e');
    }
  }

  void _handleSelectCharacter(Character character) {
     _initializeControllers(character: character);
     setState(() {
        _selectedCharacter = character;
     });
     Navigator.pop(context);
  }


  // --- Room Management Handlers ---
  Future<void> _leaveRoom() async {
    if (_room.id == null) return;
    try {
      await RoomService.leaveRoom(_room.id!);
      if (!mounted) return;
      _showSuccess('방에서 나갔습니다.');
      NavigationService.pushAndRemoveUntil(Routes.main);
    } on RoomServiceException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403) _showLeaveCreatorErrorDialog();
      else _showError('방 나가기 실패: ${e.message}');
    } catch (e) {
      if (mounted) _showError('예상치 못한 오류가 발생했습니다: $e');
    }
  }

  Future<void> _deleteRoom() async {
    if (_room.id == null) return;
    try {
      await RoomService.deleteRoom(_room.id!);
      if (!mounted) return;
      _showSuccess('방이 삭제되었습니다.');
      NavigationService.pushAndRemoveUntil(Routes.main);
    } on RoomServiceException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403) _showError('방장만 방을 삭제할 수 있습니다.');
      else _showError('방 삭제 실패: ${e.message}');
    } catch (e) {
      if (mounted) _showError('예상치 못한 오류가 발생했습니다: $e');
    }
  }

  Future<void> _transferCreator(String newCreatorId) async {
    if (_room.id == null) return;
    try {
      await RoomService.transferCreator(_room.id!, newCreatorId);
      if (!mounted) return;
      _showSuccess('방장이 성공적으로 위임되었습니다.');
      await _loadParticipants();
      final updatedRoom = await RoomService.getRoom(_room.id!);
      if (mounted) setState(() => _room = updatedRoom);
    } on RoomServiceException catch (e) {
      if (mounted) _showError('방장 위임 실패: ${e.message}');
    } catch (e) {
      if (mounted) _showError('예상치 못한 오류 발생: $e');
    }
  }

  Future<void> _updateParticipantRole(String userId, String newRole) async {
    if (_room.id == null) return;
    try {
      await RoomService.updateParticipantRole(_room.id!, userId, newRole);
      if (!mounted) return;
      _showSuccess('참여자 역할이 성공적으로 변경되었습니다.');
      _loadParticipants();
    } on RoomServiceException catch (e) {
      if (mounted) _showError('역할 변경 실패: ${e.message}');
    } catch (e) {
      if (mounted) _showError('예상치 못한 오류 발생: $e');
    }
  }

  // --- 추방 관련 함수 제거됨 ---
  // Future<void> _kickParticipant(String targetUserId) async { ... }

  Future<void> _fetchAndLogRoomInfo() async {
    if (_room.id == null) return;
    try {
      final roomInfo = await RoomService.getRoom(_room.id!);
      log('--- 방 정보 ---');
      log('Room ID: ${roomInfo.id}');
      // ... (더 많은 정보 로깅)
      log('---------------');
      if (mounted) _showSuccess('방 정보를 콘솔에 출력했습니다.');
    } catch (e) {
      if (mounted) _showError('방 정보 조회 실패: $e');
    }
  }

  // --- Dialog Helper Methods ---
  void _showLeaveRoomDialog() {
     showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
         return AlertDialog(
          title: const Text('방 나가기'), content: const Text('정말 이 방을 나가시겠습니까?'),
          actions: [
            TextButton(child: const Text('취소'), onPressed: () => Navigator.of(dialogContext).pop()),
            TextButton(child: const Text('나가기', style: TextStyle(color: Colors.red)), onPressed: () { Navigator.of(dialogContext).pop(); _leaveRoom(); }),
          ],);
      });
  }
  void _showLeaveCreatorErrorDialog() {
     showDialog(context: context, builder: (context) => AlertDialog( title: const Text('알림'), content: const Text('방장은 방을 나갈 수 없습니다.\n방을 삭제하거나 다른 사람에게 방장을 위임해주세요.'), actions: [ TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('확인')), ], ), );
  }
  void _showDeleteRoomDialog() {
     showDialog(
       context: context,
       builder: (BuildContext dialogContext) {
         return AlertDialog(
          title: const Text('방 삭제'), content: const Text('정말로 이 방을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(child: const Text('취소'), onPressed: () => Navigator.of(dialogContext).pop()),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('삭제'), onPressed: () { Navigator.of(dialogContext).pop(); _deleteRoom(); }),
          ],);
       });
  }

  void _showTransferCreatorDialog() {
     final userIdController = TextEditingController(); final formKey = GlobalKey<FormState>();
     showDialog(context: context, builder: (context) { return AlertDialog( title: const Text('방장 위임'), content: Form(key: formKey, child: TextFormField(controller: userIdController, decoration: const InputDecoration(labelText: '새 방장의 User ID'), keyboardType: TextInputType.text, validator: (v) => (v == null || v.trim().isEmpty) ? 'User ID를 입력하세요.' : null)), actions: [ TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')), ElevatedButton(onPressed: () async { if (formKey.currentState!.validate()) { final id = userIdController.text.trim(); Navigator.of(context).pop(); await _transferCreator(id); } }, child: const Text('위임하기')), ], ); });
  }

  void _showUpdateRoleDialog() {
     final userIdController = TextEditingController(); final roleController = TextEditingController(); final formKey = GlobalKey<FormState>();
     showDialog( context: context, builder: (context) { return AlertDialog( title: const Text('참여자 역할 변경'), content: Form( key: formKey, child: Column( mainAxisSize: MainAxisSize.min, children: [ TextFormField(controller: userIdController, decoration: const InputDecoration(labelText: '대상 User ID'), keyboardType: TextInputType.text, validator: (v) => (v == null || v.trim().isEmpty) ? 'User ID를 입력하세요.' : null), TextFormField(controller: roleController, decoration: const InputDecoration(labelText: '새 역할 (GM 또는 PLAYER)'), validator: (v) { if (v == null || v.trim().isEmpty) return '역할을 입력하세요.'; final uv = v.trim().toUpperCase(); if (uv != 'GM' && uv != 'PLAYER') return '유효한 역할(GM 또는 PLAYER)만 가능합니다.'; return null; }), ], ), ), actions: [ TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')), ElevatedButton(onPressed: () async { if (formKey.currentState!.validate()) { final uid = userIdController.text.trim(); final role = roleController.text.trim().toUpperCase(); Navigator.of(context).pop(); await _updateParticipantRole(uid, role); } }, child: const Text('변경하기')), ], ); });
  }

   void _showUpdateRoleDialogForParticipant(Participant participant) {
     final roleController = TextEditingController(text: participant.role);
     final formKey = GlobalKey<FormState>();
     showDialog( context: context, builder: (context) { return AlertDialog( title: Text('${participant.nickname} 역할 변경'), content: Form( key: formKey, child: TextFormField( controller: roleController, decoration: const InputDecoration(labelText: '새 역할 (GM 또는 PLAYER)'), validator: (v) { if (v == null || v.trim().isEmpty) return '역할을 입력하세요.'; final uv = v.trim().toUpperCase(); if (uv != 'GM' && uv != 'PLAYER') return '유효한 역할(GM 또는 PLAYER)만 가능합니다.'; return null; }), ), actions: [ TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')), ElevatedButton(onPressed: () async { if (formKey.currentState!.validate()) { final role = roleController.text.trim().toUpperCase(); Navigator.of(context).pop(); await _updateParticipantRole(participant.userId, role); } }, child: const Text('변경하기')), ], ); });
   }

   // --- 추방 관련 다이얼로그 제거됨 ---
   // void _showKickParticipantDialog(Participant participant) { ... }

  // --- Utility Methods ---
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_msgScroll.hasClients) {
        _msgScroll.animateTo(_msgScroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Map<String, dynamic> _collectCurrentData() {
    final stats = <String, dynamic>{};
    final general = <String, dynamic>{};
    _statControllers.forEach((k, c) => stats[k] = _parseControllerValue(c.text));
    _generalControllers.forEach((k, c) => general[k] = _parseControllerValue(c.text));
    return {'stats': stats, 'general': general};
  }

  dynamic _parseControllerValue(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    final numValue = int.tryParse(trimmed);
    if (numValue != null) return numValue;
    if (trimmed.toLowerCase() == 'true') return true;
    if (trimmed.toLowerCase() == 'false') return false;
    return trimmed;
  }

  Map<String, dynamic> _deriveCurrent() {
    try {
      final data = _collectCurrentData();
      final derived = _rules.derive(data);
      if (derived['derived'] is Map) return Map<String, dynamic>.from(derived['derived']);
      return Map<String, dynamic>.from(derived);
    } catch (e) {
      debugPrint("Error deriving stats: $e");
      if (mounted) _showError("파생 능력치 계산 중 오류 발생: $e");
      return {};
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 3)));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final bool isCurrentUserCreator = _room.creator?.id == _currentUserId;

    return Scaffold(
      key: _scaffoldKey,
      appBar: RoomAppBar(
        room: _room,
        isCurrentUserCreator: isCurrentUserCreator,
        onDicePanelToggle: () => setState(() => _isDicePanelOpen = !_isDicePanelOpen),
        onDrawerOpen: () => _scaffoldKey.currentState?.openEndDrawer(),
        onMenuSelected: (value) {
           switch (value) {
             case 'leave': _showLeaveRoomDialog(); break;
             case 'delete': _showDeleteRoomDialog(); break;
             case 'transfer': _showTransferCreatorDialog(); break;
             case 'updateRole': _showUpdateRoleDialog(); break;
             case 'getInfo': _fetchAndLogRoomInfo(); break;
           }
        },
      ),
      body: RoomBodyStack(
         isDicePanelOpen: _isDicePanelOpen,
         selectedCharacter: _selectedCharacter,
         systemId: _systemId,
         statControllers: _statControllers,
         generalControllers: _generalControllers,
         diceFaces: _diceFaces,
         diceCounts: _diceCounts,
         onDiceCountChanged: _handleDiceCountChanged,
         onRollDice: _handleRollDice,
         onCloseCharacterSheet: () => setState(() => _selectedCharacter = null),
         onSaveCharacter: _handleSaveCharacter,
         chatScrollController: _msgScroll,
      ),
      endDrawer: InfoDrawer(
         room: _room,
         participants: _participants,
         isParticipantsLoading: _isParticipantsLoading,
         onLoadParticipants: _loadParticipants,
         characters: _characters,
         onAddCharacter: _handleAddCharacter,
         onSelectCharacter: _handleSelectCharacter,
         currentUserId: _currentUserId,
         isCurrentUserCreator: isCurrentUserCreator,
          showParticipantContextMenu: (participant) {
              Navigator.pop(context); // Drawer 닫기
               _showParticipantContextMenu(participant);
          },
      ),
      bottomNavigationBar: ChatInputBar(
        onSendMessage: _handleSendMessage,
      ),
    );
  }

  // --- 참여자 컨텍스트 메뉴 표시 (추방 메뉴 제거됨) ---
  void _showParticipantContextMenu(Participant participant) {
    showModalBottomSheet(
        context: context,
        builder: (context) {
            return Wrap(
                children: <Widget>[
                    ListTile(
                        leading: const Icon(Icons.admin_panel_settings),
                        title: Text('역할 변경 (${participant.nickname})'),
                        onTap: () {
                            Navigator.pop(context);
                             _showUpdateRoleDialogForParticipant(participant);
                        },
                    ),
                    // --- 추방 관련 ListTile 제거됨 ---
                ],
            );
        }
    );
 }

} // End of _RoomScreenState