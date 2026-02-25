import 'package:flutter_test/flutter_test.dart';
import 'package:quicksave_app/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const QuickSaveApp());
    expect(find.text('QuickSave'), findsOneWidget);
  });
}
