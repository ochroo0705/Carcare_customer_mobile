import 'package:cached_network_image/cached_network_image.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/screens/organization_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _branch = BranchDetail(
  id: 'b1',
  name: 'Үндсэн салбар',
  city: 'Улаанбаатар',
  district: 'Баянзүрх',
  khoroo: '26-р хороо',
  address: 'Нарны зам 18',
);

Future<void> _pump(WidgetTester tester, {String? logoUrl}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: OrganizationDetailScreen(
        organization: OrganizationDetail(
          slug: 'infosystems',
          name: 'Инфосистемс',
          branches: const [_branch],
          logoUrl: logoUrl,
        ),
        status: OrganizationDetailStatus.data,
        errorMessage: null,
        onRetry: () {},
        onBack: () {},
        onBook: (_, _) {},
        isFavorite: false,
        onFavoriteToggle: () {},
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders the organization logo in the hero when a logoUrl exists',
      (tester) async {
    await _pump(tester, logoUrl: 'https://cdn.example.test/logo.png');

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://cdn.example.test/logo.png');
  });

  testWidgets('falls back to the initial letter when no logoUrl is published',
      (tester) async {
    await _pump(tester, logoUrl: null);

    expect(find.byType(CachedNetworkImage), findsNothing);
    // The hero shows the org's first letter ("И" from "Инфосистемс").
    expect(find.text('И'), findsOneWidget);
  });
}
