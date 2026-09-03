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

  test('tolerates branches with missing/blank city or district', () {
    // `Branch.city`/`district` are optional server-side (schema.prisma:
    // `city String?` / `district String?`); a real tenant can create a
    // branch without them. The list must still load rather than throwing.
    final organization = OrganizationSummaryDto.fromJson({
      'slug': 'infosystems',
      'name': 'Инфосистемс',
      'branches': [
        {
          'id': 'branch-1',
          'name': 'Үндсэн салбар',
          'city': null,
          'district': '   ',
        },
      ],
    }).toDomain();

    final branch = organization.branches.single;
    expect(branch.city, '');
    expect(branch.district, '');
    expect(branch.locationLabel, '');
  });

  test('locationLabel joins only the parts the API provided', () {
    final organization = OrganizationSummaryDto.fromJson({
      'slug': 'infosystems',
      'name': 'Инфосистемс',
      'branches': [
        {
          'id': 'branch-1',
          'name': 'Үндсэн салбар',
          'city': 'Улаанбаатар',
          'district': null,
        },
      ],
    }).toDomain();

    expect(organization.branches.single.locationLabel, 'Улаанбаатар');
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
