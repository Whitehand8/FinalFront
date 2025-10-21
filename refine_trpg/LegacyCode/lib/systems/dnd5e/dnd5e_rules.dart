import '../core/rules_engine.dart';
import '../core/dice.dart';

class Dnd5eRules implements TrpgRules {
  @override
  String get systemId => 'dnd5e';

  int _mod(int score) => ((score - 10) / 2).floor();
  int _prof(int level) => 2 + ((level - 1) / 4).floor();

  @override
  Map<String, dynamic> initialData() => {
    'STR': 10,
    'DEX': 10,
    'CON': 10,
    'INT': 10,
    'WIS': 10,
    'CHA': 10,
    'level': 1,
    'baseAC': 10,
    'shield': false,
    'perceptionProficient': false,
  };

  @override
  Map<String, dynamic> derive(Map<String, dynamic> d) {
    int asInt(String k) =>
        (d[k] is int) ? d[k] : int.tryParse('${d[k] ?? 0}') ?? 10;
    final level = asInt('level');
    final prof = _prof(level);
    final dexMod = _mod(asInt('DEX'));
    final wisMod = _mod(asInt('WIS'));
    final ac = (asInt('baseAC')) + dexMod + ((d['shield'] == true) ? 2 : 0);
    final passivePerception =
        10 + wisMod + ((d['perceptionProficient'] == true) ? prof : 0);

    return {
      ...d,
      'mods': {
        'STR': _mod(asInt('STR')),
        'DEX': dexMod,
        'CON': _mod(asInt('CON')),
        'INT': _mod(asInt('INT')),
        'WIS': wisMod,
        'CHA': _mod(asInt('CHA')),
      },
      'prof': prof,
      'AC': ac,
      'passivePerception': passivePerception,
    };
  }

  @override
  List<ValidationIssue> validate(Map<String, dynamic> d) {
    final issues = <ValidationIssue>[];

    int asInt(String k, {int orElse = 0}) =>
        (d[k] is int) ? d[k] : int.tryParse('${d[k] ?? ''}') ?? orElse;

    // level: 1..20
    final level = asInt('level', orElse: 1);
    if (level < 1 || level > 20) {
      issues.add(ValidationIssue('level', '레벨은 1~20 사이여야 합니다.'));
    }

    // ability scores: 1..20
    for (final k in const ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA']) {
      final v = asInt(k, orElse: -9999);
      if (v == -9999) {
        issues.add(ValidationIssue(k, '숫자를 입력하세요.'));
      } else if (v < 1 || v > 20) {
        issues.add(ValidationIssue(k, '값은 1~20 사이여야 합니다.'));
      }
    }

    // base AC sanity (typical 10~20 range in vanilla; you can relax if needed)
    final baseAC = asInt('baseAC', orElse: 10);
    if (baseAC < 8 || baseAC > 20) {
      issues.add(ValidationIssue('baseAC', '기본 AC는 8~20 범위를 권장합니다.'));
    }

    // shield must be boolean
    final shield = d['shield'];
    if (shield != null && shield is! bool) {
      issues.add(ValidationIssue('shield', '방패 값은 true/false여야 합니다.'));
    }

    return issues;
  }

  @override
  RollResult rollCheck(String kind, Map<String, dynamic> ctx) {
    // advantage: 'adv' | 'dis' | null
    final adv = ctx['advantage'] as String?; // optional

    // helpers to obtain stat/proficiency from either ctx['mods']/ctx['prof'] or raw stats/level
    int asInt(dynamic v, {int orElse = 0}) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? orElse;
      return orElse;
    }

    int getMod(String ability) {
      final mods = ctx['mods'];
      if (mods is Map && mods[ability] != null) return asInt(mods[ability]);
      // fallback compute from raw score
      final stats = (ctx['stats'] is Map) ? ctx['stats'] as Map : ctx;
      final score = asInt(stats[ability] ?? 10, orElse: 10);
      return _mod(score);
    }

    int getProf() {
      final p = ctx['prof'];
      if (p is int) return p;
      // fallback from level
      final general = (ctx['general'] is Map) ? ctx['general'] as Map : ctx;
      final level = asInt(general['level'] ?? ctx['level'] ?? 1, orElse: 1);
      return _prof(level);
    }

    switch (kind) {
      case 'ability':
        {
          // generic ability check: ctx.ability('STR'..), prof(bool), dc(int?)
          final ability = (ctx['ability']?.toString().toUpperCase() ?? 'DEX');
          final profFlag = (ctx['prof'] == true);
          final dc = (ctx['dc'] is int) ? ctx['dc'] as int : null;

          final mod = getMod(ability);
          final profBonus = profFlag ? getProf() : 0;
          final r = Dice.rollD20(adv);
          final total = r.total + mod + profBonus;
          final success = dc == null ? true : total >= dc;
          final detail =
              'Ability d20' +
              (adv == null ? '' : '($adv)') +
              ': ${r.detail} + mod($mod) + prof($profBonus) = $total' +
              (dc == null ? '' : ' vs DC $dc');
          return RollResult(detail: detail, total: total, success: success);
        }
      case 'skill':
        {
          // ctx: ability('STR'..), prof(bool), expertise(bool?), dc(int?)
          final ability = (ctx['ability']?.toString().toUpperCase() ?? 'DEX');
          final profFlag = (ctx['prof'] == true);
          final expertise = (ctx['expertise'] == true);
          final dc = (ctx['dc'] is int) ? ctx['dc'] as int : null;

          final mod = getMod(ability);
          final profBonus =
              profFlag ? (expertise ? getProf() * 2 : getProf()) : 0;
          final r = Dice.rollD20(adv);
          final total = r.total + mod + profBonus;
          final success = dc == null ? true : total >= dc;
          final detail =
              'd20${adv == null ? '' : '($adv)'}: ${r.detail} + mod($mod) + prof($profBonus) = $total' +
              (dc == null ? '' : ' vs DC $dc');
          return RollResult(detail: detail, total: total, success: success);
        }
      case 'save':
        {
          // ctx: ability, prof(bool), dc(int?)
          final ability = (ctx['ability']?.toString().toUpperCase() ?? 'CON');
          final profFlag = (ctx['prof'] == true);
          final dc = (ctx['dc'] is int) ? ctx['dc'] as int : null;

          final mod = getMod(ability);
          final profBonus = profFlag ? getProf() : 0;
          final r = Dice.rollD20(adv);
          final total = r.total + mod + profBonus;
          final success = dc == null ? true : total >= dc;
          final detail =
              'Save d20${adv == null ? '' : '($adv)'}: ${r.detail} + mod($mod) + prof($profBonus) = $total' +
              (dc == null ? '' : ' vs DC $dc');
          return RollResult(detail: detail, total: total, success: success);
        }
      case 'attack':
        {
          // ctx: ability('STR'|'DEX'), prof(bool), bonus(int), targetAC(int)
          final ability = (ctx['ability']?.toString().toUpperCase() ?? 'STR');
          final profFlag = (ctx['prof'] == true);
          final bonus = asInt(ctx['bonus'], orElse: 0);
          final targetAC = asInt(ctx['targetAC'], orElse: 10);

          final mod = getMod(ability);
          final profBonus = profFlag ? getProf() : 0;
          final r = Dice.rollD20(adv);
          final total = r.total + mod + profBonus + bonus;
          final success = total >= targetAC;
          final detail =
              'Attack d20${adv == null ? '' : '($adv)'}: ${r.detail} + mod($mod) + prof($profBonus) + bonus($bonus) = $total vs AC $targetAC';
          return RollResult(detail: detail, total: total, success: success);
        }
      default:
        {
          // Backward compatibility: treat as ability check using a flat modifier
          final baseMod = asInt(ctx['modifier'], orElse: 0);
          final r = Dice.rollD20(adv);
          final total = r.total + baseMod;
          final dc = (ctx['dc'] is int) ? ctx['dc'] as int : null;
          final success = dc == null ? true : total >= dc;
          final detail =
              'd20' +
              (adv == null ? '' : '($adv)') +
              ': ${r.detail} + $baseMod = $total' +
              (dc == null ? '' : ' vs DC $dc');
          return RollResult(detail: detail, total: total, success: success);
        }
    }
  }
}
