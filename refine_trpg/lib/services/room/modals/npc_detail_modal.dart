// lib/screens/room/modals/npc_detail_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refine_trpg/models/npc.dart';
import 'package:refine_trpg/models/enums/npc_type.dart';
import 'package:refine_trpg/providers/npc_provider.dart';
import 'dart:convert'; // JsonEncoder/Decoder 사용

class NpcDetailModal extends StatefulWidget {
  final Npc npc;
  const NpcDetailModal({super.key, required this.npc});

  @override
  _NpcDetailModalState createState() => _NpcDetailModalState();
}

class _NpcDetailModalState extends State<NpcDetailModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _dataController; // 'data' 필드를 JSON 텍스트로 편집
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.npc.name);
    _descController = TextEditingController(text: widget.npc.description);
    _dataController =
        TextEditingController(text: _formatJson(widget.npc.data));
  }

  String _formatJson(Map<String, dynamic> data) {
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (e) {
      return data.toString();
    }
  }

  Map<String, dynamic> _parseJson(String text) {
    try {
      final data = jsonDecode(text);
      if (data is Map<String, dynamic>) {
        return data;
      }
      return {'error': 'Invalid JSON format'};
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    final Map<String, dynamic> dataMap = _parseJson(_dataController.text);
    if (dataMap.containsKey('error')) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data 필드의 JSON 형식이 올바르지 않습니다.')),
      );
      return;
    }

    final updateData = {
      'name': _nameController.text,
      'description': _descController.text,
      'data': dataMap,
    };

    await context.read<NpcProvider>().updateNpc(widget.npc.id!, updateData);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('NPC 정보 수정: ${widget.npc.name}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '이름'),
                validator: (val) =>
                    (val == null || val.isEmpty) ? '이름을 입력하세요.' : null,
              ),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: '설명'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Text('유형: ${npcTypeToString(widget.npc.type)}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dataController,
                decoration: const InputDecoration(
                  labelText: 'Data (JSON 형식)',
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
                validator: (val) {
                  if (val == null || val.isEmpty) return null;
                  try {
                    jsonDecode(val);
                    return null;
                  } catch (e) {
                    return '올바른 JSON 형식이 아닙니다.';
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveChanges,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('저장'),
        ),
      ],
    );
  }
}