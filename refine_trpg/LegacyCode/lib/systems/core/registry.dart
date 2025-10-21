import '../coc7e/coc7e_rules.dart';
import '../dnd5e/dnd5e_rules.dart';
import 'rules_engine.dart';

final Map<String, TrpgRules> _systems = {
  'coc7e': Coc7eRules(),
  'dnd5e': Dnd5eRules(),
};

TrpgRules useRules(String systemId) => _systems[systemId] ?? _systems['coc7e']!;
