// lib/screens/room/modals/npc_create_modal.dart
// (또는 lib/features/npc/widgets/npc_create_modal.dart)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refine_trpg/models/npc.dart'; // Npc 모델 임포트
import 'package:refine_trpg/models/enums/npc_type.dart'; // NpcType Enum 임포트
import 'package:refine_trpg/providers/npc_provider.dart'; // NpcProvider 임포트

/// NPC 생성을 위한 모달 (AlertDialog) 위젯
class NpcCreateModal extends StatefulWidget {
  final String roomId; // NPC를 생성할 방의 ID
  const NpcCreateModal({super.key, required this.roomId});

  @override
  _NpcCreateModalState createState() => _NpcCreateModalState();
}

class _NpcCreateModalState extends State<NpcCreateModal> {
  final _formKey = GlobalKey<FormState>(); // 폼 유효성 검사를 위한 키
  String _name = ''; // 입력받을 NPC 이름
  String _description = ''; // 입력받을 NPC 설명
  NpcType _type = NpcType.basic; // 선택된 NPC 타입 (기본값: basic)
  bool _isLoading = false; // 생성 요청 중 로딩 상태 표시

  /// '생성' 버튼 클릭 시 실행될 함수
  Future<void> _submit() async {
    // 1. 폼 유효성 검사
    if (!_formKey.currentState!.validate()) {
      return; // 유효하지 않으면 중단
    }
    // 2. 폼 필드 값 저장
    _formKey.currentState!.save();

    // 3. 로딩 상태 시작
    setState(() => _isLoading = true);

    // 4. Npc 객체 생성 (id는 null, data는 기본값 {})
    final newNpc = Npc(
      name: _name,
      description: _description,
      type: _type,
      roomId: widget.roomId,
    );

    try {
      // 5. NpcProvider를 통해 NPC 추가 요청 (listen: false로 상태 변경은 구독하지 않음)
      await context.read<NpcProvider>().addNpc(newNpc);

      // 6. 성공 시 모달 닫기 (mounted 확인 필수)
      if (mounted) {
        Navigator.of(context).pop();
        // (선택) 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('NPC "${newNpc.name}" 생성 완료!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      // 7. 실패 시 로딩 상태 해제 및 에러 메시지 표시
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('NPC 생성 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
    // finally 블록을 사용하지 않아도, 성공 시 pop 되므로 로딩 상태 해제가 필요 없음
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('새 NPC 생성'),
      // 내용이 길어질 수 있으므로 SingleChildScrollView 사용
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min, // 컬럼 높이를 내용에 맞춤
            children: [
              // --- NPC 이름 입력 필드 ---
              TextFormField(
                decoration: const InputDecoration(labelText: '이름'),
                // 이름은 필수 입력
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? '이름을 입력하세요.' : null,
                onSaved: (val) => _name = val!.trim(),
              ),
              const SizedBox(height: 16), // 간격

              // --- NPC 설명 입력 필드 ---
              TextFormField(
                decoration: const InputDecoration(labelText: '설명'),
                maxLines: 3, // 여러 줄 입력 가능하도록
                onSaved: (val) => _description = val?.trim() ?? '',
              ),
              const SizedBox(height: 16), // 간격

              // --- NPC 타입 선택 드롭다운 ---
              DropdownButtonFormField<NpcType>(
                value: _type, // 현재 선택된 타입
                decoration: const InputDecoration(labelText: 'NPC 유형'),
                // NpcType Enum의 모든 값을 순회하며 메뉴 아이템 생성
                items: NpcType.values
                    .map((type) => DropdownMenuItem(
                          value: type,
                          // 화면에는 Enum 값을 문자열로 변환하여 표시
                          child: Text(npcTypeToString(type)),
                        ))
                    .toList(),
                // 값이 변경될 때 _type 상태 업데이트
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _type = val);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        // --- 취소 버튼 ---
        TextButton(
          // 로딩 중일 때는 비활성화
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        // --- 생성 버튼 ---
        ElevatedButton(
          // 로딩 중일 때는 비활성화하고 로딩 인디케이터 표시
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox( // 로딩 인디케이터 크기 조절
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('생성'),
        ),
      ],
    );
  }
}