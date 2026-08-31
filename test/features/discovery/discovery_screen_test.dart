import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows organizations and opens details', (tester) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Авто сервисээ\nхялбархан олоорой'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.view_list_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Auto Doctor Service'), findsOneWidget);

    final organizationCard = find.byKey(
      const ValueKey('organization-auto-doctor'),
    );
    await tester.ensureVisible(organizationCard);
    await tester.pumpAndSettle();
    await tester.tap(organizationCard);
    await tester.pumpAndSettle();
    expect(find.text('Баянзүрх салбар'), findsNWidgets(2));
    expect(find.text('Цаг захиалах'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('branch-choice-auto-doctor-sbd')),
    );
    await tester.pumpAndSettle();
    expect(find.text('1-р хороо, Олимпын гудамж 9'), findsOneWidget);
    expect(find.text('09:00–18:00'), findsOneWidget);

    final bookingButton = find.text('Цаг захиалах');
    await tester.ensureVisible(bookingButton);
    await tester.pumpAndSettle();
    await tester.tap(bookingButton);
    await tester.pumpAndSettle();
    expect(find.text('Захиалга эхлүүлэх'), findsOneWidget);
    expect(find.text('Үйлчилгээ сонгох — дараагийн шат'), findsOneWidget);
  });

  testWidgets('shows an explicit empty state', (tester) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          scenario: FakeOrganizationScenario.empty,
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Авто сервис олдсонгүй'), findsOneWidget);
  });

  testWidgets('filters the organization list from search', (tester) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.view_list_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Эрдэнэт');
    await tester.pumpAndSettle();

    expect(find.text('Эрдэнэт Car Care'), findsOneWidget);
    expect(find.text('Auto Doctor Service'), findsNothing);
  });

  testWidgets('shows an error with retry action', (tester) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          scenario: FakeOrganizationScenario.error,
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Мэдээлэл ачаалсангүй'), findsOneWidget);
    expect(find.text('Дахин оролдох'), findsOneWidget);
  });
}
