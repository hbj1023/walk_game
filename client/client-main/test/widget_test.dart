import 'package:flutter_test/flutter_test.dart';

import 'package:capstone_app/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('WALK MASTER'), findsOneWidget);
  });
}
