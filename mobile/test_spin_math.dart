import 'dart:math';

void main() {
  const sectorsLength = 26;
  const double sectorDegrees = 360.0 / sectorsLength;

  for (int targetIndex = 0; targetIndex < sectorsLength; targetIndex++) {
    // Current formula
    final double targetDegrees = 360 * 5 + (270.0 - (targetIndex * sectorDegrees + (sectorDegrees / 2.0)));
    final double normalizedDegrees = targetDegrees % 360.0;
    
    // Let's verify what sector center lands at 270 (12 o'clock) if we rotate by normalizedDegrees.
    // Sector center = targetIndex * sectorDegrees + sectorDegrees / 2
    final double sectorCenter = targetIndex * sectorDegrees + sectorDegrees / 2.0;
    final double finalPos = (sectorCenter + normalizedDegrees) % 360.0;
    
    print('Index $targetIndex: Center=$sectorCenter, Rotation=$normalizedDegrees, FinalPos=$finalPos (Expected 270.0)');
  }
}
