import 'dart:async';

import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostic_report_list_item.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/presentation/controllers/diagnostics_controller.dart';
import 'package:flutter_test/flutter_test.dart';

DiagnosticReportListItem _report(String id) => DiagnosticReportListItem(
  id: id,
  templateName: 'T',
  type: 'GENERAL',
  createdAt: DateTime(2026, 1, 1),
  vehiclePlate: '1234УБА',
  vehicleMake: 'Toyota',
  vehicleModel: 'Prius',
  branchName: 'Branch',
);

DiagnosticPage _page(int page, {required bool hasNext, required String id}) =>
    DiagnosticPage(
      reports: [_report(id)],
      pagination: DiagnosticPagination(
        page: page,
        pageSize: 1,
        total: 3,
        totalPages: 3,
        hasPrev: page > 1,
        hasNext: hasNext,
      ),
    );

/// Each call is answered by a completer the test controls.
class _ManualRepo implements DiagnosticsRepository {
  final calls = <(DiagnosticFilter, Completer<DiagnosticPage>)>[];

  @override
  Future<DiagnosticPage> getDiagnostics({
    DiagnosticFilter filter = const DiagnosticFilter(),
  }) {
    final completer = Completer<DiagnosticPage>();
    calls.add((filter, completer));
    return completer.future;
  }

  @override
  Future<Never> getDiagnosticDetail(String id) => throw UnimplementedError();
}

void main() {
  test('a superseded loadMore cannot leave isLoadingMore stuck', () async {
    final repository = _ManualRepo();
    final controller = DiagnosticsController(repository);
    addTearDown(controller.dispose);

    final first = controller.load();
    repository.calls[0].$2.complete(_page(1, hasNext: true, id: 'a'));
    await first;

    final more = controller.loadMore();
    expect(controller.isLoadingMore, isTrue);

    // A query change supersedes the in-flight append; its debounced reload
    // has not started yet when the append finishes.
    controller.setQuery('x');
    repository.calls[1].$2.complete(_page(2, hasNext: true, id: 'b'));
    await more;

    expect(controller.isLoadingMore, isFalse);
    expect(controller.reports.single.id, 'a');
  });
}
