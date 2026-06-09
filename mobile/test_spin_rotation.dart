import 'dart:math';

// Copied sector list from mobile code
const List<Map<String, dynamic>> wheelSectors = [
  {"label": "Lose", "isWin": false}, // 0
  {"label": "0.1x", "isWin": true}, // 1
  {"label": "10x", "isWin": true}, // 2
  {"label": "0.2x", "isWin": true}, // 3
  {"label": "0.4x", "isWin": true}, // 4
  {"label": "20x", "isWin": true}, // 5
  {"label": "0.5x", "isWin": true}, // 6
  {"label": "0.6x", "isWin": true}, // 7
  {"label": "30x", "isWin": true}, // 8
  {"label": "0.8x", "isWin": true}, // 9
  {"label": "1x", "isWin": true}, // 10
  {"label": "40x", "isWin": true}, // 11
  {"label": "1.1x", "isWin": true}, // 12
  {"label": "Lose", "isWin": false}, // 13
  {"label": "50x", "isWin": true}, // 14
  {"label": "1.2x", "isWin": true}, // 15
  {"label": "1.5x", "isWin": true}, // 16
  {"label": "2x", "isWin": true}, // 17
  {"label": "3x", "isWin": true}, // 18
  {"label": "5x", "isWin": true}, // 19
];

void main() {
  final double sectorRadians = (2 * pi) / wheelSectors.length;
  const double pointerAngle = 3 * pi / 2; // top of wheel

  print(
    'Sector Radians: $sectorRadians (${sectorRadians * 180 / pi} degrees)\n',
  );

  for (int targetIndex = 0; targetIndex < wheelSectors.length; targetIndex++) {
    final double sectorCenterAngle =
        targetIndex * sectorRadians + (sectorRadians / 2.0);

    double targetAngleNormalized =
        (pointerAngle - sectorCenterAngle) % (2 * pi);
    if (targetAngleNormalized < 0) targetAngleNormalized += (2 * pi);

    // Let's verify what sector center lands at pointerAngle (3 * pi / 2)
    // if we rotate by targetAngleNormalized.
    final double finalAngleOfSector =
        (sectorCenterAngle + targetAngleNormalized) % (2 * pi);
    final double diff = (finalAngleOfSector - pointerAngle).abs();

    final label = wheelSectors[targetIndex]['label'];
    print('Target Index $targetIndex ($label):');
    print('  Sector Center Angle: ${sectorCenterAngle * 180 / pi}°');
    print('  Required Rotation:   ${targetAngleNormalized * 180 / pi}°');
    print(
      '  Final Screen Angle:  ${finalAngleOfSector * 180 / pi}° (Expected ${pointerAngle * 180 / pi}°)',
    );
    print('  Diff:                $diff');
  }
}
