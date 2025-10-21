import '../core/rules_engine.dart';
import '../core/dice.dart';

class Coc7eRules implements TrpgRules {
  @override
  String get systemId => 'coc7e';

  @override
  Map<String, dynamic> initialData() => {
        '근력': 50,
        '건강': 50,
        '크기': 50,
        '민첩': 50,
        '외모': 50,
        '지능': 50,
        '교육': 50,
        '정신력': 50,
        '행운': 50,
        'skills': {},
      };

  @override
  Map<String, dynamic> derive(Map<String, dynamic> d) {
    int asInt(String k) =>
        (d[k] is int) ? d[k] : int.tryParse('${d[k] ?? 0}') ?? 0;
    final con = asInt('건강'),
        siz = asInt('크기'),
        pow = asInt('정신력'),
        str = asInt('근력');

    final maxHp = ((con + siz) / 10).floor();
    final maxMp = (pow / 5).floor();
    final san = (pow * 5);

    final sum = str + siz;
    String db;
    int build;
    if (sum <= 64) {
      db = '-2';
      build = -2;
    } else if (sum <= 84) {
      db = '-1';
      build = -1;
    } else if (sum <= 124) {
      db = '0';
      build = 0;
    } else if (sum <= 164) {
      db = '+1d4';
      build = 1;
    } else if (sum <= 204) {
      db = '+1d6';
      build = 2;
    } else {
      db = '+2d6';
      build = 3;
    }

    return {
      ...d,
      'maxHp': maxHp,
      'maxMp': maxMp,
      'SAN': san,
      'DB': db,
      'Build': build,
    };
  }

  @override
  List<ValidationIssue> validate(Map<String, dynamic> d) => [];

  @override
  RollResult rollCheck(String kind, Map<String, dynamic> ctx) {
    if (kind == 'skill' || kind == 'check') {
      final target = (ctx['target'] as int?) ?? 50;
      final r = Dice.roll('d100');
      final success = r.total <= target;
      String level;
      if (r.total <= (target / 5).floor()) {
        level = 'Extreme';
      } else if (r.total <= (target / 2).floor()) {
        level = 'Hard';
      } else {
        level = success ? 'Regular' : 'Fail';
      }
      return RollResult(
        detail: 'd100: ${r.total} vs $target → $level',
        total: r.total,
        success: success,
      );
    }
    throw UnimplementedError();
  }
}
