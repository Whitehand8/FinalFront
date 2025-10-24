// lib/services/room/widgets/character_sheet_overlay.dart
import 'package:flutter/material.dart';
// 수정된 Character 모델 임포트
import 'package:refine_trpg/models/character.dart';
// CharacterSheetRouter 임포트 경로는 실제 프로젝트 구조에 맞게 확인 필요
import 'package:refine_trpg/features/character_sheet/character_sheet_router.dart';

class CharacterSheetOverlay extends StatelessWidget {
  final Character? character; // 현재 선택된 캐릭터 (Nullable)
  // [제거됨] final String systemId; // Character 객체에서 직접 가져오므로 제거
  final Map<String, TextEditingController> statControllers;
  final Map<String, TextEditingController> generalControllers;
  final VoidCallback onClose;
  final VoidCallback onSave;

  const CharacterSheetOverlay({
    super.key,
    required this.character,
    // [제거됨] required this.systemId,
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

    // HP와 MP를 안전하게 파싱 (이 로직은 CharacterSheetRouter의 구현에 따라 달라질 수 있음)
    // Character.data 에서 직접 초기값을 가져오도록 CharacterSheetRouter를 수정하는 것이 더 좋을 수 있습니다.
    final hp = int.tryParse(generalControllers['HP']?.text ??
            character!.data['currentHP']?.toString() ?? // character.data에서 초기값 시도
            '0') ??
        0;
    final mp = int.tryParse(generalControllers['MP']?.text ??
            character!.data['currentMP']?.toString() ?? // character.data에서 초기값 시도
            '0') ??
        0;

    return Positioned(
      right: 16,
      top: 16,
      bottom: 16,
      width: 320, // 시트 너비 고정 또는 반응형으로 조정 가능
      child: Card(
        elevation: 8,
        clipBehavior: Clip.antiAlias,
        child: CharacterSheetRouter(
          // [수정됨] character 객체의 trpgType 사용
          systemId: character!.trpgType,
          statControllers: statControllers,
          generalControllers: generalControllers,
          hp: hp,
          mp: mp,
          onClose: onClose, // 콜백 연결
          onSave: onSave, // 콜백 연결
          // 참고: CharacterSheetRouter가 character 객체 전체를 받는 것이 더 효율적일 수 있습니다.
          // 예: character: character,
        ),
      ),
    );
  }
}