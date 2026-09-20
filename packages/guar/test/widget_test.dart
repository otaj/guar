// Smoke test that the empty app widget tree builds.
import 'package:flutter_test/flutter_test.dart';
import 'package:guar/main.dart';

void main() {
  testWidgets('app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MainApp());
    expect(find.text('Hello World!'), findsOneWidget);
  });
}
