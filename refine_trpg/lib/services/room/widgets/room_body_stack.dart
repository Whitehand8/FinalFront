import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refine_trpg/models/character.dart';
import 'package:refine_trpg/services/chat_service.dart';
import 'package:refine_trpg/services/vtt_socket_service.dart';
import 'package:refine_trpg/widgets/chat_bubble_widget.dart';
import 'dice_panel.dart'; // DicePanel 임포트
import 'character_sheet_overlay.dart'; // CharacterSheetOverlay 임포트

class RoomBodyStack extends StatelessWidget {
  final bool isDicePanelOpen;
  final Character? selectedCharacter;
  // [제거됨] final String systemId; // CharacterSheetOverlay가 character 객체에서 직접 trpgType을 사용
  final Map<String, TextEditingController> statControllers;
  final Map<String, TextEditingController> generalControllers;
  final List<int> diceFaces; // 주사위 면 목록
  final Map<int, int> diceCounts; // 주사위 개수
  final Function(int face, bool increment) onDiceCountChanged; // 주사위 개수 변경 콜백
  final VoidCallback onRollDice; // 주사위 굴리기 콜백
  final VoidCallback onCloseCharacterSheet; // 캐릭터 시트 닫기 콜백
  final VoidCallback onSaveCharacter; // 캐릭터 저장 콜백
  final ScrollController chatScrollController; // 채팅 스크롤 컨트롤러
  // final int? currentUserId; // 현재 사용자 ID 추가 (isMe 로직 위해)
  // final List<Participant> participants; // 참가자 목록 추가 (닉네임 표시 위해)

  const RoomBodyStack({
    super.key,
    required this.isDicePanelOpen,
    required this.selectedCharacter,
    // [제거됨] required this.systemId,
    required this.statControllers,
    required this.generalControllers,
    required this.diceFaces,
    required this.diceCounts,
    required this.onDiceCountChanged,
    required this.onRollDice,
    required this.onCloseCharacterSheet,
    required this.onSaveCharacter,
    required this.chatScrollController,
    // this.currentUserId,
    // required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // --- VTT Canvas ---
        Positioned.fill(
          child: Consumer<VttSocketService>(
            builder: (context, vttService, child) {
              // TODO: VttSocketService가 VttMapDto를 제공하도록 수정 후 로직 변경
              // if (vttService.currentMap == null) {
              //   return const Center(child: CircularProgressIndicator( key: ValueKey('vtt_loading'),)); // 로딩 인디케이터에 키 추가
              // }
              // return VttCanvas(mapData: vttService.currentMap!, tokens: vttService.tokens); // 수정된 VttCanvas 호출
              return const Center(child: Text('VTT 기능 구현 중...')); // 임시 대체
            },
          ),
        ),

        // --- Chat Messages Overlay ---
        Positioned(
          left: 10,
          bottom: 80, // 입력창 높이 고려
          right: MediaQuery.of(context).size.width * 0.5, // 너비 조절
          top: MediaQuery.of(context).size.height * 0.4, // 높이 조절
          child: Container(
            key: const ValueKey('chat_overlay'), // 고유 키 추가
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Consumer<ChatService>(
              builder: (context, chatService, child) {
                if (chatService.isLoadingHistory) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (chatService.error != null) {
                  return Center(child: Text('채팅 오류: ${chatService.error}'));
                }
                if (chatService.messages.isEmpty) {
                  return const Center(child: Text('메시지가 없습니다.'));
                }
                return ListView.builder(
                  controller: chatScrollController, // 스크롤 컨트롤러 연결
                  itemCount: chatService.messages.length,
                  padding: const EdgeInsets.all(8.0),
                  itemBuilder: (context, index) {
                    final msg = chatService.messages[index];
                    // final isMe = msg.senderId == currentUserId; // TODO: Implement isMe logic

                    // --- 오류 수정: senderId(int)를 String으로 변환 ---
                    final playerNameString = msg.senderId.toString();

                    // TODO: 참가자 목록(participants)을 받아와서 senderId로 닉네임 찾기
                    // final participant = participants.firstWhere((p) => p.userId == msg.senderId, orElse: () => null);
                    // final displayName = participant?.nickname ?? 'ID: ${msg.senderId}';

                    return ChatBubbleWidget(
                      // playerName: displayName, // 닉네임 사용 시
                      playerName: playerNameString, // 임시로 ID 문자열 사용
                      message: msg.content,
                      // isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),
        ),

        // --- Character Sheet Overlay (분리된 위젯 사용) ---
        CharacterSheetOverlay(
          key: const ValueKey('character_sheet_overlay'), // 고유 키 추가
          character: selectedCharacter,
          // [수정됨] systemId: systemId, // 이 줄을 제거합니다.
          statControllers: statControllers,
          generalControllers: generalControllers,
          onClose: onCloseCharacterSheet, // 콜백 전달
          onSave: onSaveCharacter, // 콜백 전달
        ),

        // --- Dice Panel Overlay (분리된 위젯 사용) ---
        if (isDicePanelOpen)
          Positioned(
            key: const ValueKey('dice_panel_overlay'), // 고유 키 추가
            top: 16,
            right: 16,
            child: DicePanel(
              diceFaces: diceFaces,
              diceCounts: diceCounts,
              onCountChanged: onDiceCountChanged, // 콜백 전달
              onRoll: onRollDice, // 콜백 전달
            ),
          ),
      ],
    );
  }
}