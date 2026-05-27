class VersionComparer {
  /// Compares two semantic version strings (e.g. "1.0.0" and "1.1.0").
  /// Returns:
  /// - `1` if [v1] is greater than [v2]
  /// - `-1` if [v1] is less than [v2]
  /// - `0` if [v1] is equal to [v2]
  static int compare(String v1, String v2) {
    final v1Clean = v1.split('+').first;
    final v2Clean = v2.split('+').first;

    final v1Parts = v1Clean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final v2Parts = v2Clean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;

    for (int i = 0; i < maxLen; i++) {
      final part1 = i < v1Parts.length ? v1Parts[i] : 0;
      final part2 = i < v2Parts.length ? v2Parts[i] : 0;

      if (part1 > part2) return 1;
      if (part1 < part2) return -1;
    }

    return 0;
  }
}
