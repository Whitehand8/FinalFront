// lib/screens/room_screen.dart
import 'dart:convert';
import 'dart:developer'; // Use dart:developer for log
import 'dart:math' hide log; // Avoid conflict with dart:developer log
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

// --- Models ---
import 'package:refine_trpg/models/room.dart';
import 'package:refine_trpg/models/character.dart';
import 'package:refine_trpg/models/participant.dart';
// import '../models/chat.dart'; // ChatMessage moved to chat_service.dart

// --- Widgets ---
import 'package:refine_trpg/services/room/widgets/room_app_bar.dart';
import 'package:refine_trpg/services/room/widgets/room_body_stack.dart';
import 'package:refine_trpg/services/room/widgets/info_drawer.dart';
import 'package:refine_trpg/services/room/widgets/chat_input_bar.dart';

// --- Services & Providers ---
import 'package:refine_trpg/routes.dart';
import 'package:refine_trpg/services/navigation_service.dart';
import 'package:refine_trpg/services/room_service.dart';
import 'package:refine_trpg/services/chat_service.dart';
import 'package:refine_trpg/services/character_service.dart'; // Import DTOs too
import 'package:refine_trpg/services/vtt_socket_service.dart';
import 'package:refine_trpg/providers/npc_provider.dart';
import 'package:refine_trpg/services/auth_service.dart'; // For fetching user ID

// --- TRPG Systems ---
import 'package:refine_trpg/features/character_sheet/systems.dart';
import 'package:refine_trpg/systems/core/dice.dart';
import 'package:refine_trpg/systems/core/rules_engine.dart';
import 'package:refine_trpg/systems/dnd5e/dnd5e_rules.dart';
import 'package:refine_trpg/systems/coc7e/coc7e_rules.dart';

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
        // Room ID null check
        final roomIdNonNull = snapshot.data!.id;
        if (roomIdNonNull == null) {
           return Scaffold(appBar: AppBar(title: const Text('오류')), body: const Center(child: Text('방 ID가 유효하지 않습니다.')));
        }
        return MultiProvider(
          providers: [
            // Use non-null room ID
            ChangeNotifierProvider(create: (_) => VttSocketService(roomIdNonNull)),
            ChangeNotifierProvider(create: (_) => ChatService(roomIdNonNull)),
            ChangeNotifierProvider(create: (_) => NpcProvider(roomIdNonNull)),
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
  List<Character> _characters = []; // 방 안의 '내' 캐릭터 또는 '볼 수 있는' 캐릭터 목록
  final CharacterService _characterService = CharacterService();
  bool _isCharacterListLoading = false; // <<< --- !!! 추가됨 !!! --- >>>

  // Participants Data
  List<Participant> _participants = [];
  bool _isParticipantsLoading = false;
  Timer? _participantsRefreshTimer;

  // Current User ID
  // [수정됨] 타입을 int?로 변경
  int? _currentUserId;
  // [추가됨] 현재 사용자의 이 방에서의 participantId
  int? _currentUserParticipantId;


  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _systemId = _room.systemId;
    _rules = _initializeRules(_systemId);

    _initializeControllers();
    _loadInitialData(); // [수정됨] 비동기 호출
    _setupPeriodicRefresh();
    _connectServices();
    _setupChatScrollListener();
  }

  @override
  void dispose() {
    _participantsRefreshTimer?.cancel();
    _msgScroll.dispose();
    _generalControllers.values.forEach((c) => c.dispose());
    _statControllers.values.forEach((c) => c.dispose());
    // [수정됨] mounted check and safe listener removal
    if (mounted) {
       try {
         // Use context.read for safety in dispose
         final chatService = context.read<ChatService?>();
         chatService?.removeListener(_scrollToBottom);
       } catch (e) {
         debugPrint("Error removing ChatService listener during dispose: $e");
       }
    }
    super.dispose();
  }

  // --- Initialization Helper Methods ---

  // [수정됨] 초기 데이터 로딩 순서 및 비동기 처리
  Future<void> _loadInitialData() async {
    // 1. 현재 사용자 ID 가져오기
    await _fetchCurrentUserId();
    if (!mounted) return; // 작업 중 위젯 unmount 방지

    // 2. 참가자 목록 로드
    await _loadParticipants();
     if (!mounted) return;

    // 3. 캐릭터 목록 로드
    await _loadCharactersForRoom();
     if (!mounted) return;
  }

  // [추가됨] 현재 사용자 ID 가져오는 로직 (AuthService 사용)
  Future<void> _fetchCurrentUserId() async {
    final token = await AuthService.getToken();
    int? fetchedUserId;
    if (token != null) {
      try {
        final payload = AuthService.parseJwt(token);
        // 백엔드 JWT payload의 사용자 ID 키 확인 (보통 'id' 또는 'sub')
        final userIdValue = payload['id'];
        if (userIdValue is int) {
          fetchedUserId = userIdValue;
        } else if (userIdValue is String) {
          fetchedUserId = int.tryParse(userIdValue);
        }
        log('Current User ID fetched: $fetchedUserId', name: 'RoomScreen'); // Use log from dart:developer
      } catch (e) {
        log('Error parsing token for user ID: $e', name: 'RoomScreen', error: e);
        if (mounted) _showError('사용자 인증 정보를 확인하는데 실패했습니다.');
        // Consider navigating to login screen
        // NavigationService.pushAndRemoveUntil(Routes.login);
      }
    } else {
      log('Authentication token not found.', name: 'RoomScreen');
      if (mounted) _showError('로그인이 필요합니다.');
      // Consider navigating to login screen
      // NavigationService.pushAndRemoveUntil(Routes.login);
    }

    if (mounted && _currentUserId != fetchedUserId) {
       setState(() {
          _currentUserId = fetchedUserId;
       });
    }
  }


  void _setupPeriodicRefresh() {
    // Refresh less often to reduce load
    _participantsRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) { // Check if mounted before loading
         _loadParticipants();
      } else {
         _participantsRefreshTimer?.cancel(); // Stop timer if not mounted
      }
    });
  }

  void _connectServices() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        Provider.of<ChatService>(context, listen: false).connect();
      } catch (e) {
        log("Error connecting ChatService: $e", name: "RoomScreen", error: e);
        if (mounted) _showError("채팅 서비스 연결 실패");
      }
      try {
        Provider.of<VttSocketService>(context, listen: false).connect();
      } catch (e) {
        log("Error connecting VttSocketService: $e", name: "RoomScreen", error: e);
        if (mounted) _showError("VTT 서비스 연결 실패");
      }
    });
  }

  void _setupChatScrollListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          Provider.of<ChatService>(context, listen: false).addListener(_scrollToBottom);
        } catch (e) {
          log("Error adding ChatService listener: $e", name: "RoomScreen", error: e);
        }
      }
    });
  }

  TrpgRules _initializeRules(String systemId) {
    switch (systemId) {
      case 'dnd5e': return Dnd5eRules();
      case 'coc7e': default: return Coc7eRules(); // Default to CoC 7th Ed.
    }
  }

  // Initialize controllers based on character data or system defaults
  void _initializeControllers({Character? character}) {
    // Dispose previous controllers safely
    _generalControllers.values.forEach((controller) => controller.dispose());
    _statControllers.values.forEach((controller) => controller.dispose());
    _generalControllers = {};
    _statControllers = {};

    // Use character.data if available, otherwise empty map
    final sourceData = character?.data ?? {};
    final systemDefaults = Systems.defaults(_systemId);
    final skillKeys = Systems.skillKeys(_systemId);
    final generalKeys = Systems.generalKeys(_systemId);

    // Initialize stat controllers
    _statControllers = {
      for (final k in skillKeys)
        k: TextEditingController(
            // Access data directly, fallback to defaults, then 0
            text: '${sourceData[k] ?? systemDefaults[k] ?? 0}')
    };

    // Initialize general controllers
    _generalControllers = {
      for (final k in generalKeys)
        k: TextEditingController(
            // Access data directly, fallback to defaults, then empty string
            text: '${sourceData[k] ?? systemDefaults[k] ?? ''}')
    };

    // Update the UI if controllers are initialized/re-initialized
    if (mounted) setState(() {});
  }


  // --- Data Loading Methods ---

  // [수정됨] Load character sheets based on participants
  Future<void> _loadCharactersForRoom() async {
    if (!mounted || _participants.isEmpty) {
      // Clear list if no participants or not mounted
      if (mounted) setState(() => _characters = []);
      return;
    }
    if (_isCharacterListLoading) return; // Prevent concurrent loading

    setState(() => _isCharacterListLoading = true);
    final loadedCharacters = <Character>[];
    log("Starting to load character sheets for ${_participants.length} participants.", name: "RoomScreen");

    try {
      for (final p in _participants) {
        if (!mounted) break; // Stop if unmounted during loop

        int? participantId;
        try {
          // ⚠️ 중요: Participant 모델의 Participant ID 필드를 사용해야 합니다.
          // 백엔드의 RoomParticipant entity에는 'id' (number)가 PK입니다.
          // Participant 모델에 이 'id' 필드가 'participantId' (int) 등으로 매핑되어야 합니다.
          // 임시로 p.userId를 파싱하여 사용하나, 모델 수정이 필요할 수 있습니다.
          // <<< --- !!! 실제 Participant ID 필드로 수정 필요 !!! --- >>>
          participantId = int.tryParse(p.userId); // 예: p.id 또는 p.participantId 사용 고려
          if (participantId == null) throw FormatException('Invalid ID format for ${p.nickname}');
        } catch (e) {
          log("Skipping character load for participant: Invalid ID or parsing error for ${p.nickname}. Error: $e", name: "RoomScreen", error: e);
          continue;
        }

        try {
          // Fetch sheet for the valid participantId
          log("Fetching character sheet for participant ID: $participantId (${p.nickname})...", name: "RoomScreen");
          final character = await _characterService.getCharacterSheet(participantId);
          loadedCharacters.add(character);
          log("Successfully loaded sheet for participant ID: $participantId", name: "RoomScreen");
        } on Exception catch (e) {
          // Handle specific errors like 404 Not Found gracefully
          if (e.toString().contains('Status 404')) {
            log('No character sheet found for participant ${p.nickname} (ID: $participantId).', name: "RoomScreen");
          } else { // Log other errors
            log('Error loading sheet for participant ${p.nickname} (ID: $participantId): $e', name: "RoomScreen", error: e);
            // Optionally show a non-blocking error to the user for individual failures
            // _showError('참가자 ${p.nickname}의 시트 로딩 실패');
          }
        }
      }
      // Update state only if mounted
      if (mounted) setState(() => _characters = loadedCharacters);
      log("Finished loading character sheets. Total loaded: ${loadedCharacters.length}", name: "RoomScreen");

    } catch (e) { // Catch errors during the overall process
      log('Error during overall character list loading: $e', name: "RoomScreen", error: e);
      if (mounted) _showError('캐릭터 목록 로딩 중 오류 발생');
    } finally {
      if (mounted) setState(() => _isCharacterListLoading = false);
    }
  }


  Future<void> _loadParticipants() async {
    if (_room.id == null || !mounted) return;
    // Prevent concurrent loading
    if (_isParticipantsLoading) return;

    setState(() => _isParticipantsLoading = true);
    log("Loading participants for room: ${_room.id}", name: "RoomScreen");
    try {
      final participants = await RoomService.getParticipants(_room.id!);
      if (mounted) {
         log("Participants loaded: ${participants.length}", name: "RoomScreen");
         setState(() => _participants = participants);
         // [추가됨] Update current user's participant ID after loading
         _updateCurrentUserParticipantId();
      }
    } catch (e) {
      log('Error loading participants: $e', name: "RoomScreen", error: e);
      if (mounted) {
        if (e is RoomServiceException && e.statusCode == 404) {
          _showError('방을 찾을 수 없습니다.');
          // Navigate out if room doesn't exist anymore
          NavigationService.pushAndRemoveUntil(Routes.main);
        } else {
          _showError('참여자 목록을 불러올 수 없습니다.');
        }
      }
    } finally {
      if (mounted) setState(() => _isParticipantsLoading = false);
    }
  }

  // [추가됨] Find and update the current user's participant ID
  void _updateCurrentUserParticipantId() {
    if (_currentUserId == null || _participants.isEmpty) {
      if (_currentUserParticipantId != null) {
        log("Clearing current user participant ID.", name: "RoomScreen");
        if(mounted) setState(() => _currentUserParticipantId = null);
      }
      return;
    }

    int? foundParticipantId;
    try {
      // ⚠️ 중요: Participant 모델의 User ID 필드(int 타입이어야 함)와 비교합니다.
      // 예: Participant 모델에 `final int userId;` 필드가 있다고 가정합니다.
      final currentParticipant = _participants.firstWhere(
        // <<< --- !!! 실제 User ID 필드로 수정 필요 !!! --- >>>
        (p) => int.tryParse(p.userId) == _currentUserId, // Compare integer User IDs
      );

      // ⚠️ 중요: Participant 모델의 Participant ID 필드(int 타입이어야 함)를 사용합니다.
      // 예: Participant 모델에 `final int id;` (Participant ID) 필드가 있다고 가정합니다.
      // <<< --- !!! 실제 Participant ID 필드로 수정 필요 !!! --- >>>
      foundParticipantId = int.tryParse(currentParticipant.userId); // 임시: userId를 Participant ID로 가정
      log("Current user's Participant ID found: $foundParticipantId", name: "RoomScreen");

    } catch (e) { // firstWhere throws if not found
      log("Could not find participant entry for current user ID: $_currentUserId. Error: $e", name: "RoomScreen");
      foundParticipantId = null;
    }

    // Update state only if the value changed
    if (mounted && _currentUserParticipantId != foundParticipantId) {
       setState(() {
         _currentUserParticipantId = foundParticipantId;
       });
    }
  }


  // --- Event Handler Methods ---

  void _handleSendMessage(String text) {
    if (text.trim().isEmpty || !mounted) return;
    try {
      Provider.of<ChatService>(context, listen: false).sendMessage(text.trim());
    } catch (e) {
      log("Error sending message: $e", name: "RoomScreen", error: e);
      _showError('채팅 메시지 전송 실패');
    }
  }

  void _handleDiceCountChanged(int face, bool increment) {
     if (!mounted) return;
     setState(() {
         int currentCount = _diceCounts[face] ?? 0;
         _diceCounts[face] = increment ? currentCount + 1 : max(0, currentCount - 1);
     });
  }

  void _handleRollDice() {
    if (!mounted) return;
    final lines = <String>[];
    int totalAll = 0;
    bool hasError = false;
    log("Rolling dice: $_diceCounts", name: "RoomScreen");

    _diceCounts.forEach((face, count) {
      if (hasError || face <= 0 || count <= 0) return;
      final expr = '${count}d$face';
      try {
        final r = Dice.roll(expr);
        totalAll += r.total;
        lines.add('$expr: ${r.detail} = ${r.total}');
      } catch (e) {
        log('Dice roll error ($expr): $e', name: "RoomScreen", error: e);
        if (mounted) _showError('주사위 굴림 오류 ($expr)');
        hasError = true;
      }
    });

    if (!hasError) {
        if (lines.isNotEmpty) {
            final msg = '[주사위]\n${lines.join('\n')}\n총합: $totalAll';
            log("Dice roll result: $msg", name: "RoomScreen");
            _handleSendMessage(msg); // Send result to chat
        } else {
            log("No dice selected to roll.", name: "RoomScreen");
            if (mounted) _showError('굴릴 주사위가 선택되지 않았습니다.');
        }
    }

    // Close panel and reset counts
    setState(() {
      _isDicePanelOpen = false;
      _diceCounts = {for (var f in _diceFaces) f: 0};
    });
  }


  // [수정됨] Use createCharacterSheet and participantId
  void _handleAddCharacter() async {
    if (!mounted) return;
    // Check if current user's participant ID is available
    if (_currentUserParticipantId == null) {
      _showError('캐릭터를 추가할 사용자 정보를 찾을 수 없습니다.');
      log("Attempted to add character but _currentUserParticipantId is null.", name: "RoomScreen");
      // Optionally try reloading participants again
      // await _loadParticipants();
      // if(_currentUserParticipantId == null) return;
      return;
    }

    log("Attempting to add character sheet for participant ID: $_currentUserParticipantId", name: "RoomScreen");
    try {
      final initialData = Systems.defaults(_systemId);
      // Derive stats if needed and include in initialData
      // final derivedStats = _rules.derive({'stats': initialData, 'general': {}});
      // initialData.addAll(derivedStats); // Example merge

      final createDto = CreateCharacterSheetDto(
        data: initialData,
        trpgType: _systemId,
      );

      // Call the updated service method
      await _characterService.createCharacterSheet(_currentUserParticipantId!, createDto);

      log("Character sheet added successfully for participant ID: $_currentUserParticipantId", name: "RoomScreen");
      if (mounted) _showSuccess('새 캐릭터 시트가 추가되었습니다!');
      _loadCharactersForRoom(); // Refresh character list

    } catch (e) {
      log('Failed to add character sheet: $e', name: "RoomScreen", error: e);
      if (mounted) {
         if (e.toString().contains('Status 409')) {
             _showError('이미 해당 참가자의 캐릭터 시트가 존재합니다.');
         } else {
             _showError('캐릭터 시트 추가 실패');
         }
      }
    }
  }

  // [수정됨] Use updateCharacterSheet and participantId
  void _handleSaveCharacter() async {
    if (_selectedCharacter == null || !mounted) return;

    final participantId = _selectedCharacter!.participantId; // Get participantId from selected character
    final currentData = _collectCurrentData(); // Collect data from controllers, merged with original
    log("Attempting to save character sheet for participant ID: $participantId", name: "RoomScreen");

    try {
      final updateDto = UpdateCharacterSheetDto(
        data: currentData,
        // Only GM can update isPublic, so don't send it unless GM logic is added
        // isPublic: _selectedCharacter?.isPublic
      );

      final updatedCharacter = await _characterService.updateCharacterSheet(participantId, updateDto);
      log("Character sheet saved successfully for participant ID: $participantId", name: "RoomScreen");

      if (mounted) {
        _showSuccess('저장 완료!');
        // Update local list efficiently or reload
        final index = _characters.indexWhere((c) => c.id == updatedCharacter.id);
        setState(() {
          if (index != -1) {
            _characters[index] = updatedCharacter; // Update in place
          } else {
            _characters.add(updatedCharacter); // Add if somehow missing (shouldn't happen)
          }
          _selectedCharacter = null; // Close the sheet overlay
          _initializeControllers(); // Reset controllers
        });
        // Or simply reload: await _loadCharactersForRoom();
      }
    } catch (e) {
      log('Failed to save character sheet: $e', name: "RoomScreen", error: e);
      if (mounted) _showError('캐릭터 시트 저장 실패');
    }
  }


  void _handleSelectCharacter(Character character) {
     if (!mounted) return;
     log("Selected character: ID ${character.id}, Participant ID ${character.participantId}", name: "RoomScreen");
     _initializeControllers(character: character); // Load data into controllers
     setState(() {
        _selectedCharacter = character; // Show the overlay
     });
     // Close the drawer after selection
     if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
       Navigator.pop(context);
     }
  }


  // --- Room Management Handlers ---
  Future<void> _leaveRoom() async {
    if (_room.id == null || !mounted) return;
    log("Attempting to leave room: ${_room.id}", name: "RoomScreen");
    try {
      await RoomService.leaveRoom(_room.id!);
      log("Left room successfully.", name: "RoomScreen");
      if (!mounted) return;
      _showSuccess('방에서 나갔습니다.');
      NavigationService.pushAndRemoveUntil(Routes.main); // Navigate to main screen
    } on RoomServiceException catch (e) {
      log('Failed to leave room: ${e.message}', name: "RoomScreen", error: e);
      if (!mounted) return;
      if (e.statusCode == 403) _showLeaveCreatorErrorDialog(); // Specific dialog for creator
      else _showError('방 나가기 실패: ${e.message}');
    } catch (e) {
      log('Unexpected error leaving room: $e', name: "RoomScreen", error: e);
      if (mounted) _showError('방 나가기 중 예상치 못한 오류 발생');
    }
  }

  Future<void> _deleteRoom() async {
    if (_room.id == null || !mounted) return;
    log("Attempting to delete room: ${_room.id}", name: "RoomScreen");
    try {
      await RoomService.deleteRoom(_room.id!);
      log("Deleted room successfully.", name: "RoomScreen");
      if (!mounted) return;
      _showSuccess('방이 삭제되었습니다.');
      NavigationService.pushAndRemoveUntil(Routes.main); // Navigate to main screen
    } on RoomServiceException catch (e) {
      log('Failed to delete room: ${e.message}', name: "RoomScreen", error: e);
      if (!mounted) return;
      if (e.statusCode == 403) _showError('방장만 방을 삭제할 수 있습니다.'); // Only creator can delete
      else _showError('방 삭제 실패: ${e.message}');
    } catch (e) {
      log('Unexpected error deleting room: $e', name: "RoomScreen", error: e);
      if (mounted) _showError('방 삭제 중 예상치 못한 오류 발생');
    }
  }

  // [수정됨] Expects User ID (int) for new creator
  Future<void> _transferCreator(int newCreatorUserId) async {
    if (_room.id == null || !mounted) return;
    log("Attempting to transfer creator to User ID: $newCreatorUserId", name: "RoomScreen");
    try {
      // Backend expects the User ID (int)
      await RoomService.transferCreator(_room.id!, newCreatorUserId);
      log("Transferred creator successfully.", name: "RoomScreen");
      if (!mounted) return;
      _showSuccess('방장이 성공적으로 위임되었습니다.');
      // Reload room details and participants to reflect changes
      await _loadParticipants(); // Updates participant roles/info
      final updatedRoom = await RoomService.getRoom(_room.id!); // Gets new creator info
      if (mounted) setState(() => _room = updatedRoom); // Update local room state
    } on RoomServiceException catch (e) {
      log('Failed to transfer creator: ${e.message}', name: "RoomScreen", error: e);
      if (mounted) _showError('방장 위임 실패: ${e.message}');
    } catch (e) {
      log('Unexpected error transferring creator: $e', name: "RoomScreen", error: e);
      if (mounted) _showError('방장 위임 중 예상치 못한 오류 발생');
    }
  }

  // [수정됨] Expects Participant ID (int)
  Future<void> _updateParticipantRole(int participantId, String newRole) async {
    if (_room.id == null || !mounted) return;
    log("Attempting to update role for Participant ID: $participantId to $newRole", name: "RoomScreen");
    try {
      // Backend expects Participant ID (int) and role string
      await RoomService.updateParticipantRole(_room.id!, participantId, newRole);
      log("Updated role successfully.", name: "RoomScreen");
      if (!mounted) return;
      _showSuccess('참여자 역할이 성공적으로 변경되었습니다.');
      _loadParticipants(); // Refresh participant list to show new role
    } on RoomServiceException catch (e) {
      log('Failed to update role: ${e.message}', name: "RoomScreen", error: e);
      if (mounted) _showError('역할 변경 실패: ${e.message}');
    } catch (e) {
      log('Unexpected error updating role: $e', name: "RoomScreen", error: e);
      if (mounted) _showError('역할 변경 중 예상치 못한 오류 발생');
    }
  }


  // --- 추방 관련 함수 제거됨 ---

  Future<void> _fetchAndLogRoomInfo() async {
    if (_room.id == null || !mounted) return;
    log("Fetching room info for: ${_room.id}", name: "RoomScreen");
    try {
      final roomInfo = await RoomService.getRoom(_room.id!);
      log('--- Room Info ---', name: "RoomScreen");
      log('ID: ${roomInfo.id}', name: "RoomScreen");
      log('Name: ${roomInfo.name}', name: "RoomScreen");
      log('Max Participants: ${roomInfo.maxParticipants}', name: "RoomScreen");
      log('Current Participants: ${roomInfo.currentParticipants}', name: "RoomScreen");
      log('System ID: ${roomInfo.systemId}', name: "RoomScreen");
      log('Creator: ${roomInfo.creator?.nickname} (User ID: ${roomInfo.creator?.id})', name: "RoomScreen");
      log('Participants:', name: "RoomScreen");
      for (var p in roomInfo.participants) {
         // ⚠️ 중요: Participant 모델에 participantId('id') 와 userId('user'.'id') 가 구분되어야 함
         // <<< --- !!! Participant 모델 확인 후 실제 Participant ID와 User ID 필드로 수정 !!! --- >>>
         log(' - Nick: ${p.nickname} (P.ID: ${p.userId}, Role: ${p.role})', name: "RoomScreen"); // 임시: userId를 Participant ID로 사용
      }
      log('---------------', name: "RoomScreen");
      if (mounted) _showSuccess('방 정보를 콘솔에 출력했습니다.');
    } catch (e) {
      log('Failed to fetch room info: $e', name: "RoomScreen", error: e);
      if (mounted) _showError('방 정보 조회 실패');
    }
  }

  // --- Dialog Helper Methods ---
  void _showLeaveRoomDialog() {
     if (!mounted) return;
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
     if (!mounted) return;
     showDialog(context: context, builder: (context) => AlertDialog( title: const Text('알림'), content: const Text('방장은 방을 나갈 수 없습니다.\n방을 삭제하거나 다른 사람에게 방장을 위임해주세요.'), actions: [ TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('확인')), ], ), );
  }
  void _showDeleteRoomDialog() {
     if (!mounted) return;
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

  // [수정됨] Input asks for User ID (int)
  void _showTransferCreatorDialog() {
     if (!mounted) return;
     final userIdController = TextEditingController();
     final formKey = GlobalKey<FormState>();
     showDialog(
       context: context,
       builder: (BuildContext dialogContext) {
         return AlertDialog(
          title: const Text('방장 위임'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: userIdController,
              decoration: const InputDecoration(labelText: '새 방장의 User ID', hintText: '숫자 ID 입력'),
              keyboardType: TextInputType.number, // Ensure numeric input
              validator: (v) {
                 if (v == null || v.trim().isEmpty) return 'User ID를 입력하세요.';
                 if (int.tryParse(v.trim()) == null) return '유효한 숫자 User ID를 입력하세요.';
                 return null;
              }
            )
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                 if (formKey.currentState!.validate()) {
                    final idStr = userIdController.text.trim();
                    final int? newCreatorUserId = int.tryParse(idStr); // Parse to int
                    Navigator.of(dialogContext).pop(); // Close dialog first
                    if (newCreatorUserId != null) {
                       await _transferCreator(newCreatorUserId); // Call with int
                    } else {
                       // This case should ideally be caught by validation
                       _showError('잘못된 User ID 형식입니다.');
                    }
                 }
              },
              child: const Text('위임하기')
            ),
          ],
         );
       }
     );
  }

  // [수정됨] Input asks for Participant ID (int)
  void _showUpdateRoleDialog() {
     if (!mounted) return;
     final participantIdController = TextEditingController();
     final roleController = TextEditingController();
     final formKey = GlobalKey<FormState>();
     showDialog(
       context: context,
       builder: (BuildContext dialogContext) {
         return AlertDialog(
          title: const Text('참여자 역할 변경'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: participantIdController,
                  decoration: const InputDecoration(labelText: '대상 Participant ID', hintText: '숫자 ID 입력'), // Clarify ID type
                  keyboardType: TextInputType.number, // Ensure numeric input
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Participant ID를 입력하세요.';
                    if (int.tryParse(v.trim()) == null) return '유효한 숫자 Participant ID를 입력하세요.';
                    return null;
                  }
                ),
                TextFormField(
                  controller: roleController,
                  decoration: const InputDecoration(labelText: '새 역할 (GM 또는 PLAYER)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '역할을 입력하세요.';
                    final uv = v.trim().toUpperCase();
                    if (uv != 'GM' && uv != 'PLAYER') return '유효한 역할(GM 또는 PLAYER)만 가능합니다.';
                    return null;
                  }
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                 if (formKey.currentState!.validate()) {
                    final pidStr = participantIdController.text.trim();
                    final int? participantId = int.tryParse(pidStr); // Parse to int
                    final role = roleController.text.trim().toUpperCase();
                    Navigator.of(dialogContext).pop(); // Close dialog first
                    if (participantId != null) {
                       await _updateParticipantRole(participantId, role); // Call with int
                    } else {
                        // Should be caught by validation
                       _showError('잘못된 Participant ID 형식입니다.');
                    }
                 }
              },
              child: const Text('변경하기')
            ),
          ],
         );
       }
     );
   }

   // [수정됨] Use participant's actual Participant ID (int)
   void _showUpdateRoleDialogForParticipant(Participant participant) {
     if (!mounted) return;

     // ⚠️ 중요: Participant 모델에서 Participant ID (int)를 가져옵니다.
     // 예: final int? participantId = participant.id; (모델 구조에 따라 필드명 확인)
     // <<< --- !!! 실제 Participant ID 필드로 수정 필요 !!! --- >>>
     final int? participantId = int.tryParse(participant.userId); // 임시: userId 파싱

     if (participantId == null) {
         _showError('선택된 참가자의 ID가 유효하지 않습니다.');
         return;
     }

     final roleController = TextEditingController(text: participant.role);
     final formKey = GlobalKey<FormState>();
     showDialog(
       context: context,
       builder: (BuildContext dialogContext) {
         return AlertDialog(
          title: Text('${participant.nickname} 역할 변경'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: roleController,
              decoration: const InputDecoration(labelText: '새 역할 (GM 또는 PLAYER)'),
              validator: (v) {
                 if (v == null || v.trim().isEmpty) return '역할을 입력하세요.';
                 final uv = v.trim().toUpperCase();
                 if (uv != 'GM' && uv != 'PLAYER') return '유효한 역할(GM 또는 PLAYER)만 가능합니다.';
                 return null;
              }
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                 if (formKey.currentState!.validate()) {
                    final role = roleController.text.trim().toUpperCase();
                    Navigator.of(dialogContext).pop(); // Close dialog first
                    await _updateParticipantRole(participantId, role); // Pass the int ID
                 }
              },
              child: const Text('변경하기')
            ),
          ],
         );
       }
     );
   }

   // --- 추방 관련 다이얼로그 제거됨 ---

  // --- Utility Methods ---
  void _scrollToBottom() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_msgScroll.hasClients) {
        _msgScroll.animateTo(
          _msgScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut);
      }
    });
  }

  // [수정됨] Collect data, merging with original data
  Map<String, dynamic> _collectCurrentData() {
    if (_selectedCharacter == null) return {}; // No character selected

    final Map<String, dynamic> collectedData = {};
    _statControllers.forEach((key, controller) {
      collectedData[key] = _parseControllerValue(controller.text);
    });
    _generalControllers.forEach((key, controller) {
      collectedData[key] = _parseControllerValue(controller.text);
    });

    // Start with original data and overwrite with controller values
    final originalData = Map<String, dynamic>.from(_selectedCharacter!.data);
    originalData.addAll(collectedData); // Merge, collectedData overwrites

    return originalData;
  }

  // Value parser (handles int, double, bool, string)
  dynamic _parseControllerValue(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return ''; // Or null, depending on backend expectation
    final intValue = int.tryParse(trimmed);
    if (intValue != null) return intValue;
    final doubleValue = double.tryParse(trimmed);
    if (doubleValue != null) return doubleValue;
    if (trimmed.toLowerCase() == 'true') return true;
    if (trimmed.toLowerCase() == 'false') return false;
    return trimmed; // Default to string
  }

  // [삭제됨] _deriveCurrent method
  // Map<String, dynamic> _deriveCurrent() { ... }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3)));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2)));
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    // [수정됨] Compare integer User IDs for creator check
    final bool isCurrentUserCreator = _currentUserId != null && _room.creator?.id == _currentUserId.toString(); // creator ID is string in model

    return Scaffold(
      key: _scaffoldKey,
      appBar: RoomAppBar(
        room: _room,
        isCurrentUserCreator: isCurrentUserCreator,
        onDicePanelToggle: () => setState(() => _isDicePanelOpen = !_isDicePanelOpen),
        onDrawerOpen: () => _scaffoldKey.currentState?.openEndDrawer(),
        onMenuSelected: (value) {
           if (!mounted) return; // Prevent actions if not mounted
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
         // [삭제됨] systemId is no longer passed here
         statControllers: _statControllers,
         generalControllers: _generalControllers,
         diceFaces: _diceFaces,
         diceCounts: _diceCounts,
         onDiceCountChanged: _handleDiceCountChanged,
         onRollDice: _handleRollDice,
         onCloseCharacterSheet: () {
            if (mounted) {
              setState(() => _selectedCharacter = null);
              _initializeControllers(); // Reset controllers when closing
            }
         },
         onSaveCharacter: _handleSaveCharacter,
         chatScrollController: _msgScroll,
         // Pass potentially needed data to RoomBodyStack if required there
         // participants: _participants,
         // currentUserId: _currentUserId,
      ),
      endDrawer: InfoDrawer(
         room: _room,
         participants: _participants,
         isParticipantsLoading: _isParticipantsLoading,
         onLoadParticipants: _loadParticipants, // Allow manual refresh from drawer
         characters: _characters,
         isCharacterListLoading: _isCharacterListLoading, // Pass loading state
         onAddCharacter: _handleAddCharacter,
         onSelectCharacter: _handleSelectCharacter,
         // [수정됨] Pass int? type
         currentUserId: _currentUserId,
         isCurrentUserCreator: isCurrentUserCreator,
         showParticipantContextMenu: (participant) {
              // Close drawer before showing context menu
              if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
                 Navigator.pop(context); // Close Drawer
              }
               _showParticipantContextMenu(participant); // Show context menu
          },
      ),
      bottomNavigationBar: ChatInputBar(
        onSendMessage: _handleSendMessage,
      ),
    );
  }

  // --- 참여자 컨텍스트 메뉴 표시 (추방 메뉴 제거됨) ---
  void _showParticipantContextMenu(Participant participant) {
    if (!mounted) return;

    // [수정됨] Compare integer User IDs for creator check
    final bool isCurrentUserCreator = _currentUserId != null && _room.creator?.id == _currentUserId.toString();

    // Only allow role changes if the current user is the creator
    if (!isCurrentUserCreator) {
        _showError("방장만 역할을 변경할 수 있습니다.");
        return;
     }

    showModalBottomSheet(
        context: context,
        isScrollControlled: true, // Needed if keyboard appears
        builder: (modalContext) { // Use modalContext to avoid issues
            return Padding(
              // Adjust padding for keyboard if necessary
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom),
              child: Wrap(
                  children: <Widget>[
                      ListTile(
                          leading: const Icon(Icons.admin_panel_settings_outlined),
                          title: Text('역할 변경 (${participant.nickname})'),
                          onTap: () {
                              Navigator.pop(modalContext); // Close bottom sheet
                              // Show dialog to update role for this participant
                              _showUpdateRoleDialogForParticipant(participant);
                          },
                      ),
                      // --- 추방 관련 ListTile 제거됨 ---
                  ],
              ),
            );
        }
    );
 }

} // End of _RoomScreenState