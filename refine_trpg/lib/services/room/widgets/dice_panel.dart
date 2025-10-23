// lib/screens/room/widgets/dice_panel.dart
import 'dart:math';
import 'package:flutter/material.dart';

class DicePanel extends StatelessWidget {
  final List<int> diceFaces;
  final Map<int, int> diceCounts;
  final Function(int face, bool increment) onCountChanged; // 카운트 변경 콜백
  final VoidCallback onRoll; // 굴리기 콜백

  const DicePanel({
    super.key,
    required this.diceFaces,
    required this.diceCounts,
    required this.onCountChanged,
    required this.onRoll,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).cardColor,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('주사위 패널', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: diceFaces.map((face) {
                return GestureDetector(
                  onTap: () => onCountChanged(face, true), // Increment
                  onLongPress: () => onCountChanged(face, false), // Decrement
                  onSecondaryTap: () => onCountChanged(face, false), // Decrement (web)
                  child: Card(
                    elevation: 2,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text('d$face', style: const TextStyle(fontSize: 18)),
                        if ((diceCounts[face] ?? 0) > 0)
                          Positioned(
                            top: 4, right: 4,
                            child: CircleAvatar(
                              radius: 11,
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              child: Text('${diceCounts[face]}', style: const TextStyle(fontSize: 11)),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRoll, // 굴리기 콜백 연결
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
              child: const Text('굴리기'),
            ),
          ],
        ),
      ),
    );
  }
}