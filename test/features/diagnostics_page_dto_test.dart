import 'package:carcare_customer_mobile/features/diagnostics/data/diagnostic_report_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses diagnostics pagination and available years', () {
    final page = diagnosticPageFromJson({
      'reports': [
        {
          'id': 'r1',
          'templateName': 'Үзлэг',
          'type': 'INTAKE',
          'createdAt': '2026-01-02T00:00:00Z',
          'vehicle': {'plate': '1234УБА'},
          'branch': {'name': 'Салбар'},
        },
      ],
      'pagination': {
        'page': 2,
        'pageSize': 20,
        'total': 21,
        'totalPages': 2,
        'hasPrev': true,
        'hasNext': false,
      },
      'availableYears': [2026, 2025],
    });

    expect(page.reports, hasLength(1));
    expect(page.pagination.page, 2);
    expect(page.pagination.total, 21);
    expect(page.availableYears, [2026, 2025]);
  });
}
