import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BranchDetail branch({String? openTime, String? closeTime}) => BranchDetail(
    id: 'branch',
    name: 'Branch',
    city: 'Улаанбаатар',
    district: 'Баянзүрх',
    khoroo: '',
    address: '',
    openTime: openTime,
    closeTime: closeTime,
  );

  test('calculates daytime opening status from local clock', () {
    final subject = branch(openTime: '09:00', closeTime: '18:00');

    expect(
      subject.openStatusAt(DateTime(2026, 9, 1, 9)),
      BranchOpenStatus.open,
    );
    expect(
      subject.openStatusAt(DateTime(2026, 9, 1, 18)),
      BranchOpenStatus.closed,
    );
  });

  test('supports hours that cross midnight', () {
    final subject = branch(openTime: '20:00', closeTime: '03:00');

    expect(
      subject.openStatusAt(DateTime(2026, 9, 1, 23)),
      BranchOpenStatus.open,
    );
    expect(
      subject.openStatusAt(DateTime(2026, 9, 2, 2, 59)),
      BranchOpenStatus.open,
    );
    expect(
      subject.openStatusAt(DateTime(2026, 9, 2, 3)),
      BranchOpenStatus.closed,
    );
  });

  test('returns unknown for absent, invalid, or equal times', () {
    expect(branch().openStatusAt(DateTime.now()), BranchOpenStatus.unknown);
    expect(
      branch(openTime: '9:00', closeTime: '18:00').openStatusAt(DateTime.now()),
      BranchOpenStatus.unknown,
    );
    expect(
      branch(
        openTime: '09:00',
        closeTime: '09:00',
      ).openStatusAt(DateTime.now()),
      BranchOpenStatus.unknown,
    );
  });
}
