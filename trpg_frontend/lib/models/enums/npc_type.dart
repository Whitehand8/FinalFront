// lib/models/enums/npc_type.dart

/// 백엔드의 NpcType Enum (trpg_server/src/common/enums/npc-type.enum.ts)
enum NpcType {
  NPC,      // 'npc'
  MONSTER,  // 'monster'
}

/// Enum을 API가 이해하는 문자열('npc', 'monster')로 변환
String npcTypeToString(NpcType type) {
  switch (type) {
    case NpcType.NPC:
      return 'npc';
    case NpcType.MONSTER:
      return 'monster';
    default:
      return 'npc';
  }
}

/// API의 문자열('npc', 'monster')을 Enum으로 변환
NpcType npcTypeFromString(String? typeString) {
  switch (typeString) {
    case 'npc':
      return NpcType.NPC;
    case 'monster':
      return NpcType.MONSTER;
    default:
      return NpcType.NPC; // 매칭되는 값이 없으면 NPC 반환
  }
}