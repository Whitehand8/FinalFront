// lib/screens/room/widgets/character_sheet_overlay.dart
import 'package:flutter/material.dart';
import 'package:refine_trpg/features/character_sheet/character_sheet_router.dart';
import 'package:refine_trpg/models/character.dart'; // Character 모델 임포트

class CharacterSheetOverlay extends StatelessWidget {
  final Character? character; // 현재 선택된 캐릭터 (Nullable)
  final String systemId;
  final Map<String, TextEditingController> statControllers;
  final Map<String, TextEditingController> generalControllers;
  final VoidCallback onClose;
  final VoidCallback onSave;

  const CharacterSheetOverlay({
    super.key,
    required this.character,
    required this.systemId,
    required this.statControllers,
    required this.generalControllers,
    required this.onClose,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    // character가 null이면 아무것도 표시하지 않음
    if (character == null) {
      return const SizedBox.shrink();
    }

    // HP와 MP를 안전하게 파싱
    final hp = int.tryParse(generalControllers['HP']?.text ?? '0') ?? 0;
    final mp = int.tryParse(generalControllers['MP']?.text ?? '0') ?? 0;

    return Positioned(
      right: 16,
      top: 16,
      bottom: 16,
      width: 320,
      child: Card(
        elevation: 8,
        clipBehavior: Clip.antiAlias,
        child: CharacterSheetRouter(
          systemId: systemId,
          statControllers: statControllers,
          generalControllers: generalControllers,
          hp: hp,
          mp: mp,
          onClose: onClose, // 콜백 연결
          onSave: onSave, // 콜백 연결
        ),
      ),
    );
  }
}