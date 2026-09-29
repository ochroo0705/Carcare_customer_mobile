import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockAppointmentRepository extends Mock implements AppointmentRepository {}
class MockServiceHistoryRepository extends Mock implements ServiceHistoryRepository {}
class MockVehicleRepository extends Mock implements VehicleRepository {}
class MockNotificationsRepository extends Mock implements NotificationsRepository {}
class MockOrganizationRepository extends Mock implements OrganizationRepository {}
class MockRemotePushService extends Mock implements RemotePushService {}

const testAccount = Account(id: '1', phone: '99112233');

/// The always-signed-in auth double that 5+ test files each re-declared.
MockAuthRepository signedInAuthRepository({Account account = testAccount}) {
  final auth = MockAuthRepository();
  when(() => auth.onSessionInvalidated).thenAnswer((_) => const Stream.empty());
  when(() => auth.restoreSession()).thenAnswer((_) async => account);
  when(() => auth.requestOtp(any())).thenAnswer((_) async {});
  when(() => auth.verifyOtp(
        phone: any(named: 'phone'),
        code: any(named: 'code'),
        name: any(named: 'name'),
      )).thenAnswer((_) async => (account: account, reactivated: false));
  when(() => auth.signOut()).thenAnswer((_) async {});
  when(() => auth.requestClosureOtp()).thenAnswer((_) async => '****1234');
  when(() => auth.deactivateAccount(any())).thenAnswer((_) async {});
  when(() => auth.deleteAccount(any())).thenAnswer((_) async {});
  return auth;
}

/// Call from `setUpAll` in any file that uses `any()` on a non-primitive
/// argument type. Add a `registerFallbackValue` line here when mocktail's
/// error names a missing type.
void registerMockFallbacks() {}
