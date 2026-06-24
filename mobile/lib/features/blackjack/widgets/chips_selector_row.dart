import 'package:flutter/material.dart';
import 'poker_chip.dart';

class ChipsSelectorRow extends StatelessWidget {
  final double selectedBet;
  final ValueChanged<double> onBetSelected;

  const ChipsSelectorRow({
    super.key,
    required this.selectedBet,
    required this.onBetSelected,
  });

  @override
  Widget build(BuildContext context) {
    final chips = [
      {'val': 100.0, 'label': '100', 'color': const Color(0xFFB91C1C)},
      {'val': 500.0, 'label': '500', 'color': const Color(0xFF15803D)},
      {'val': 1000.0, 'label': '1K', 'color': const Color(0xFF1D4ED8)},
      {'val': 5000.0, 'label': '5K', 'color': const Color(0xFF374151)},
      {'val': 10000.0, 'label': '10K', 'color': const Color(0xFF6D28D9)},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.5),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.chevron_left,
              color: Colors.white54,
              size: 22,
            ),
            onPressed: () {
              int idx = chips.indexWhere((c) => c['val'] == selectedBet);
              if (idx > 0) {
                onBetSelected(chips[idx - 1]['val'] as double);
              }
            },
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: chips.map((c) {
                  final val = c['val'] as double;
                  final label = c['label'] as String;
                  final color = c['color'] as Color;
                  final isSelected = selectedBet == val;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: PokerChipWidget(
                      label: label,
                      color: color,
                      size: 42.0,
                      isSelected: isSelected,
                      onTap: () => onBetSelected(val),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.chevron_right,
              color: Colors.white54,
              size: 22,
            ),
            onPressed: () {
              int idx = chips.indexWhere((c) => c['val'] == selectedBet);
              if (idx >= 0 && idx < chips.length - 1) {
                onBetSelected(chips[idx + 1]['val'] as double);
              }
            },
          ),
        ],
      ),
    );
  }
}
