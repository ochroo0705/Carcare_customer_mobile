import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/walk_in_order.dart';

enum AppointmentsStatus { initial, loading, data, empty, error }

class AppointmentsState {
  const AppointmentsState({
    this.status = AppointmentsStatus.initial,
    this.appointments = const [],
    this.walkInOrders = const [],
    this.message,
    this.isFromCache = false,
  });

  final AppointmentsStatus status;
  final List<Appointment> appointments;
  // Appointment-гүй (staff шууд үүсгэсэн) захиалгууд. Offline кэш дэмждэггүй
  // (CacheStore зөвхөн appointments-г хадгалдаг) — сүлжээгүй үед хоосон
  // харагдана, `appointments` кэшлэгдсэн хэвээр байхад ч мөн адил.
  final List<WalkInOrder> walkInOrders;
  final String? message;

  /// True when [appointments] is the last successfully loaded list, shown
  /// because a fresh load just failed (e.g. no network) rather than because
  /// it is currently up to date.
  final bool isFromCache;

  bool get isLoading =>
      status == AppointmentsStatus.initial ||
      status == AppointmentsStatus.loading;
}
