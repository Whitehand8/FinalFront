import 'dart:math';
import 'package:flutter/material.dart';
import '../models/room.dart';
import '../services/chat_service.dart';
import '../models/chat.dart';
import '../features/character_sheet/character_sheet_router.dart';
import '../widgets/chat_bubble_widget.dart';
import '../features/character_sheet/systems.dart';
import '../systems/core/dice.dart';
import '../systems/core/rules_engine.dart';
import '../systems/dnd5e/dnd5e_rules.dart';
import '../systems/coc7e/coc7e_rules.dart';

class RoomScreen extends StatefulWidget {
  static const String routeName = '/room';
  final Room room;
  const RoomScreen({super.key, required this.room});

  @override
  _RoomScreenState createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late Room _room;

  late final ChatService _chatService;
  late final String _playerName;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _chatController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _msgScroll = ScrollController();

  // 사이드 패널 상태
  int? selectedCharacterIndex;
  bool isRightDrawerOpen = false;
  bool isLeftDrawerOpen = false;
  bool isDicePanelOpen = false;

  // 주사위 패널
  final List<int> diceFaces = [2, 4, 6, 8, 10, 20, 100];
  Map<int, int> diceCounts = {
    for (var f in [2, 4, 6, 8, 10, 20, 100]) f: 0,
    -1: 0, // 보너스/기타 슬롯 (현재는 미사용)
  };

  // 시스템 라우팅용 ID (Room에서 가져오되 없으면 coc7e)
  late final String systemId;
  late final TrpgRules rules;

  // 시스템 정의를 기반으로 동적으로 만드는 컨트롤러들
  late Map<String, TextEditingController> statControllers; // 스킬/특성치
  late Map<String, TextEditingController> generalControllers; // 이름/직업 등

  @override
  void initState() {
    super.initState();
    _playerName = '플레이어';
    // 단순화: widget.room만 사용
    _room = widget.room; // ← late Room이므로 non-null 보장

    systemId = 'coc7e'; // ← 임시
    rules = systemId == 'dnd5e' ? Dnd5eRules() : Coc7eRules();

    // systems 레지스트리에서 정의(키 목록 & 기본값) 가져오기
    final defaults = Systems.defaults(systemId) ?? const <String, dynamic>{};

    // 시스템별 표시 필드 키
    final skillKeys = Systems.skillKeys(systemId) ?? const <String>[];
    final generalKeys = Systems.generalKeys(systemId) ?? const <String>[];

    // 컨트롤러 생성 (기본값 텍스트 적용)
    statControllers = {
      for (final k in skillKeys)
        k: TextEditingController(text: '${defaults[k] ?? 0}'),
    };
    generalControllers = {
      for (final k in generalKeys)
        k: TextEditingController(text: '${defaults[k] ?? ''}'),
    };
  }

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
    // 일부 룰은 {derived:{...}} 형태를 반환할 수 있어 평탄화 처리
    if (d['derived'] is Map) return Map<String, dynamic>.from(d['derived']);
    return Map<String, dynamic>.from(d);
  }

  void _handleSendClick() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('채팅 기능은 현재 비활성화되어 있습니다.')));
    _chatController.clear(); // 입력창 비우기
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: [
          // === VTT 캔버스: 맨 아래 레이어 (배경/마커) ===
          Positioned.fill(
            child: Container(
              color: Colors.grey[100],
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'VTT 기능은 현재 비활성화되어 있습니다.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 좌측 핸들
          Positioned(
            left: 0,
            top: screenHeight * 0.5,
            child: Builder(
              builder: (innerContext) => _buildDrawerHandle(
                onTap: () => setState(() => isLeftDrawerOpen = true),
                icon: Icons.menu,
              ),
            ),
          ),

          // 우측 핸들
          Positioned(
            right: 0,
            top: screenHeight * 0.5,
            child: Visibility(
              visible: !isRightDrawerOpen,
              child: _buildDrawerHandle(
                onTap: () => setState(() => isRightDrawerOpen = true),
                icon: Icons.menu_open,
              ),
            ),
          ),

          // 좌측 Drawer
          if (isLeftDrawerOpen)
            Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 300,
                  child: _buildLeftDrawer(),
                ),
                Positioned(
                  left: 300,
                  top: MediaQuery.of(context).size.height * 0.5 - 40,
                  child: GestureDetector(
                    onTap: () => setState(() => isLeftDrawerOpen = false),
                    child: Container(
                      width: 40,
                      height: 80,
                      color: Colors.black.withAlpha((0.1 * 255).round()),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),

          // 우측 Drawer
          if (isRightDrawerOpen)
            Stack(
              children: [
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 300,
                  child: _buildRightDrawer(context),
                ),
                Positioned(
                  right: 300,
                  top: MediaQuery.of(context).size.height * 0.5 - 40,
                  child: GestureDetector(
                    onTap: () => setState(() => isRightDrawerOpen = false),
                    child: Container(
                      width: 40,
                      height: 80,
                      color: Colors.black.withAlpha((0.1 * 255).round()),
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),

          // 파생치 요약 배지 (룰별로 핵심만 표시)
          Positioned(
            left: 16,
            top: 40,
            child: Builder(
              builder: (context) {
                final derived = _deriveCurrent();
                List<Widget> chips = [];
                if (systemId == 'dnd5e') {
                  final prof = derived['proficiency'];
                  final mods = derived['mods'];
                  chips.add(Chip(label: Text('PROF +${prof ?? '-'}')));
                  if (mods is Map && mods['DEX'] != null) {
                    chips.add(Chip(label: Text('DEX mod ${mods['DEX']}')));
                  }
                } else if (systemId == 'coc7e') {
                  final hp = derived['hp'] ?? derived['maxHp'];
                  final mp = derived['mp'] ?? derived['maxMp'];
                  final san = derived['SAN'];
                  final mov = derived['MOV'];
                  final db = derived['DB'];
                  if (hp != null) chips.add(Chip(label: Text('HP $hp')));
                  if (mp != null) chips.add(Chip(label: Text('MP $mp')));
                  if (san != null) chips.add(Chip(label: Text('SAN $san')));
                  if (mov != null) chips.add(Chip(label: Text('MOV $mov')));
                  if (db != null) chips.add(Chip(label: Text('DB $db')));
                }
                if (chips.isEmpty) return const SizedBox.shrink();
                return Wrap(spacing: 8, children: chips);
              },
            ),
          ),
          // 캐릭터 시트 (시스템 라우터)
          if (selectedCharacterIndex != null)
            Positioned(
              right: 300,
              top: 100,
              child: SizedBox(
                height: 500,
                width: 280,
                child: SingleChildScrollView(
                  child: CharacterSheetRouter(
                    systemId: systemId, // ⬅️ 룰북 시스템 적용 (coc7e/dnd5e 등)
                    statControllers: statControllers, // systems에서 생성한 컨트롤러
                    generalControllers:
                        generalControllers, // systems에서 생성한 컨트롤러
                    hp: int.tryParse(generalControllers['HP']?.text ?? '') ??
                        11, // 규칙에 따라 가져오거나 기본값
                    mp: int.tryParse(generalControllers['MP']?.text ?? '') ??
                        4, // 규칙에 따라 가져오거나 기본값
                    onClose: () =>
                        setState(() => selectedCharacterIndex = null),
                    onSave: _saveCharacter,
                  ),
                ),
              ),
            ),

          // 주사위 패널
          if (isDicePanelOpen)
            Positioned(
              right: 300,
              top: 100,
              child: SizedBox(
                width: 300,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '주사위 패널',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          children: diceFaces.map((face) {
                            return GestureDetector(
                              onTap: () => setState(
                                () => diceCounts[face] = diceCounts[face]! + 1,
                              ),
                              onSecondaryTap: () => setState(
                                () => diceCounts[face] = max(
                                  0,
                                  diceCounts[face]! - 1,
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text('d$face'),
                                    if (diceCounts[face]! > 0)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: CircleAvatar(
                                          radius: 10,
                                          child: Text(
                                            '${diceCounts[face]}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
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
                          onPressed: () async {
                            final lines = <String>[];
                            int totalAll = 0;

                            diceCounts.forEach((face, count) {
                              if (face <= 0 || count <= 0) return; // -1 등 무시
                              final expr = '${count}d$face';
                              final r = Dice.roll(expr);
                              totalAll += r.total;
                              // r.detail이 각 개별 주사위 눈 정보를 포함한다고 가정
                              lines.add('$expr: ${r.detail} = ${r.total}');
                            });

                            final msg = lines.isEmpty
                                ? '주사위 선택이 없습니다.'
                                : '[주사위]\n${lines.join('\n')}\n총합: $totalAll';

                            try {
                              await _chatService.sendChatMessage(
                                _room.id ?? '',
                                _playerName,
                                msg,
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('주사위 전송 실패: $e')),
                              );
                            }

                            setState(() {
                              isDicePanelOpen = false;
                              diceCounts = {
                                for (var f in diceFaces) f: 0,
                                -1: 0,
                              };
                            });
                          },
                          child: const Text('굴리기'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 하단 채팅 입력 영역 (VTT 위에 얹히지만 포인터 방해 없음)
          Column(
            children: [
              // 가운데 빈 레이어가 포인터를 막지 않도록 IgnorePointer 처리
              Expanded(
                child: IgnorePointer(
                  ignoring: true,
                  child: const SizedBox.expand(),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                color: const Color(0xFFF0F0F0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        decoration: InputDecoration(
                          hintText: '채팅을 입력하기...',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _handleSendClick(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _openChatPanel,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade700,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.chat_bubble,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => setState(() => isDicePanelOpen = true),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade700,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.casino,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _handleSendClick,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade700,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openChatPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final height = MediaQuery.of(context).size.height * 0.65;
        return SizedBox(
          height: height,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '채팅',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Divider(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: _msgScroll,
                  itemCount: _messages.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemBuilder: (context, i) {
                    final m = _messages[i];
                    return ChatBubbleWidget(
                      message: m.content,
                      playerName: _playerName,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 좌측 Drawer (NPC/오브젝트 추가)
  Widget _buildLeftDrawer() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('NPC 추가'),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Center(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('오브젝트 추가하기'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 우측 Drawer (캐릭터 관리)
  Widget _buildRightDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // 캐릭터 추가 버튼
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => _addCharacter(context),
              icon: const Icon(Icons.add),
              label: const Text('캐릭터 추가'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
          const Divider(height: 1),
          // 캐릭터 리스트 (스크롤 가능)
          Expanded(
            child: ListView.builder(
              itemCount: 3, // TODO: 실제 캐릭터 수
              itemBuilder: (context, index) => _buildCharacterCard(index),
            ),
          ),
        ],
      ),
    );
  }

  // 캐릭터 카드 위젯
  Widget _buildCharacterCard(int index) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => selectedCharacterIndex = index),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: const Padding(
          padding: EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '# 十',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('HP 11/11', style: TextStyle(color: Colors.red)),
              Text('MP 4/9', style: TextStyle(color: Colors.blue)),
            ],
          ),
        ),
      ),
    );
  }

  // 캐릭터 추가 함수
  void _addCharacter(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('새 캐릭터가 추가되었습니다!')));
  }

  // 캐릭터 저장: systems-불문 공통 포맷으로 묶어서 저장 요청
  void _saveCharacter() async {
    final data = _collectCurrentData();

    // 1) 검증
    final issues = rules.validate(data);
    if (issues.isNotEmpty) {
      final first = issues.first;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패: ${first.message}')));
      return;
    }

    // 2) 파생치 계산
    final derived = _deriveCurrent();

    // 3) 페이로드 구성 (룰 식별자 포함)
    final payload = {'systemId': systemId, 'data': data, 'derived': derived};

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('저장 완료 (Mock)')));
  }

  // Drawer 핸들
  Widget _buildDrawerHandle({
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 80,
        color: Colors.black.withOpacity(0.1),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _chatController.dispose();
    _msgScroll.dispose();

    // 컨트롤러 해제
    for (final c in generalControllers.values) {
      c.dispose();
    }
    for (final c in statControllers.values) {
      c.dispose();
    }
    super.dispose();
  }
}
