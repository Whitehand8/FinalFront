// lib/models/enums/npc_type.dart

/// 백엔드의 NpcType Enum (trpg_server/src/common/enums/npc-type.enum.ts)
enum NpcType {
  basic,
  merchant,
  questGiver,
  guard,
  // 필요에 따라 백엔드와 동일하게 추가
}

/// Enum을 API가 이해하는 문자열로 변환
String npcTypeToString(NpcType type) {
  return type.toString().split('.').last;
}

/// API의 문자열을 Enum으로 변환
NpcType npcTypeFromString(String typeString) {
  try {
    return NpcType.values.firstWhere(
      (e) => npcTypeToString(e) == typeString,
      orElse: () => NpcType.basic, // 매칭되는 값이 없으면 basic 반환
    );
  } catch (e) {
    return NpcType.basic; // 기본값
  }
}