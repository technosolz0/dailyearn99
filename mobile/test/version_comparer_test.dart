import 'package:flutter_test/flutter_test.dart';
import 'package:target99/core/utils/version_comparer.dart';

void main() {
  group('VersionComparer Unit Tests', () {
    test('Identical version strings should return 0', () {
      expect(VersionComparer.compare('1.0.0', '1.0.0'), equals(0));
      expect(VersionComparer.compare('2.14.3', '2.14.3'), equals(0));
      expect(VersionComparer.compare('0.0.1', '0.0.1'), equals(0));
    });

    test('Higher patch version should return 1', () {
      expect(VersionComparer.compare('1.0.1', '1.0.0'), equals(1));
    });

    test('Lower patch version should return -1', () {
      expect(VersionComparer.compare('1.0.0', '1.0.1'), equals(-1));
    });

    test('Higher minor version should return 1', () {
      expect(VersionComparer.compare('1.1.0', '1.0.9'), equals(1));
      expect(VersionComparer.compare('2.5.0', '2.4.99'), equals(1));
    });

    test('Lower minor version should return -1', () {
      expect(VersionComparer.compare('1.0.9', '1.1.0'), equals(-1));
    });

    test('Higher major version should return 1', () {
      expect(VersionComparer.compare('2.0.0', '1.9.9'), equals(1));
    });

    test('Lower major version should return -1', () {
      expect(VersionComparer.compare('1.9.9', '2.0.0'), equals(-1));
    });

    test('Build numbers/metadata (+1) should be ignored for version check', () {
      expect(VersionComparer.compare('1.0.0+1', '1.0.0'), equals(0));
      expect(VersionComparer.compare('1.0.0+2', '1.0.0+1'), equals(0));
      expect(VersionComparer.compare('1.0.1+1', '1.0.0+9'), equals(1));
    });

    test('Varying length semantic versions should pad with zero and compare correctly', () {
      expect(VersionComparer.compare('1', '1.0.0'), equals(0));
      expect(VersionComparer.compare('1.1', '1.1.0'), equals(0));
      expect(VersionComparer.compare('1.1.1', '1.1'), equals(1));
      expect(VersionComparer.compare('2', '1.9'), equals(1));
    });
  });
}
