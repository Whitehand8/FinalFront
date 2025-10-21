import 'package:flutter/material.dart';
import '../../core/rules_engine.dart';

class Dnd5eSheet extends StatefulWidget {
  final TrpgRules rules;
  final Map<String, TextEditingController> stat;
  final Map<String, TextEditingController> general;
  final VoidCallback onSave;
  final VoidCallback onClose;

  const Dnd5eSheet({
    super.key,
    required this.rules,
    required this.stat,
    required this.general,
    required this.onSave,
    required this.onClose,
  });

  @override
  State<Dnd5eSheet> createState() => _Dnd5eSheetState();
}

class _Dnd5eSheetState extends State<Dnd5eSheet> {
  int _ac = 10, _prof = 2, _passive = 10;
  Map<String, int> _mods = const {};
  final List<VoidCallback> _listeners = [];

  @override
  void initState() {
    super.initState();
    _attach();
    _recalc();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _attach() {
    void add(TextEditingController c) {
      void f() => _recalc();
      c.addListener(f);
      _listeners.add(() => c.removeListener(f));
    }

    for (final c in [...widget.stat.values, ...widget.general.values]) {
      add(c);
    }
  }

  void _detach() {
    for (final off in _listeners) off();
    _listeners.clear();
  }

  dynamic _parse(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty) return 0;
    if (t == 'true' || t == 'false') return t == 'true';
    return int.tryParse(t) ?? s;
  }

  Map<String, dynamic> _collect() {
    final stats = <String, dynamic>{};
    final general = <String, dynamic>{};
    widget.stat.forEach((k, c) => stats[k] = _parse(c.text));
    widget.general.forEach((k, c) => general[k] = _parse(c.text));
    return {'stats': stats, 'general': general};
  }

  int _asInt(dynamic v, {int orElse = 0}) {
    if (v is int) return v;
    if (v is double) return v.floor();
    if (v is String) return int.tryParse(v) ?? orElse;
    return orElse;
  }

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return false;
  }

  int _mod(int score) => ((score - 10) / 2).floor();

  int _profByLevel(int level) {
    if (level <= 4) return 2;
    if (level <= 8) return 3;
    if (level <= 12) return 4;
    if (level <= 16) return 5;
    return 6;
  }

  void _recalc() {
    final data = _collect();
    final stats = Map<String, dynamic>.from(data['stats'] ?? {});
    final general = Map<String, dynamic>.from(data['general'] ?? {});

    // Run rules derive
    final d = widget.rules.derive(data);
    // derive may return nested under 'derived'
    final Map<String, dynamic> derived = Map<String, dynamic>.from(
      (d['derived'] is Map) ? d['derived'] as Map : d,
    );

    // ability mods
    final mods = Map<String, int>.from(
      (derived['mods'] is Map)
          ? Map<String, dynamic>.from(
            derived['mods'],
          ).map((k, v) => MapEntry(k, _asInt(v)))
          : const {},
    );

    // proficiency bonus (fallback from level)
    final prof = _asInt(
      derived['proficiency'],
      orElse: _profByLevel(_asInt(general['level'], orElse: 1)),
    );

    // AC calculation (fallback if rules didn't supply): baseAC + DEX mod + (shield?+2)
    int ac = _asInt(derived['AC'], orElse: -999);
    if (ac == -999) {
      final baseAC = _asInt(general['baseAC'], orElse: 10);
      final dex = _asInt(stats['DEX'], orElse: 10);
      final shield = _asBool(general['shield']);
      ac = baseAC + _mod(dex) + (shield ? 2 : 0);
    }

    // Passive Perception: 10 + WIS mod + (proficiency if proficient)
    int passive = _asInt(derived['passivePerception'], orElse: -999);
    if (passive == -999) {
      final wis = _asInt(stats['WIS'], orElse: 10);
      final wisMod = _mod(wis);
      final perceptProf = _asBool(general['perceptionProficient']);
      passive = 10 + wisMod + (perceptProf ? prof : 0);
    }

    setState(() {
      _ac = ac;
      _prof = prof;
      _passive = passive;
      _mods = mods;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget _badge(String label, String value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      child: Text('$label: $value'),
    );

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Derived (D&D 5e)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Wrap(
                children: [
                  _badge('AC', '$_ac'),
                  _badge('Prof', '+$_prof'),
                  _badge('Passive Perception', '$_passive'),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Ability Mods'),
              Wrap(
                children: [
                  _badge('STR', '${_mods['STR'] ?? 0}'),
                  _badge('DEX', '${_mods['DEX'] ?? 0}'),
                  _badge('CON', '${_mods['CON'] ?? 0}'),
                  _badge('INT', '${_mods['INT'] ?? 0}'),
                  _badge('WIS', '${_mods['WIS'] ?? 0}'),
                  _badge('CHA', '${_mods['CHA'] ?? 0}'),
                ],
              ),

              const SizedBox(height: 16),
              Text(
                'Rolls',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              // ↓ 필요 시 D&D 전용 입력/장비/공격/주문 섹션을 여기에 추가하세요.
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
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
        ),
      ),
    );
  }
}
