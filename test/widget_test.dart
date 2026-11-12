import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:nutrition_app/main.dart';

void main() {
  testWidgets('Nutrition app opens and health setup route works', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NutritionApp());

    expect(find.text('วิเคราะห์โภชนาการ AI'), findsOneWidget);

    Navigator.of(tester.element(find.text('วิเคราะห์โภชนาการ AI')))
        .pushNamed('/health');
    await tester.pumpAndSettle();

    expect(find.text('ข้อมูลสุขภาพของคุณ'), findsOneWidget);
    expect(find.text('ถัดไป'), findsOneWidget);
  });
}
