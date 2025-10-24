// lib/providers/npc_provider.dart
import 'package:flutter/foundation.dart';
import 'package:refine_trpg/models/npc.dart';
// NpcServiceException 임포트 (npc_service.dart 파일 내 정의 또는 별도 파일)
import 'package:refine_trpg/services/npc_service.dart';

class NpcProvider with ChangeNotifier {
  final String _roomId; // Room ID (UUID String)
  final NpcService _npcService = NpcService();

  List<Npc> _npcs = [];
  List<Npc> get npcs => List.unmodifiable(_npcs); // Return unmodifiable list

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  NpcProvider(this._roomId) {
    fetchNpcs(); // Fetch NPCs when provider is created
  }

  /// Fetches NPCs for the current room.
  Future<void> fetchNpcs() async {
    if (_isLoading) return; // Prevent concurrent fetches

    _isLoading = true;
    _error = null;
    notifyListeners(); // Notify UI about loading start

    try {
      _npcs = await _npcService.getNpcsInRoom(_roomId);
      debugPrint('[NpcProvider] Fetched ${_npcs.length} NPCs for room $_roomId');
    } on NpcServiceException catch (e) { // Catch specific service exception
      debugPrint('[NpcProvider] Error fetching NPCs: $e');
      _error = 'NPC 목록을 불러오는데 실패했습니다: ${e.message}';
    } catch (e) { // Catch generic errors
      debugPrint('[NpcProvider] Unexpected error fetching NPCs: $e');
      _error = 'NPC 목록 로딩 중 예상치 못한 오류 발생.';
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify UI about loading end and potential error/data
    }
  }

  /// Adds a new NPC via the service.
  Future<void> addNpc(Npc newNpc) async {
    // Basic validation (optional)
    if (newNpc.name.trim().isEmpty) {
       _error = 'NPC 이름은 비워둘 수 없습니다.';
       notifyListeners();
       return;
    }

    _error = null; // Clear previous error
    // Optionally set a specific loading state for add operation
    // _isAdding = true; notifyListeners();

    try {
      // Call service to create NPC (ensure newNpc includes roomId)
      final createdNpc = await _npcService.createNpc(newNpc);
      _npcs.add(createdNpc); // Add to local list on success
      debugPrint('[NpcProvider] Added NPC: ${createdNpc.name} (ID: ${createdNpc.id})');
      notifyListeners();
    } on NpcServiceException catch (e) {
      debugPrint('[NpcProvider] Error creating NPC: $e');
      _error = 'NPC 생성 실패: ${e.message}';
      notifyListeners();
    } catch (e) {
      debugPrint('[NpcProvider] Unexpected error creating NPC: $e');
      _error = 'NPC 생성 중 예상치 못한 오류 발생.';
      notifyListeners();
    } finally {
       // _isAdding = false; notifyListeners();
    }
  }

  /// Removes an NPC via the service.
  /// [수정됨] 매개변수 타입을 int로 변경
  Future<void> removeNpc(int npcId) async {
    _error = null;
    final index = _npcs.indexWhere((npc) => npc.id == npcId); // Find index before removing
    if (index == -1) {
       debugPrint('[NpcProvider] Cannot remove NPC: ID $npcId not found in local list.');
       _error = '삭제할 NPC를 찾을 수 없습니다.';
       notifyListeners();
       return;
    }
    final npcToRemove = _npcs[index]; // Keep a reference for potential rollback

    try {
      // Optimistic UI update (remove immediately)
      _npcs.removeAt(index);
      notifyListeners();
      debugPrint('[NpcProvider] Optimistically removed NPC ID: $npcId');

      // Call service to delete NPC
      await _npcService.deleteNpc(npcId); // <<< --- [수정됨] int ID 전달
      debugPrint('[NpcProvider] Successfully deleted NPC ID: $npcId from server.');

    } on NpcServiceException catch (e) {
      debugPrint('[NpcProvider] Error deleting NPC: $e');
      _error = 'NPC 삭제 실패: ${e.message}';
      // Rollback optimistic update on failure
      _npcs.insert(index, npcToRemove);
      notifyListeners();
    } catch (e) {
      debugPrint('[NpcProvider] Unexpected error deleting NPC: $e');
      _error = 'NPC 삭제 중 예상치 못한 오류 발생.';
      // Rollback optimistic update
      _npcs.insert(index, npcToRemove);
      notifyListeners();
    }
  }

  /// Updates an NPC via the service.
  /// [수정됨] npcId 매개변수 타입을 int로 변경
  Future<void> updateNpc(int npcId, Map<String, dynamic> updateData) async {
    _error = null;
    final index = _npcs.indexWhere((npc) => npc.id == npcId); // <<< --- [수정됨] int ID 비교
    if (index == -1) {
       debugPrint('[NpcProvider] Cannot update NPC: ID $npcId not found.');
       _error = '수정할 NPC를 찾을 수 없습니다.';
       notifyListeners();
       return;
    }
    // Optionally keep original for rollback: final originalNpc = _npcs[index];

    try {
      // Call service to update NPC
      final updatedNpc = await _npcService.updateNpc(npcId, updateData); // <<< --- [수정됨] int ID 전달
      // Update local list with the response from the server
      _npcs[index] = updatedNpc;
      debugPrint('[NpcProvider] Updated NPC ID: $npcId');
      notifyListeners();
    } on NpcServiceException catch (e) {
      debugPrint('[NpcProvider] Error updating NPC: $e');
      _error = 'NPC 정보 수정 실패: ${e.message}';
      // Optionally rollback: _npcs[index] = originalNpc;
      notifyListeners();
    } catch (e) {
      debugPrint('[NpcProvider] Unexpected error updating NPC: $e');
      _error = 'NPC 정보 수정 중 예상치 못한 오류 발생.';
      // Optionally rollback: _npcs[index] = originalNpc;
      notifyListeners();
    }
  }

  /// Clears the current error message.
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

}