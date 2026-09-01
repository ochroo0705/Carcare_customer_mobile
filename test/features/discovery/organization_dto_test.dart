import 'package:carcare_customer_mobile/features/discovery/data/organization_dto.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the sparse organization list without detail-only fields', () {
    final organization = OrganizationSummaryDto.fromJson({
      'slug': 'infosystems',
      'name': 'Инфосистемс',
      'logoUrl': '/logo.png',
      'branches': [
        {
          'id': 'branch-1',
          'name': 'Үндсэн салбар',
          'city': 'Улаанбаатар',
          'district': 'Баянзүрх',
          'latitude': 47.91,
          'longitude': 106.91,
        },
      ],
    }).toDomain();

    expect(organization.slug, 'infosystems');
    expect(organization.branches.single.latitude, 47.91);
  });

  test('parses detail hours and maps missing hours to unknown', () {
    final organization = OrganizationDetailDto.fromJson({
      'slug': 'infosystems',
      'name': 'Инфосистемс',
      'phone1': '70110000',
      'branches': [
        {
          'id': 'branch-1',
          'name': 'Үндсэн салбар',
          'city': 'Улаанбаатар',
          'district': 'Баянзүрх',
          'khoroo': '1-р хороо',
          'address': 'Нарны зам',
          'openTime': null,
          'closeTime': null,
        },
      ],
    }).toDomain();

    expect(organization.phone, '70110000');
    expect(organization.branches.single.fullAddress, '1-р хороо, Нарны зам');
    expect(
      organization.branches.single.openStatusAt(DateTime.now()),
      BranchOpenStatus.unknown,
    );
  });
}
