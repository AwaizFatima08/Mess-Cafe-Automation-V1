import 'package:flutter_test/flutter_test.dart';
import 'package:employee_flutter_app/main.dart';

void main() {
  testWidgets('MessCafeApp builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MessCafeApp());
    expect(find.text('Mess & Cafe Automation V1'), findsOneWidget);
  });
}
