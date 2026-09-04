import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';

/// A small checkerboard placeholder, clearly not a real QPay QR — this is
/// fake-repository data, never scannable. Mirrors the shape of a real QPay
/// QR PNG closely enough to exercise `AppointmentPaymentScreen`'s rendering.
const _fakeQrImageBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAPAAAADwCAIAAACxN37FAAADc0lEQVR4nO3d0W7aQBRAQVz1/3/Z'
    'fUBFLgZHQEOWszMPkQCZGyUn1hLZ2tMJAAB4xPLi8eu6Pjl4eWm0uebenPXrlakwGkGTImhSBE2K'
    'oEkRNCmCJkXQpAiaFEGTImhSBE2KoEkRNCmCBhjVP1dhP3o19wwXj5v7WXMtOUgRNCmCJkXQpAia'
    'FEGTImhSBE2KoEkRNCmCJkXQpAiaFEGTImhSBE2KoEkRNMCobBpk7sfPtWkQWYImRdCkCJoUQZMi'
    'aFIETYqgSRE0KYImRdCkCJoUQZMiaFIETYqgSRE0KYIGGJV9Cs1NzbXkIEXQpAiaFEGTImhSBE2K'
    'oEkRNCmCJkXQpAiaFEGTImhSBE2KoEkRNCmCJkXQAKOyT6G5Hz/XPoVkCZoUQZMiaFIETYqgSRE0'
    'KYImRdCkCJoUQZMiaFIETYqgSRE0KYImRdCkCJqUV2/BGtDTdw3N6cV7pUYT3KdQ0P/LmL/fY5Yc'
    'pAiaFEGTImhSBE2KoEkRNCmCJkXQpAiaFEGTImhSBE3K75/+Bt7t6kqudV23z2wfXr10ddTxm++P'
    'dQ3ge0x6hl7/Ou1S2z+8PLM9au9c8PnVZVm2R51ylx0Pa9Kgl2X58gy6jfLeUYxm0qC3J9pzo9uv'
    'F/von1g5bM/cfLdJg97bB3dzqfDESdqS452CP+Xjc+H2c9vp8GPcvScPRtx7t8vDAc/Tsb+06fYp'
    'fINh273pm27Q/Kl9Cqf7t90bfErKSdbQpAiaFEGTImhSBE2KoEkRNCmCJkXQpAiaFEGTImhSBE2K'
    'oEkRNCmCJkXQpKTuJztzw8hDyvcUNvYpNHfmuZYcpAiaFEGTImhSBE2KoEkRNCmCJkXQpAiaFEGT'
    'ImhSBE2KoEkRNCmCJkXQpAgaYFTT7VNobm/udpYlBymCJkXQpAiaFEGTImhSBE2KoEkRNCmCJkXQ'
    'pAiaFEGTImhSBE2KoEkRNCmCBhiVfQrNTc215CBF0KQImhRBkyJoUgRNiqBJETQpgiZF0KQImhRB'
    'kyJoUgRNiqBJETQpgiZF0ACjsk+huR8/1z6FZAmaFEGTImhSBE2KoEkRNCmCJkXQpAiaFEGTImhS'
    'BE2KoEkRNCmCJkXQpAgaYFT2KTQ3NdeSgxRBkyJoUgRNiqBJETQpgiZF0KQImhRBkyJoUgRNiqBJ'
    'ETQAAMDE/gBwMEiw9t/dIgAAAABJRU5ErkJggg==';

class FakeAppointmentRepository implements AppointmentRepository {
  FakeAppointmentRepository() : _now = DateTime.now();

  final DateTime _now;
  late final List<Appointment> _appointments = [
    Appointment(
      id: 'seed-1',
      status: AppointmentStatus.confirmed,
      requestedAt: _now.add(const Duration(days: 2, hours: 3)),
      tenantName: 'Инфосистемс',
      tenantSlug: 'infosystems',
      branchName: 'Үндсэн салбар',
      categoryName: 'Тоормос',
    ),
    Appointment(
      id: 'seed-2',
      status: AppointmentStatus.pending,
      requestedAt: _now.add(const Duration(days: 5)),
      tenantName: 'Тэсо Моторс',
      tenantSlug: 'teso-motors',
      branchName: 'Хан-Уул салбар',
      payment: _pendingPayment(),
    ),
    Appointment(
      id: 'seed-3',
      status: AppointmentStatus.cancelled,
      requestedAt: _now.subtract(const Duration(days: 10)),
      tenantName: 'Инфосистемс',
      tenantSlug: 'infosystems',
      branchName: 'Үндсэн салбар',
    ),
  ];
  var _sequence = 0;

  /// Simulates the platform's fee setting (`PlatformSetting.appointmentFee*`
  /// on web) defaulting to enabled — see `CUSTOMER_API_CONTRACT.md`.
  static AppointmentPayment _pendingPayment() => const AppointmentPayment(
    status: AppointmentFeeStatus.pending,
    amount: 1000,
    currency: 'MNT',
    qrImageBase64: _fakeQrImageBase64,
    qrText: 'qpay://fake-invoice',
    urls: [
      QpayBankUrl(
        name: 'Khan bank',
        nameMn: 'Хаан банк',
        logo: '',
        link: 'khanbank://q?qPay_QRcode=FAKE',
      ),
      QpayBankUrl(
        name: 'Trade and Development bank',
        nameMn: 'Худалдаа хөгжлийн банк',
        logo: '',
        link: 'tdbbank://q?qPay_QRcode=FAKE',
      ),
    ],
  );

  /// Tracks how many times `checkPayment` has been called per appointment,
  /// so the first check reports "not yet paid" and the second reports
  /// "paid" — exercising both branches of the payment screen without a real
  /// QPay backend.
  final Map<String, int> _checkAttempts = {};

  @override
  Future<CreatedAppointment> createAppointment({
    required String branchId,
    required DateTime requestedAt,
    String? note,
    String? accountVehicleId,
  }) async {
    _sequence += 1;
    final id = 'fake-appointment-$_sequence';
    final payment = _pendingPayment();
    _appointments.insert(
      0,
      Appointment(
        id: id,
        status: AppointmentStatus.pending,
        requestedAt: requestedAt,
        tenantName: 'Таны сонгосон байгууллага',
        tenantSlug: branchId,
        branchName: 'Сонгосон салбар',
        note: note,
        payment: payment,
      ),
    );
    return CreatedAppointment(
      id: id,
      status: 'PENDING',
      requestedAt: requestedAt,
      payment: payment,
    );
  }

  @override
  Future<List<Appointment>> getAppointments() async =>
      List.unmodifiable(_appointments);

  @override
  Future<void> cancelAppointment(String id) async {
    final index = _appointments.indexWhere(
      (appointment) => appointment.id == id,
    );
    if (index == -1) throw const NotFoundFailure();
    final appointment = _appointments[index];
    if (!appointment.status.canCancel) throw const ConflictFailure();
    _appointments[index] = appointment.copyWith(
      status: AppointmentStatus.cancelled,
    );
  }

  @override
  Future<AppointmentPayment?> getPayment(String appointmentId) async {
    final appointment = _appointments
        .where((appointment) => appointment.id == appointmentId)
        .firstOrNull;
    if (appointment == null) throw const NotFoundFailure();
    return appointment.payment;
  }

  @override
  Future<AppointmentPaymentCheckResult> checkPayment(
    String appointmentId,
  ) async {
    final index = _appointments.indexWhere(
      (appointment) => appointment.id == appointmentId,
    );
    if (index == -1) throw const NotFoundFailure();
    final attempts = (_checkAttempts[appointmentId] ?? 0) + 1;
    _checkAttempts[appointmentId] = attempts;
    if (attempts < 2) {
      return const AppointmentPaymentCheckResult(paid: false);
    }
    final appointment = _appointments[index];
    final payment = appointment.payment;
    if (payment == null) throw const ConflictFailure();
    _appointments[index] = appointment.copyWith(
      payment: AppointmentPayment(
        status: AppointmentFeeStatus.paid,
        amount: payment.amount,
        currency: payment.currency,
      ),
    );
    return const AppointmentPaymentCheckResult(paid: true);
  }

  @override
  Future<AppointmentPayment?> retryPayment(String appointmentId) async {
    final index = _appointments.indexWhere(
      (appointment) => appointment.id == appointmentId,
    );
    if (index == -1) throw const NotFoundFailure();
    final payment = _pendingPayment();
    _appointments[index] = _appointments[index].copyWith(payment: payment);
    _checkAttempts.remove(appointmentId);
    return payment;
  }
}
