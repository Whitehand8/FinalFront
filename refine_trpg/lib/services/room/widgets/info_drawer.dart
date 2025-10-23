// lib/screens/room/widgets/info_drawer.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refine_trpg/models/room.dart';
import 'package:refine_trpg/models/participant.dart';
import 'package:refine_trpg/models/character.dart';
import 'package:refine_trpg/models/npc.dart';
import 'package:refine_trpg/providers/npc_provider.dart'; // NpcProvider 임포트
import 'package:refine_trpg/services/room/modals/npc_create_modal.dart'; // 모달 임포트
import 'package:refine_trpg/services/room/modals/npc_detail_modal.dart'; // 모달 임포트

// Participant Context Menu 관련 콜백 함수 타입 정의
typedef ParticipantActionCallback = void Function(Participant participant);
// Character/NPC 관련 콜백 함수 타입 정의
typedef ItemActionCallback<T> = void Function(T item);

class InfoDrawer extends StatefulWidget {
  final Room room;
  final List<Participant> participants;
  final bool isParticipantsLoading;
  final VoidCallback onLoadParticipants; // 참여자 목록 새로고침 콜백
  final List<Character> characters;
  final VoidCallback onAddCharacter; // 캐릭터 추가 콜백
  final ItemActionCallback<Character> onSelectCharacter; // 캐릭터 선택 콜백
  final String currentUserId; // 현재 사용자 ID (방장/본인 구분용)
  final bool isCurrentUserCreator; // 현재 사용자가 방장인지 여부
  final ParticipantActionCallback showParticipantContextMenu; // 참여자 컨텍스트 메뉴 표시 콜백

  const InfoDrawer({
    super.key,
    required this.room,
    required this.participants,
    required this.isParticipantsLoading,
    required this.onLoadParticipants,
    required this.characters,
    required this.onAddCharacter,
    required this.onSelectCharacter,
    required this.currentUserId,
    required this.isCurrentUserCreator,
    required this.showParticipantContextMenu,
  });

  @override
  _InfoDrawerState createState() => _InfoDrawerState();
}

class _InfoDrawerState extends State<InfoDrawer> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 참여자, 캐릭터, NPC
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- 캐릭터 카드 빌더 (별도 함수로 분리) ---
  Widget _buildCharacterCard(Character character) {
    final general = (character.data['general'] as Map<String, dynamic>?) ?? {};
    final stats = (character.data['stats'] as Map<String, dynamic>?) ?? {};
    final name = general['name']?.toString().isNotEmpty == true ? general['name'].toString() : '이름 없음';
    final hp = general['HP']?.toString() ?? stats['HP']?.toString() ?? '-';
    final mp = general['MP']?.toString() ?? stats['MP']?.toString() ?? '-';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('HP: $hp / MP: $mp'),
        trailing: const Icon(Icons.edit_note, size: 20),
        onTap: () => widget.onSelectCharacter(character), // 콜백 사용
        // TODO: 캐릭터 삭제 기능 (onLongPress 등)
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          AppBar(
            title: const Text('정보'),
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF5D4037),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: '닫기',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.people_alt), text: '참여자'),
                Tab(icon: Icon(Icons.description), text: '캐릭터'),
                Tab(icon: Icon(Icons.person_pin), text: 'NPC'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildParticipantsList(),
                _buildCharacterList(),
                _buildNpcList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 참여자 탭 빌더 ---
  Widget _buildParticipantsList() {
    return Column(
      children: [
        ListTile(
          title: const Text('참여자 목록'),
          trailing: widget.isParticipantsLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: '참여자 목록 새로고침',
                  onPressed: widget.onLoadParticipants, // 콜백 사용
                ),
        ),
        Expanded(
          child: widget.participants.isEmpty && !widget.isParticipantsLoading
              ? const Center(child: Text('참여자가 없습니다.'))
              : ListView.builder(
                  itemCount: widget.participants.length,
                  itemBuilder: (context, index) {
                    final p = widget.participants[index];
                    final bool isCreator = widget.room.creator != null && p.userId == widget.room.creator!.id;
                    final bool isSelf = p.userId == widget.currentUserId;

                    return ListTile(
                      leading: CircleAvatar(child: Text(p.nickname.isNotEmpty ? p.nickname[0].toUpperCase() : '?')),
                      title: Text(p.nickname + (isSelf ? ' (나)' : '')),
                      subtitle: Text('ID: ${p.userId} / Role: ${p.role}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCreator)
                            Tooltip(message: '방장', child: Icon(Icons.shield_moon, color: Colors.blue.shade700, size: 20)),
                          SizedBox(width: isCreator ? 4 : 0),
                          if (p.role == 'GM')
                            Tooltip(message: 'GM', child: Icon(Icons.star, color: Colors.amber.shade700, size: 20)),
                        ],
                      ),
                      onLongPress: widget.isCurrentUserCreator && !isCreator // 방장이고, 자기 자신이 아닐 때
                          ? () => widget.showParticipantContextMenu(p) // 컨텍스트 메뉴 콜백 호출
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- 캐릭터 탭 빌더 ---
  Widget _buildCharacterList() {
    return Column(
      children: [
        ListTile(
          title: const Text('캐릭터 목록'),
          trailing: Tooltip(
            message: '새 캐릭터 추가',
            child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: widget.onAddCharacter, // 콜백 사용
            ),
          ),
        ),
        Expanded(
          child: widget.characters.isEmpty
              ? const Center(child: Text('생성된 캐릭터가 없습니다.'))
              : ListView.builder(
                  itemCount: widget.characters.length,
                  itemBuilder: (context, index) => _buildCharacterCard(widget.characters[index]),
                ),
        ),
      ],
    );
  }

  // --- NPC 탭 빌더 ---
  Widget _buildNpcList() {
    // NpcProvider를 Consumer로 구독
    return Consumer<NpcProvider>(
      builder: (context, npcProvider, child) {
        return Column(
          children: [
            ListTile(
              title: const Text('NPC 목록'),
              trailing: Tooltip(
                message: '새 NPC 추가',
                child: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    // Drawer를 닫지 않고 바로 모달 띄우기 (Drawer 닫힘은 모달에서 처리)
                    showDialog(
                      context: context,
                      builder: (ctx) => NpcCreateModal(roomId: widget.room.id!),
                    );
                  },
                ),
              ),
            ),
            // 로딩 및 빈 상태 처리
            if (npcProvider.isLoading && npcProvider.npcs.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (npcProvider.npcs.isEmpty)
              const Expanded(child: Center(child: Text('생성된 NPC가 없습니다.')))
            else
              // NPC 목록 표시
              Expanded(
                child: ListView.builder(
                  itemCount: npcProvider.npcs.length,
                  itemBuilder: (context, index) {
                    final npc = npcProvider.npcs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(npc.name.isNotEmpty ? npc.name[0] : 'N'),
                        ),
                        title: Text(npc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(npc.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'NPC 삭제',
                          onPressed: () => _showDeleteNpcDialog(context, npc), // 삭제 확인 다이얼로그
                        ),
                        onTap: () {
                          // Drawer를 닫지 않고 바로 모달 띄우기
                          showDialog(
                            context: context,
                            builder: (ctx) => NpcDetailModal(npc: npc),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  // NPC 삭제 확인 다이얼로그
  void _showDeleteNpcDialog(BuildContext context, Npc npc) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('NPC 삭제 확인'),
          content: Text('${npc.name} NPC를 정말 삭제하시겠습니까?'),
          actions: [
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // NpcProvider의 removeNpc 호출 (listen: false 중요)
                context.read<NpcProvider>().removeNpc(npc.id!);
              },
            ),
          ],
        );
      },
    );
  }
}