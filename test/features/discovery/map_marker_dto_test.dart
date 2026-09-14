import 'package:carcare_customer_mobile/features/discovery/data/organization_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses bounded map marker metadata and optional distance', () {
    final page = organizationMapPageFromJson({
      'markers': [
        {
          'id': 'branch-1',
          'orgSlug': 'auto-doctor',
          'orgName': 'Auto Doctor',
          'branchName': 'Баянзүрх',
          'logoUrl': 'https://example.test/logo.png',
          'city': 'Улаанбаатар',
          'district': 'Баянзүрх',
          'latitude': 47.92,
          'longitude': 106.97,
          'distanceKm': 2.4,
        },
      ],
      'count': 501,
      'truncated': true,
      'max': 500,
    });

    expect(page.markers, hasLength(1));
    expect(page.markers.single.orgSlug, 'auto-doctor');
    expect(page.markers.single.distanceKm, 2.4);
    expect(page.count, 501);
    expect(page.truncated, isTrue);
    expect(page.max, 500);
  });
}
