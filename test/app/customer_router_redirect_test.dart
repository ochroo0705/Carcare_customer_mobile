import 'package:carcare_customer_mobile/app/customer_router.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? r(String loc, {required bool authed}) =>
      customerRedirect(isAuthenticated: authed, uri: Uri.parse(loc));

  test('booking requires auth and remembers where it was going', () {
    final to = r('/organizations/auto-doctor/book?branch=b1&keys=a,b', authed: false);
    expect(to, startsWith('/login?from='));
    expect(Uri.parse(to!).queryParameters['from'],
        '/organizations/auto-doctor/book?branch=b1&keys=a,b');
  });

  test('signed-in booking is left alone', () {
    expect(r('/organizations/auto-doctor/book', authed: true), isNull);
  });

  test('account closure bounces to the shell when signed out', () {
    expect(r('/account/close', authed: false), '/');
    expect(r('/account/close', authed: true), isNull);
  });

  test('login with a from target forwards once signed in', () {
    expect(r('/login?from=%2Forganizations%2Fx%2Fbook', authed: true),
        '/organizations/x/book');
  });

  test('everything else is public', () {
    for (final p in ['/', '/organizations/x', '/notifications', '/vehicles/add']) {
      expect(r(p, authed: false), isNull, reason: p);
    }
  });

  group('resolveLockedCategoryIds', () {
    test('matches the picked service keys on the given branch', () async {
      final repository = FakeOrganizationRepository(delay: Duration.zero);
      final detail = await repository.getOrganization('auto-doctor');
      final ids = resolveLockedCategoryIds(
        detail,
        'auto-doctor-bzd',
        {'oil-change', 'car-wash'},
      );
      expect(
        ids.toSet(),
        {'auto-doctor-bzd-oil-change', 'auto-doctor-bzd-car-wash'},
      );
    });

    test('an unknown branch resolves to nothing', () async {
      final repository = FakeOrganizationRepository(delay: Duration.zero);
      final detail = await repository.getOrganization('auto-doctor');
      final ids = resolveLockedCategoryIds(detail, 'no-such-branch', {'oil-change'});
      expect(ids, isEmpty);
    });
  });
}
