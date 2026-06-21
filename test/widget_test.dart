import 'package:flutter_test/flutter_test.dart';
import 'package:bookme/main.dart';

void main() {
  testWidgets('MBPractice app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MbPracticeApp());
    expect(find.byType(MbPracticeApp), findsOneWidget);
  });
}
