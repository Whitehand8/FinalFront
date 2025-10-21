import 'dart:math';

final _rng = Random();

class Dice {
  /// "2d6+1" / "d100" / "3d4-2" 등 지원
  static Roll roll(String expr) {
    final m = RegExp(r'^\s*(\d*)d(\d+)\s*([+-]\s*\d+)?\s*$').firstMatch(expr);
    if (m == null) throw ArgumentError('bad dice expr: $expr');
    final count = (m.group(1)?.isEmpty ?? true) ? 1 : int.parse(m.group(1)!);
    final sides = int.parse(m.group(2)!);
    final mod =
        m.group(3) != null ? int.parse(m.group(3)!.replaceAll(' ', '')) : 0;
    final rolls = List.generate(count, (_) => _rng.nextInt(sides) + 1);
    final total = rolls.fold<int>(0, (a, b) => a + b) + mod;
    return Roll(
      total: total,
      detail:
          '${rolls.toString()}${mod == 0 ? '' : (mod > 0 ? '+$mod' : '$mod')}',
    );
  }

  /// d20 전용: advantage(dis) 지원
  static Roll rollD20([String? adv]) {
    final a = _rng.nextInt(20) + 1, b = _rng.nextInt(20) + 1;
    if (adv == 'adv') {
      final t = a > b ? a : b;
      return Roll(total: t, detail: '[$a,$b]→$t');
    } else if (adv == 'dis') {
      final t = a < b ? a : b;
      return Roll(total: t, detail: '[$a,$b]→$t');
    }
    return Roll(total: a, detail: '[$a]');
  }
}

class Roll {
  final int total;
  final String detail;
  Roll({required this.total, required this.detail});
}
