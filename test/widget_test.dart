import 'package:flutter_test/flutter_test.dart';
import 'package:bookme/main.dart';

void main() {
  testWidgets('BookMe app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BookMeApp());
    expect(find.byType(BookMeApp), findsOneWidget);
  });
}
