import 'package:flutter/material.dart';
import '../../core/rules_engine.dart';

class Coc7eSheet extends StatefulWidget {
  final TrpgRules rules;
  final Map<String, TextEditingController> stat; // 능력치/스킬 등 숫자 필드
  final Map<String, TextEditingController> general; // 이름/성별/직업 등 일반 필드
  final int hp; // 현재 HP
  final int mp; // 현재 MP
  final VoidCallback onSave;
  final VoidCallback onClose;

  const Coc7eSheet({
    super.key,
    required this.rules,
    required this.stat,
    required this.general,
    required this.hp,
    required this.mp,
    required this.onSave,
    required this.onClose,
  });

  @override
  State<Coc7eSheet> createState() => _Coc7eSheetState();
}

class _Coc7eSheetState extends State<Coc7eSheet> {
  // 파생표시
  int _maxHp = 0, _maxMp = 0, _san = 0, _build = 0;
  String _db = '';
  final List<VoidCallback> _off = [];
  bool _seeded = false; // 기본값 시드를 한 번만 적용

  // ── 능력치 키
  static const List<String> _coreStats = [
    '근력',
    '건강',
    '크기',
    '민첩',
    '외모',
    '지능',
    '교육',
    '정신력',
    '행운',
  ];

  // ── 스킬 키(컨트롤러 키와 동일해야 함)
  static const List<String> _skills = [
    '회계',
    '인류학',
    '감정',
    '고고학',
    '매혹',
    '오르기',
    '재력',
    '크툴루신화',
    '변장',
    '회피',
    '자동차운전',
    '전기수리',
    '말재주',
    '근접전(격투)',
    '사격(권총)',
    '사격(라/산)',
    '응급처치',
    '역사',
    '관찰력',
    '은밀행동',
    '수영',
    '투척',
    '추적',
    '외국어()',
    '과학()',
    '예술/공예()',
    '사격()',
    '자연',
    '항법',
    '오컬트',
    '중장비 조작',
    '심리학',
    '정신분석',
    '승마',
    '손놀림',
    '듣기',
    '자료조사',
    '열쇠공',
    '의료',
    '기계수리',
    '모국어',
    '법률',
    '생존술()',
  ];

  /// ── 스킬 기본값(정적): 회피/모국어/크레딧 등 일부는 따로 계산
  static const Map<String, int> _skillBaseStatic = {
    '회계': 5,
    '인류학': 1,
    '감정': 5,
    '고고학': 1,
    '매혹': 15,
    '오르기': 20,
    '재력': 0,
    '크툴루신화': 0,
    '변장': 5,
    '자동차운전': 20,
    '전기수리': 10,
    '말재주': 5,
    '근접전(격투)': 25,
    '사격(권총)': 20,
    '사격(라/산)': 25,
    '응급처치': 30, '역사': 5, '관찰력': 25, '은밀행동': 20, '수영': 20, '투척': 20, '추적': 10,
    '외국어()': 1, '과학()': 1, '예술/공예()': 5, '사격()': 0, // 특화 필요시 개별 항목으로 사용
    '자연': 10,
    '항법': 10,
    '오컬트': 5,
    '중장비 조작': 1,
    '심리학': 10,
    '정신분석': 1,
    '승마': 5,
    '손놀림': 10,
    '듣기': 20, '자료조사': 20, '열쇠공': 1, '의료': 1, '기계수리': 10, '법률': 5, '생존술()': 10,
    // '회피','모국어' 는 아래 동적 기본값 처리
  };

  @override
  void initState() {
    super.initState();
    _attach();
    _seedDefaultsOnce(); // ← 기본값 채우기(빈 값만)
    _recalc();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _attach() {
    void add(TextEditingController c) {
      void f() {
        if (!_seeded) _seedDefaultsOnce();
        _recalc();
      }

      c.addListener(f);
      _off.add(() => c.removeListener(f));
    }

    for (final c in [...widget.stat.values, ...widget.general.values]) {
      add(c);
    }
  }

  void _detach() {
    for (final fn in _off) fn();
    _off.clear();
  }

  dynamic _parse(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty) return '';
    if (t == 'true' || t == 'false') return t == 'true';
    return int.tryParse(t) ?? s;
  }

  Map<String, dynamic> _collect() {
    final m = <String, dynamic>{};
    widget.stat.forEach((k, c) => m[k] = _parse(c.text));
    widget.general.forEach((k, c) => m[k] = _parse(c.text));
    return m;
  }

  // ── 기본값을 한 번만 채움(빈 필드만)
  void _seedDefaultsOnce() {
    if (_seeded) return;
    _seeded = true;

    // 1) 정적 기본값
    _skillBaseStatic.forEach((k, base) {
      final c = widget.stat[k];
      if (c != null && c.text.trim().isEmpty) c.text = base.toString();
    });

    // 2) 동적 기본값
    int _asInt(String k) =>
        int.tryParse(widget.stat[k]?.text.trim() ?? '') ?? 0;
    // 회피 = 민첩(DEX) / 2
    final dex = _asInt('민첩');
    final dodge = (dex / 2).floor();
    if (widget.stat['회피'] != null && widget.stat['회피']!.text.trim().isEmpty) {
      widget.stat['회피']!.text = dodge.toString();
    }
    // 모국어 = 교육(EDU)
    final edu = _asInt('교육');
    if (widget.stat['모국어'] != null && widget.stat['모국어']!.text.trim().isEmpty) {
      widget.stat['모국어']!.text = edu.toString();
    }
  }

  void _recalc() {
    final d = widget.rules.derive(_collect());
    setState(() {
      _maxHp = (d['maxHp'] ?? 0) as int;
      _maxMp = (d['maxMp'] ?? 0) as int;
      _san = (d['SAN'] ?? 0) as int;
      _db = '${d['DB'] ?? ''}';
      _build = (d['Build'] ?? 0) as int;
    });
  }

  Widget _field({
    required TextEditingController? c,
    required String label,
    bool number = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType: number ? TextInputType.number : TextInputType.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 탐사자 기본 정보 ───────────────────────────────────────
              const Text(
                '탐사자 정보',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              _field(c: widget.general['name'], label: '이름', number: false),
              _field(c: widget.general['sex'], label: '성별', number: false),
              _field(c: widget.general['age'], label: '나이', number: true),
              _field(c: widget.general['job'], label: '직업', number: false),
              const SizedBox(height: 12),

              // ── 주요 특성치 ───────────────────────────────────────────
              const Text(
                '주요 특성치',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              for (final k in _coreStats)
                _field(c: widget.stat[k], label: k, number: true),
              const SizedBox(height: 12),

              // ── 파생 능력치(표시 전용) ────────────────────────────────
              const Text(
                '파생 능력치',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text('체력: ${widget.hp}/$_maxHp'),
              Text('마력: ${widget.mp}/$_maxMp'),
              Text('이성(SAN): $_san'),
              Text('피해 보너스: $_db'),
              Text('체구(Build): $_build'),
              const SizedBox(height: 12),

              // ── 광기/발작 관련 ────────────────────────────────────────
              const Text(
                '광기/발작 관련',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              _field(
                c: widget.general['temporaryInsanity'],
                label: '일시적 광기',
                number: true,
              ),
              _field(
                c: widget.general['indefiniteInsanity'],
                label: '장기적 광기',
                number: true,
              ),
              _field(
                c: widget.general['insanityOutburst'],
                label: '광기의 발작',
                number: true,
              ),
              const SizedBox(height: 12),

              // ── 탐사자 기능(스킬) ────────────────────────────────────
              const Text(
                '탐사자 기능',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 640;
                  final col = isWide ? 2 : 1;
                  return GridView.count(
                    crossAxisCount: col,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: isWide ? 4.2 : 6.2,
                    children: [
                      for (final k in _skills)
                        TextFormField(
                          controller: widget.stat[k],
                          decoration: InputDecoration(
                            labelText: k,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      _seeded = false;
                      _seedDefaultsOnce();
                      setState(() {});
                    },
                    child: const Text('기본값 다시 채우기'),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: widget.onClose,
                        child: const Text('닫기'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: widget.onSave,
                        child: const Text('저장'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
