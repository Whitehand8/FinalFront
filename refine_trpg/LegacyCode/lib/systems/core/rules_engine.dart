abstract class TrpgRules {
  String get systemId; // "coc7e" | "dnd5e" ...
  Map<String, dynamic> initialData(); // 새 캐릭터 기본값
  Map<String, dynamic> derive(Map<String, dynamic> data); // 파생 스탯 계산
  List<ValidationIssue> validate(Map<String, dynamic> data);
  RollResult rollCheck(
    String kind,
    Map<String, dynamic> ctx,
  ); // "skill" | "save" | "attack" 등
}

class ValidationIssue {
  final String field;
  final String message;
  ValidationIssue(this.field, this.message);
}

class RollResult {
  final String detail; // "d100: 74 vs 55 → 실패" 같은 로그
  final int total;
  final bool success;
  RollResult({
    required this.detail,
    required this.total,
    required this.success,
  });
}
