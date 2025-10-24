import 'package:flutter/material.dart';
import 'package:refine_trpg/systems/core/registry.dart';
import 'package:refine_trpg/systems/core/rules_engine.dart';
import 'package:refine_trpg/systems/coc7e/widgets/coc7e_sheet.dart';
import 'package:refine_trpg/systems/dnd5e/widgets/dnd5e_sheet.dart';

class CharacterSheetRouter extends StatelessWidget {
  final String systemId;
  final Map<String, TextEditingController> statControllers;
  final Map<String, TextEditingController> generalControllers;
  final int hp;
  final int mp;
  final VoidCallback onSave;
  final VoidCallback onClose;

  const CharacterSheetRouter({
    super.key,
    required this.systemId,
    required this.statControllers,
    required this.generalControllers,
    required this.hp,
    required this.mp,
    required this.onSave,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final TrpgRules rules = useRules(systemId);

    switch (systemId) {
      case 'dnd5e':
        return Dnd5eSheet(
          rules: rules,
          stat: statControllers,
          general: generalControllers,
          onSave: onSave,
          onClose: onClose,
        );
      case 'coc7e':
      default:
        return Coc7eSheet(
          rules: rules,
          stat: statControllers,
          general: generalControllers,
          hp: hp,
          mp: mp,
          onSave: onSave,
          onClose: onClose,
        );
    }
  }
}
