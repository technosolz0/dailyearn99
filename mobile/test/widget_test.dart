import 'package:flutter_test/flutter_test.dart';
import 'package:dailyearn99/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DailyEarn99App());
    expect(find.byType(DailyEarn99App), findsOneWidget);
  });
}
