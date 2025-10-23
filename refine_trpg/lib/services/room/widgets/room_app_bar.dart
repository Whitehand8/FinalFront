// lib/screens/room/widgets/room_app_bar.dart
import 'package:flutter/material.dart';
import 'package:refine_trpg/models/room.dart';

class RoomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Room room;
  final bool isCurrentUserCreator;
  final VoidCallback onDicePanelToggle;
  final VoidCallback onDrawerOpen;
  final Function(String) onMenuSelected; // 메뉴 선택 콜백

  const RoomAppBar({
    super.key,
    required this.room,
    required this.isCurrentUserCreator,
    required this.onDicePanelToggle,
    required this.onDrawerOpen,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(room.name),
      backgroundColor: const Color(0xFF8C7853),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: '뒤로가기',
        onPressed: () => Navigator.of(context).pop(), // 직접 Navigator 사용
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.casino),
          tooltip: '주사위 패널 열기/닫기',
          onPressed: onDicePanelToggle, // 콜백 연결
        ),
        IconButton(
          icon: const Icon(Icons.people),
          tooltip: '참여자 목록 보기',
          onPressed: onDrawerOpen, // 콜백 연결
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: '방 관리 메뉴',
          onSelected: onMenuSelected, // 콜백 연결
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'leave',
              child: ListTile(leading: Icon(Icons.exit_to_app), title: Text('방 나가기')),
            ),
            const PopupMenuItem<String>(
              value: 'getInfo',
              child: ListTile(leading: Icon(Icons.info_outline), title: Text('방 정보 조회 (콘솔)')),
            ),
            if (isCurrentUserCreator) ...[
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'transfer',
                child: ListTile(leading: Icon(Icons.person_pin_circle_outlined), title: Text('방장 위임')),
              ),
              const PopupMenuItem<String>(
                value: 'updateRole',
                child: ListTile(leading: Icon(Icons.admin_panel_settings_outlined), title: Text('참여자 역할 변경')),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_forever, color: Colors.red),
                  title: Text('방 삭제', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}