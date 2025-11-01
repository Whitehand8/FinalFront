// lib/widgets/npc/npc_detail_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trpg_frontend/models/npc.dart';
import 'package:trpg_frontend/models/enums/npc_type.dart';
import 'package:trpg_frontend/providers/npc_provider.dart';
import 'dart:convert'; // JsonEncoder/Decoder

class NpcDetailModal extends StatefulWidget {
  final Npc npc;
  final bool isGm; // ✨ GM 여부 플래그 추가

  const NpcDetailModal({
    super.key,
    required this.npc,
    required this.isGm, // ✨ GM 플래그 필수
  });

  @override
  _NpcDetailModalState createState() => _NpcDetailModalState();
}

class _NpcDetailModalState extends State<NpcDetailModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _dataController;
  late bool _isPublic; // ✨ isPublic 상태 변수
  late NpcType _type;  // ✨ type 상태 변수
  bool _isLoading = false; // 저장/삭제 로딩 상태

  @override
  void initState() {
    super.initState();
    // 초기값 설정
    _nameController = TextEditingController(text: widget.npc.name);
    _descController = TextEditingController(text: widget.npc.description);
    _dataController = TextEditingController(text: _formatJson(widget.npc.data));
    _isPublic = widget.npc.isPublic; // ✨ 초기 isPublic 설정
    _type = widget.npc.type;         // ✨ 초기 type 설정
  }

  // JSON 보기 좋게 포맷 (기존과 동일)
  String _formatJson(Map<String, dynamic> data) {
    try {
      // data 맵에서 name, description 키 제거 (별도 필드에서 편집하므로)
      final dataWithoutOverrides = Map<String, dynamic>.from(data)
        ..remove('name')
        ..remove('description')
        ..remove('imageUrl'); // imageUrl도 data보다는 별도 필드가 나을 수 있음 (선택적)
      return const JsonEncoder.withIndent('  ').convert(dataWithoutOverrides);
    } catch (e) {
      return data.toString(); // 실패 시 단순 문자열 변환
    }
  }

  // JSON 파싱 (기존과 동일)
  Map<String, dynamic> _parseJson(String text) {
    try {
      if (text.trim().isEmpty) return {}; // 비어있으면 빈 맵 반환
      final data = jsonDecode(text);
      if (data is Map<String, dynamic>) {
        return data;
      }
      return {'error': 'Invalid JSON format: Not a Map'};
    } catch (e) {
      return {'error': 'Failed to parse JSON: $e'};
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _dataController.dispose();
    super.dispose();
  }

  /// 변경 사항 저장 로직
  Future<void> _saveChanges() async {
    // GM만 저장 가능
    if (!widget.isGm) return;

    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save(); // Controller 값들이 필드로 저장될 필요는 없음

    setState(() => _isLoading = true);

    final Map<String, dynamic> dataMap = _parseJson(_dataController.text);
    if (dataMap.containsKey('error')) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Data 필드의 JSON 형식이 올바르지 않습니다: ${dataMap['error']}');
      return;
    }

    // ✨ 백엔드 UpdateNpcDto 형식에 맞춰 데이터 구성
    final updateData = {
      'type': npcTypeToString(_type), // NpcType enum -> String
      'isPublic': _isPublic,
      'data': {
        'name': _nameController.text.trim(), // 이름은 data 안에 포함
        'description': _descController.text.trim(), // 설명도 data 안에 포함
        // imageUrl은 dataMap에 포함시키거나 별도 필드로 관리
        ...dataMap, // 편집된 JSON 데이터 병합
      },
    };

    try {
      // Provider를 통해 업데이트 요청
      final success = await context.read<NpcProvider>().updateNpc(widget.npc.id!, updateData);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(); // 성공 시 모달 닫기
          _showSuccessSnackBar('NPC 정보가 저장되었습니다.');
        } else {
          // Provider에서 에러 처리 후 false 반환 시
          final errorMsg = context.read<NpcProvider>().error ?? '알 수 없는 오류';
          _showErrorSnackBar('NPC 정보 저장 실패: $errorMsg');
          setState(() => _isLoading = false); // 로딩 해제
        }
      }
    } catch (e) { // 혹시 모를 Provider 외부 예외
       if (mounted) {
         _showErrorSnackBar('NPC 정보 저장 중 오류 발생: $e');
         setState(() => _isLoading = false);
       }
    }
    // 성공 시 pop 되므로 finally 블록 불필요
  }

  /// NPC 삭제 로직
  Future<void> _deleteNpc() async {
    // GM만 삭제 가능
    if (!widget.isGm || widget.npc.id == null) return;

    // 삭제 확인 다이얼로그
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('NPC 삭제 확인'),
        content: Text('"${widget.npc.name}" NPC를 정말 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return; // 사용자가 취소한 경우

    setState(() => _isLoading = true); // 삭제 작업 로딩 시작

    try {
      final success = await context.read<NpcProvider>().removeNpc(widget.npc.id!);

       if (mounted) {
         if (success) {
           Navigator.of(context).pop(); // 성공 시 모달 닫기
           _showSuccessSnackBar('NPC가 삭제되었습니다.');
         } else {
           final errorMsg = context.read<NpcProvider>().error ?? '알 수 없는 오류';
           _showErrorSnackBar('NPC 삭제 실패: $errorMsg');
           setState(() => _isLoading = false); // 로딩 해제
         }
       }
    } catch (e) {
       if (mounted) {
         _showErrorSnackBar('NPC 삭제 중 오류 발생: $e');
         setState(() => _isLoading = false);
       }
    }
  }

  // --- Helper methods for SnackBar ---
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // ✨ 제목 수정 (기본 정보 + 수정 표시)
      title: Text(widget.isGm ? 'NPC 정보 수정' : 'NPC 정보 조회'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, // 왼쪽 정렬
            children: [
              // --- 이름 ---
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '이름'),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? '이름을 입력하세요.' : null,
                readOnly: !widget.isGm, // GM 아니면 읽기 전용
              ),
              const SizedBox(height: 16),

              // --- 설명 ---
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: '설명'),
                maxLines: 3,
                readOnly: !widget.isGm,
              ),
              const SizedBox(height: 16),

              // --- 타입 선택 ---
              DropdownButtonFormField<NpcType>(
                value: _type,
                decoration: const InputDecoration(labelText: '유형'),
                items: NpcType.values
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(npcTypeToString(type)),
                        ))
                    .toList(),
                // ✨ GM만 변경 가능하도록, null 전달 시 비활성화됨
                onChanged: widget.isGm ? (val) {
                  if (val != null) setState(() => _type = val);
                } : null,
              ),
              const SizedBox(height: 16),

              // --- 공개 여부 ---
              CheckboxListTile(
                title: const Text('플레이어에게 공개'),
                value: _isPublic,
                // ✨ GM만 변경 가능
                onChanged: widget.isGm ? (bool? value) {
                  setState(() => _isPublic = value ?? false);
                } : null,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),

              // --- Data (JSON) ---
              TextFormField(
                controller: _dataController,
                decoration: const InputDecoration(
                  labelText: '추가 데이터 (JSON 형식)',
                  alignLabelWithHint: true,
                  hintText: '{}', // 빈 JSON 예시
                  // ✨ JSON 편집기 스타일 개선 (선택적)
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 8,
                readOnly: !widget.isGm,
                // JSON 유효성 검사
                validator: (val) {
                   if (val == null || val.trim().isEmpty) return null; // 비어있으면 통과
                   final parsed = _parseJson(val);
                   return parsed.containsKey('error') ? parsed['error'] : null;
                },
                style: const TextStyle(fontFamily: 'monospace'), // 고정폭 글꼴 사용
              ),
            ],
          ),
        ),
      ),
      actions: [
        // ✨ GM일 경우 삭제 버튼 추가
        if (widget.isGm)
          TextButton(
            onPressed: _isLoading ? null : _deleteNpc,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: _isLoading
               ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
               : const Text('삭제'),
          ),
        const Spacer(), // 버튼들을 양쪽으로 밀기
        // --- 취소 버튼 ---
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        // --- 저장 버튼 (GM 전용) ---
        if (widget.isGm)
          ElevatedButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: _isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('저장'),
          ),
      ],
    );
  }
}