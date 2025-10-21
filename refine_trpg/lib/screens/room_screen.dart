// lib/screens/room_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../models/room.dart';
import '../models/character.dart';
import '../models/participant.dart';

import '../widgets/chat_bubble_widget.dart';

import '../routes.dart';
import '../services/navigation_service.dart';
import '../services/room_service.dart';
import '../services/chat_service.dart';
import '../services/character_service.dart';
import '../services/vtt_socket_service.dart';

import '../features/character_sheet/character_sheet_router.dart';
import '../features/character_sheet/systems.dart';
import '../features/vtt/vtt_canvas.dart';

import '../systems/core/dice.dart';
import '../systems/core/rules_engine.dart';
import '../systems/dnd5e/dnd5e_rules.dart';
import '../systems/coc7e/coc7e_rules.dart';

class RoomScreen extends StatefulWidget {
  final Room room;

  const RoomScreen({super.key, required this.room});

  static Widget byId({required String roomId}) {
    return FutureBuilder<Room>(
      future: RoomService.getRoom(roomId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('오류')),
            body: Center(
              child: Text('방을 불러올 수 없습니다: ${snapshot.error}'),
            ),
          );
        }

        return RoomScreen(room: snapshot.data!);
      },
    );
  }

  @override
  _RoomScreenState createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late Room _room;

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _msgScroll = ScrollController();

  // Feature Toggles
  bool isDicePanelOpen = false;
  Character? selectedCharacter;

  // Drawers
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Dice Panel
  final List<int> diceFaces = [2, 4, 6, 8, 10, 20, 100];
  Map<int, int> diceCounts = {
    for (var f in [2, 4, 6, 8, 10, 20, 100]) f: 0,
  };

  // TRPG System
  late final String systemId;
  late final TrpgRules rules;

  // Character Sheet
  late Map<String, TextEditingController> statControllers;
  late Map<String, TextEditingController> generalControllers;
  List<Character> _characters = [];
  final CharacterService _characterService = CharacterService();

  // Participants
  List<Participant> _participants = [];
  bool _isParticipantsLoading = false;
  Timer? _participantsRefreshTimer;
  bool _didConnect = false;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    systemId = _room.systemId;
    rules = _initializeRules(systemId);

    _initializeControllers();
    _loadCharacters();
    _loadParticipants();

    _participantsRefreshTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _loadParticipants());
    // Chat 서비스 및 VTT 소켓 연결 활성화
    // (Provider 의존 connect()는 build에서 트리거)
  }

  // --- Initializers ---
  TrpgRules _initializeRules(String systemId) {
    switch (systemId) {
      case 'dnd5e':
        return Dnd5eRules();
      case 'coc7e':
      default:
        return Coc7eRules();
    }
  }

  void _initializeControllers({Character? character}) {
    final defaults = character?.data ?? Systems.defaults(systemId);
    final generalData = defaults['general'] as Map<String, dynamic>? ?? {};
    final statsData = defaults['stats'] as Map<String, dynamic>? ?? {};

    final skillKeys = Systems.skillKeys(systemId);
    final generalKeys = Systems.generalKeys(systemId);

    statControllers = {
      for (final k in skillKeys)
        k: TextEditingController(
            text: '${statsData[k] ?? Systems.defaults(systemId)[k] ?? 0}'),
    };
    generalControllers = {
      for (final k in generalKeys)
        k: TextEditingController(
            text: '${generalData[k] ?? Systems.defaults(systemId)[k] ?? ''}'),
    };
  }

  // --- Data Loaders ---
  Future<void> _loadCharacters() async {
    try {
      final characters = await _characterService.getCharactersInRoom(_room.id!);
      if (mounted) {
        setState(() {
          _characters = characters;
        });
      }
    } catch (e) {
      _showError('캐릭터 목록 로딩 실패: $e');
    }
  }

  Future<void> _loadParticipants() async {
    if (_room.id == null) return;
    if (!mounted) return;

    setState(() => _isParticipantsLoading = true);
    try {
      final participants = await RoomService.getParticipants(_room.id!);
      if (mounted) {
        setState(() {
          _participants = participants;
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('참여자 목록을 불러올 수 없습니다.');
      }
    } finally {
      if (mounted) {
        setState(() => _isParticipantsLoading = false);
      }
    }
  }

  // --- Event Handlers ---
  void _handleSendChat(ChatService chat) {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    try {
      chat.sendMessage(text);
      _chatController.clear();
    } catch (e) {
      _showError('채팅 전송 실패: $e');
    }
  }

  void _handleRollDice() {
    final lines = <String>[];
    int totalAll = 0;

    diceCounts.forEach((face, count) {
      if (face <= 0 || count <= 0) return;
      final expr = '${count}d$face';
      final r = Dice.roll(expr);
      totalAll += r.total;
      lines.add('$expr: ${r.detail} = ${r.total}');
    });

    final msg = lines.isEmpty
        ? '주사위 선택이 없습니다.'
        : '[주사위]\n${lines.join('\n')}\n총합: $totalAll';

    // 주사위 굴림 결과 채팅 전송 기능 주석 처리
    /*
    try {
      Provider.of<ChatService>(context, listen: false).sendMessage(msg);
    } catch (e) {
      _showError('주사위 전송 실패: $e');
    }
    */

    setState(() {
      isDicePanelOpen = false;
      diceCounts = {for (var f in diceFaces) f: 0};
    });
  }

  void _handleAddCharacter() async {
    try {
      await _characterService.createCharacter(
        roomId: _room.id!,
        systemId: systemId,
        data: Systems.defaults(systemId),
        derived:
            rules.derive({'stats': Systems.defaults(systemId), 'general': {}}),
      );
      _showSuccess('새 캐릭터가 추가되었습니다!');
      _loadCharacters();
    } catch (e) {
      _showError('캐릭터 추가 실패: $e');
    }
  }

  void _handleSaveCharacter() async {
    if (selectedCharacter == null) return;

    final data = _collectCurrentData();
    final issues = rules.validate(data);
    if (issues.isNotEmpty) {
      _showError('저장 실패: ${issues.first.message}');
      return;
    }

    final derived = _deriveCurrent();

    try {
      await _characterService.updateCharacter(
        characterId: selectedCharacter!.id,
        data: data,
        derived: derived,
      );
      _showSuccess('저장 완료!');
      _loadCharacters();
      setState(() {
        selectedCharacter = null;
      });
    } catch (e) {
      _showError('저장 실패: $e');
    }
  }

  // --- 방 나가기 관련 메서드 ---
  Future<void> _leaveRoom() async {
    try {
      await RoomService.leaveRoom(_room.id!);
      if (!mounted) return;

      _showSuccess('방에서 나갔습니다.');
      NavigationService.pushAndRemoveUntil(Routes.main);
    } on RoomServiceException catch (e) {
      if (!mounted) return;

      if (e.statusCode == 403) {
        // 방장이라서 나갈 수 없는 경우
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('알림'),
            content:
                const Text('방장은 방을 나갈 수 없습니다.\n방을 삭제하거나 다른 사람에게 방장을 위임해주세요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      } else {
        _showError('방 나가기 실패: ${e.message}');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('예상치 못한 오류가 발생했습니다: $e');
    }
  }

  void _showLeaveRoomDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('방 나가기'),
          content: const Text('정말 이 방을 나가시겠습니까?'),
          actions: [
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('나가기', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _leaveRoom();
              },
            ),
          ],
        );
      },
    );
  }

  // --- 방 삭제 관련 메서드 ---
  Future<void> _deleteRoom() async {
    try {
      await RoomService.deleteRoom(_room.id!);
      if (!mounted) return;

      _showSuccess('방이 삭제되었습니다.');
      NavigationService.pushAndRemoveUntil(Routes.main);
    } on RoomServiceException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403) {
        _showError('방장만 방을 삭제할 수 있습니다.');
      } else {
        _showError('방 삭제 실패: ${e.message}');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('예상치 못한 오류가 발생했습니다: $e');
    }
  }

  void _showDeleteRoomDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('방 삭제'),
          content: const Text('정말로 이 방을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('삭제'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deleteRoom();
              },
            ),
          ],
        );
      },
    );
  }

  // --- UI Builders ---
  @override
  Widget build(BuildContext context) {

    final content = Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_room.name),
        backgroundColor: const Color(0xFF8C7853),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationService.goBack(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.casino),
            onPressed: () => setState(() => isDicePanelOpen = !isDicePanelOpen),
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          // --- 방 나가기 및 삭제를 위한 메뉴 버튼 ---
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'leave') {
                _showLeaveRoomDialog();
              } else if (value == 'delete') {
                _showDeleteRoomDialog();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'leave',
                child: ListTile(
                  leading: Icon(Icons.exit_to_app),
                  title: Text('방 나가기'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_forever, color: Colors.red),
                  title: Text('방 삭제', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Provider 준비 후 1회 연결 트리거
          Consumer2<ChatService, VttSocketService>(
            builder: (context, chat, vtt, _) {
              if (!_didConnect) {
                _didConnect = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  try { chat.connect(); } catch (_) {}
                  try { vtt.connect(); } catch (_) {}
                });
              }
              return const SizedBox.shrink();
            },
          ),
          // VTT 캔버스 표시
          Positioned.fill(
            child: VttCanvas(),
          ),
          if (selectedCharacter != null)
            Positioned(
              right: 16,
              top: 16,
              bottom: 16,
              width: 320,
              child: _buildCharacterSheet(),
            ),
          if (isDicePanelOpen)
            Positioned(
              top: 16,
              right: 16,
              child: _buildDicePanel(),
            ),
          // VTT 상태 배지 (활성/대기 표시)
          Positioned(
            top: 12,
            right: 12,
            child: Consumer<VttSocketService>(
              builder: (context, vtt, _) {
                final ready = vtt.scene != null; // 씬 수신 여부로 활성 판단
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: (ready ? Colors.green : Colors.orange).withOpacity(0.90),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(ready ? Icons.check_circle : Icons.hourglass_top,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          ready ? 'VTT 연결됨' : 'VTT 준비 중',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      endDrawer: _buildParticipantsDrawer(),
      bottomNavigationBar: _buildBottomChatBar(),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VttSocketService(_room.id!)),
        ChangeNotifierProvider(create: (_) => ChatService(_room.id!)),
      ],
      child: Builder(
        builder: (_) => content,
      ),
    );
  }

  Widget _buildCharacterSheet() {
    return Card(
      elevation: 8,
      child: CharacterSheetRouter(
        systemId: systemId,
        statControllers: statControllers,
        generalControllers: generalControllers,
        hp: int.tryParse(generalControllers['HP']?.text ?? '') ?? 0,
        mp: int.tryParse(generalControllers['MP']?.text ?? '') ?? 0,
        onClose: () => setState(() => selectedCharacter = null),
        onSave: _handleSaveCharacter,
      ),
    );
  }

  Widget _buildDicePanel() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('주사위 패널',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: diceFaces.map((face) {
                return GestureDetector(
                  onTap: () => setState(
                      () => diceCounts[face] = (diceCounts[face] ?? 0) + 1),
                  onSecondaryTap: () => setState(() =>
                      diceCounts[face] = max(0, (diceCounts[face] ?? 0) - 1)),
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border.all(),
                        borderRadius: BorderRadius.circular(8)),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text('d$face'),
                        if ((diceCounts[face] ?? 0) > 0)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: CircleAvatar(
                              radius: 10,
                              child: Text('${diceCounts[face]}',
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _handleRollDice,
              child: const Text('굴리기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsDrawer() {
    return Drawer(
      child: Column(
        children: [
          AppBar(
            title: const Text('참여자 및 캐릭터'),
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF5D4037),
          ),
          ListTile(
            title: const Text('참여자 목록'),
            trailing: _isParticipantsLoading
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator())
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadParticipants,
                  ),
          ),
          Expanded(
            flex: 1,
            child: ListView.builder(
              itemCount: _participants.length,
              itemBuilder: (context, index) {
                final p = _participants[index];
                // 👇 이 부분을 수정했습니다. .toString() 제거
                final isCreator =
                    _room.creator != null && p.userId == _room.creator!.id;

                return ListTile(
                  leading: CircleAvatar(child: Text(p.nickname[0])),
                  title: Text(p.nickname),
                  subtitle: Text(p.role),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCreator)
                        const Icon(Icons.shield_moon,
                            color: Colors.blue, size: 20), // 방장 아이콘
                      if (p.role == 'GM')
                        const Icon(Icons.star,
                            color: Colors.amber, size: 20), // GM 아이콘
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('캐릭터 목록'),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _handleAddCharacter,
            ),
          ),
          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: _characters.length,
              itemBuilder: (context, index) =>
                  _buildCharacterCard(_characters[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterCard(Character character) {
    final general = character.data['general'] as Map<String, dynamic>? ?? {};
    final name =
        general['name']?.isNotEmpty == true ? general['name'] : '이름 없음';
    final hp = general['HP'] ?? '-';
    final mp = general['MP'] ?? '-';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        subtitle: Text('HP: $hp / MP: $mp'),
        onTap: () {
          setState(() {
            selectedCharacter = character;
            _initializeControllers(character: character);
          });
          Navigator.pop(context); // Close drawer
        },
      ),
    );
  }

  void _showChatLog(ChatService chat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '채팅 로그',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  controller: ScrollController(),
                  itemCount: chat.messages.length,
                  itemBuilder: (context, i) {
                    final m = chat.messages[i];
                    return ChatBubbleWidget(
                      message: m.content,
                      playerName: m.sender,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomChatBar() {
    return Material(
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 100,
              child: Consumer<ChatService>(
                builder: (context, chat, child) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_msgScroll.hasClients) {
                      _msgScroll.jumpTo(_msgScroll.position.maxScrollExtent);
                    }
                  });
                  return ListView.builder(
                    controller: _msgScroll,
                    itemCount: chat.messages.length,
                    itemBuilder: (context, i) {
                      final m = chat.messages[i];
                      return ChatBubbleWidget(
                        message: m.content,
                        playerName: m.sender,
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),
            Consumer<ChatService>(
              builder: (context, chat, _) => Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      decoration: const InputDecoration(
                        hintText: '채팅을 입력하세요...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _handleSendChat(chat),
                    ),
                  ),
                  IconButton(
                    tooltip: '채팅 로그 보기',
                    icon: const Icon(Icons.keyboard_arrow_up),
                    onPressed: () => _showChatLog(chat),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => _handleSendChat(chat),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Utility Methods ---
  Map<String, dynamic> _collectCurrentData() {
    final stats = {
      for (final e in statControllers.entries)
        e.key: int.tryParse(e.value.text) ?? e.value.text,
    };
    final general = {
      for (final e in generalControllers.entries)
        e.key: int.tryParse(e.value.text) ?? e.value.text,
    };
    return {'stats': stats, 'general': general};
  }

  Map<String, dynamic> _deriveCurrent() {
    final d = rules.derive(_collectCurrentData());
    if (d['derived'] is Map) return Map<String, dynamic>.from(d['derived']);
    return Map<String, dynamic>.from(d);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  @override
  void dispose() {
    _participantsRefreshTimer?.cancel();
    _chatController.dispose();
    _msgScroll.dispose();

    for (final c in generalControllers.values) {
      c.dispose();
    }
    for (final c in statControllers.values) {
      c.dispose();
    }
    super.dispose();
  }
}
