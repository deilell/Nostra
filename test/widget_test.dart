import 'package:flutter_test/flutter_test.dart';
import 'package:nostra/app.dart';

void main() {
  testWidgets('App boots', (tester) async {
    await tester.pumpWidget(const NostraApp());
    expect(find.byType(NostraApp), findsOneWidget);
  });
}
