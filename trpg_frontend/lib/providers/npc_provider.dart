// lib/providers/npc_provider.dart
import 'package:flutter/foundation.dart';
import 'package:trpg_frontend/models/npc.dart';
import 'package:trpg_frontend/services/npc_service.dart'; // NpcService와 NpcServiceException import

class NpcProvider with ChangeNotifier {
  final String _roomId;
  // --- ✨ NpcService 싱글톤 인스턴스 사용 ---
  final NpcService _npcService = NpcService.instance;
  // --- ✨ ---

  List<Npc> _npcs = [];
  List<Npc> get npcs => List.unmodifiable(_npcs);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  NpcProvider(this._roomId) {
    fetchNpcs();
  }

  /// NPC 목록 가져오기 (NpcService 호출)
  Future<void> fetchNpcs() async {
    if (_isLoading) return;

    _setLoading(true); // 로딩 시작 알림

    try {
      // --- ✨ NpcService.instance 사용 ---
      _npcs = await _npcService.getNpcsInRoom(_roomId);
      // --- ✨ ---
      debugPrint('[NpcProvider] Fetched ${_npcs.length} NPCs for room $_roomId');
      _setError(null); // 성공 시 에러 클리어
    } on NpcServiceException catch (e) { // 서비스 예외 처리
      debugPrint('[NpcProvider] Error fetching NPCs: $e');
      _setError('NPC 목록 로딩 실패: ${e.message}');
    } catch (e) { // 일반 예외 처리
      debugPrint('[NpcProvider] Unexpected error fetching NPCs: $e');
      _setError('NPC 목록 로딩 중 예상치 못한 오류 발생.');
    } finally {
      _setLoading(false); // 로딩 종료 알림
    }
  }

  /// NPC 추가 (NpcService 호출)
  Future<bool> addNpc(Npc newNpc) async { // 성공 여부 반환하도록 변경 (선택적)
    if (newNpc.name.trim().isEmpty) {
      _setError('NPC 이름은 비워둘 수 없습니다.');
      return false;
    }

    _setError(null);
    // _setAdding(true); // 필요 시 추가 작업용 로딩 상태

    try {
      // --- ✨ NpcService.instance 사용 ---
      final createdNpc = await _npcService.createNpc(newNpc);
      // --- ✨ ---
      _npcs.add(createdNpc);
      debugPrint('[NpcProvider] Added NPC: ${createdNpc.name} (ID: ${createdNpc.id})');
      notifyListeners(); // 목록 변경 알림
      return true; // 성공 반환
    } on NpcServiceException catch (e) {
      debugPrint('[NpcProvider] Error creating NPC: $e');
      _setError('NPC 생성 실패: ${e.message}');
      return false; // 실패 반환
    } catch (e) {
      debugPrint('[NpcProvider] Unexpected error creating NPC: $e');
      _setError('NPC 생성 중 예상치 못한 오류 발생.');
      return false; // 실패 반환
    } finally {
      // _setAdding(false);
    }
  }

  /// NPC 삭제 (NpcService 호출)
  Future<bool> removeNpc(int npcId) async {
    _setError(null);
    final index = _npcs.indexWhere((npc) => npc.id == npcId);
    if (index == -1) {
      _setError('삭제할 NPC를 찾을 수 없습니다.');
      return false;
    }
    final npcToRemove = _npcs[index];

    // Optimistic UI update
    _npcs.removeAt(index);
    notifyListeners();
    debugPrint('[NpcProvider] Optimistically removed NPC ID: $npcId');

    try {
      // --- ✨ NpcService.instance 사용 ---
      await _npcService.deleteNpc(npcId);
      // --- ✨ ---
      debugPrint('[NpcProvider] Successfully deleted NPC ID: $npcId from server.');
      return true;
    } on NpcServiceException catch (e) {
      debugPrint('[NpcProvider] Error deleting NPC: $e');
      _setError('NPC 삭제 실패: ${e.message}');
      _npcs.insert(index, npcToRemove); // Rollback
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[NpcProvider] Unexpected error deleting NPC: $e');
      _setError('NPC 삭제 중 예상치 못한 오류 발생.');
      _npcs.insert(index, npcToRemove); // Rollback
      notifyListeners();
      return false;
    }
  }

  /// NPC 수정 (NpcService 호출)
  Future<bool> updateNpc(int npcId, Map<String, dynamic> updateData) async {
    _setError(null);
    final index = _npcs.indexWhere((npc) => npc.id == npcId);
    if (index == -1) {
      _setError('수정할 NPC를 찾을 수 없습니다.');
      return false;
    }
    // final originalNpc = _npcs[index]; // 롤백용 원본 저장

    try {
      // --- ✨ NpcService.instance 사용 ---
      final updatedNpc = await _npcService.updateNpc(npcId, updateData);
      // --- ✨ ---
      _npcs[index] = updatedNpc; // 서버 응답으로 업데이트
      debugPrint('[NpcProvider] Updated NPC ID: $npcId');
      notifyListeners();
      return true;
    } on NpcServiceException catch (e) {
      debugPrint('[NpcProvider] Error updating NPC: $e');
      _setError('NPC 정보 수정 실패: ${e.message}');
      // _npcs[index] = originalNpc; // Rollback
      // notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[NpcProvider] Unexpected error updating NPC: $e');
      _setError('NPC 정보 수정 중 예상치 못한 오류 발생.');
      // _npcs[index] = originalNpc; // Rollback
      // notifyListeners();
      return false;
    }
  }

  /// 에러 메시지 클리어
  void clearError() {
    _setError(null);
  }

  // --- ✨ Helper methods for state update ---
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String? errorMsg) {
    if (_error != errorMsg) {
      _error = errorMsg;
      notifyListeners(); // 에러 상태 변경 알림
    }
  }
  // --- ✨ ---
}