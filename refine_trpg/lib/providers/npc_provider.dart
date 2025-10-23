// lib/providers/npc_provider.dart
import 'package:flutter/foundation.dart';
import '../models/npc.dart';
// DTO 임포트가 필요 없어짐
import '../services/npc_service.dart';

class NpcProvider with ChangeNotifier {
  final String _roomId;
  final NpcService _npcService = NpcService();

  List<Npc> _npcs = [];
  List<Npc> get npcs => _npcs;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  NpcProvider(this._roomId) {
    fetchNpcs();
  }

  Future<void> fetchNpcs() async {
    // ... (이전과 동일)
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _npcs = await _npcService.getNpcsInRoom(_roomId);
    } catch (e) {
      debugPrint('Error fetching NPCs: $e');
      _error = 'NPC 목록을 불러오는데 실패했습니다.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Npc 객체를 직접 받도록 수정
  Future<void> addNpc(Npc newNpc) async {
    _error = null;
    try {
      final createdNpc = await _npcService.createNpc(newNpc);
      _npcs.add(createdNpc);
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating NPC: $e');
      _error = 'NPC 생성에 실패했습니다.';
      notifyListeners();
    }
  }

  Future<void> removeNpc(String npcId) async {
    // ... (이전과 동일)
    _error = null;
    try {
      await _npcService.deleteNpc(npcId);
      _npcs.removeWhere((npc) => npc.id == npcId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting NPC: $e');
      _error = 'NPC 삭제에 실패했습니다.';
      notifyListeners();
    }
  }

  Future<void> updateNpc(String npcId, Map<String, dynamic> updateData) async {
    // ... (이전과 동일)
    _error = null;
    try {
      final updatedNpc = await _npcService.updateNpc(npcId, updateData);
      final index = _npcs.indexWhere((npc) => npc.id == npcId);
      if (index != -1) {
        _npcs[index] = updatedNpc;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating NPC: $e');
      _error = 'NPC 정보 수정에 실패했습니다.';
      notifyListeners();
    }
  }
}