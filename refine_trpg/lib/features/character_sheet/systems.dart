// frontend/lib/features/character_sheet/systems/systems.dart

class SystemSpec {
  final List<String> generalKeys; // 이름/직업/HP/MP 등
  final List<String> skillKeys; // 스킬/특성치(시트에 그릴 항목)
  final Map<String, dynamic> defaults; // 각 키의 기본값

  const SystemSpec({
    required this.generalKeys,
    required this.skillKeys,
    required this.defaults,
  });
}

class Systems {
  static final Map<String, SystemSpec> _registry = {
    'coc7e': _coc7e,
    'dnd5e': _dnd5e,
  };

  static Map<String, dynamic> defaults(String id) =>
      _registry[id]?.defaults ?? const <String, dynamic>{};

  static List<String> skillKeys(String id) =>
      _registry[id]?.skillKeys ?? const <String>[];

  static List<String> generalKeys(String id) =>
      _registry[id]?.generalKeys ?? const <String>[];
}

// ── CoC 7th Edition 기본 정의 ────────────────────────────────────────────────
const SystemSpec _coc7e = SystemSpec(
  generalKeys: [
    'name', 'sex', 'age', 'job',
    '장비', '소지품', '현금',
    'HP', 'MP', // HP/MP도 general로 관리(화면에서 바로 꺼내 쓰기 쉬움)
  ],
  skillKeys: [
    '회계',
    '위협',
    '관찰력',
    '인류학',
    '도약',
    '은밀행동',
    '감정',
    '모국어',
    '수영',
    '고고학',
    '법률',
    '투척',
    '자료조사',
    '추적',
    '매혹',
    '오르기',
    '듣기',
    '재력',
    '열쇠공',
    '크툴루신화',
    '기계수리',
    '변장',
    '의료',
    '회피',
    '자연',
    '자동차운전',
    '항법',
    '전기수리',
    '오컬트',
    '말재주',
    '중장비 조작',
    '근접전(격투)',
    '설득',
    '사격(권총)',
    '사격(라/산)',
    '심리학',
    '정신분석',
    '응급처치',
    '승마',
    '역사',
    '손놀림',
  ],
  defaults: {
    // 일반
    'name': '', 'sex': '', 'age': '', 'job': '',
    '장비': '', '소지품': '', '현금': 0,
    'HP': 11, 'MP': 4,
    // 스킬 기본값(룰북 표준치 기반)
    '회계': 5, '위협': 15, '관찰력': 25, '인류학': 1, '도약': 20, '은밀행동': 20,
    '감정': 5, '모국어': 0, '수영': 20, '고고학': 1, '법률': 5, '투척': 20, '자료조사': 20,
    '추적': 10, '매혹': 15, '오르기': 20, '듣기': 20, '재력': 0, '열쇠공': 1, '크툴루신화': 0,
    '기계수리': 10, '변장': 5, '의료': 1, '회피': 0, '자연': 10, '자동차운전': 20,
    '항법': 10, '전기수리': 10, '오컬트': 5, '말재주': 5, '중장비 조작': 1,
    '근접전(격투)': 25, '설득': 10, '사격(권총)': 20, '사격(라/산)': 25,
    '심리학': 10, '정신분석': 1, '응급처치': 30, '승마': 5, '역사': 5, '손놀림': 10,
  },
);

// ── (선택) D&D 5e 예시: 최소 스텁 ───────────────────────────────────────────
const SystemSpec _dnd5e = SystemSpec(
  generalKeys: [
    'name',
    'class',
    'level',
    'background',
    'race',
    'alignment',
    'HP'
  ],
  skillKeys: ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'],
  defaults: {
    'name': '',
    'class': '',
    'level': 1,
    'background': '',
    'race': '',
    'alignment': '',
    'HP': 10,
    'STR': 10,
    'DEX': 10,
    'CON': 10,
    'INT': 10,
    'WIS': 10,
    'CHA': 10,
  },
);
