import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_management/main.dart';

void main() {
  testWidgets('HealthcareApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const HealthcareApp());
    expect(find.text('Portal Sign In'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Doctor'), findsOneWidget);
    expect(find.text('Patient'), findsOneWidget);
  });
}
