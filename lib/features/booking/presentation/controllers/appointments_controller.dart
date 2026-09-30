import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_progress.dart';
import 'package:carcare_customer_mobile/features/booking/domain/walk_in_order.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_state.dart';
import 'package:flutter/foundation.dart';

class AppointmentsController extends ChangeNotifier {
  AppointmentsController(this._repository, {CacheStore? cache})
    : _cache = cache ?? const NoopCacheStore();

  final AppointmentRepository _repository;
  final CacheStore _cache;
  AppointmentsState _state = const AppointmentsState();
  final Set<String> _cancellingIds = {};

  // Bumped by every [load] and by [reset]. A load whose generation is no
  // longer current (a newer load started, or the user signed out meanwhile)
  // must not touch state or the disk cache — otherwise a load in flight at
  // sign-out puts the previous account's appointments back.
  int _generation = 0;

  // Bumped ONLY by [reset]. Tells a sign-out apart from a merely superseded
  // load: the former must wipe the disk cache, the latter must leave it alone
  // (the newer load's fresh write lives there).
  int _epoch = 0;

  // True while the lists on screen came from a successful network load (not
  // the disk cache). A failed refresh must then keep them rather than swap
  // them for an older cached copy or an error screen.
  bool _hasLiveData = false;

  /// Fired after a cancel succeeds server-side. The router wires this to
  /// `historyController.load()`.
  ///
  /// Why it exists: cancelling is a *terminal* transition, and History renders
  /// a dedicated cancelled-appointments section of its own
  /// (`ServiceHistoryRepository.getCancelledAppointments()` →
  /// `ServiceHistoryPage.cancelledAppointments`, drawn by
  /// `history_screen.dart`). Reloading only this controller makes the
  /// appointment vanish from Appointments without ever appearing in History
  /// until something unrelated reloads it.
  ///
  /// The staff-side terminal transitions (`appointment_rejected`,
  /// `appointment_expired`, `appointment_no_show`) already reload both lists
  /// via the router's `_reloadListsForPushType`; this is the local-action
  /// equivalent of that same rule.
  ///
  /// Kept as a callback rather than a `HistoryController` reference so this
  /// controller stays independent of the history feature — same pattern as
  /// `AuthController.beforeSignOut`.
  VoidCallback? onAppointmentCancelled;

  String _searchQuery = '';
  // Selected status label (`AppointmentStatusUi.localizedLabel` /
  // `ServiceProgressStatusUi.localizedLabel`) — kept as a display-label
  // rather than a typed enum so both tabs' filter share one shape. `null`
  // means "all statuses". Single-select: choosing a new label replaces the
  // previous one.
  String? _selectedAppointmentStatus;
  String? _selectedWalkInStatus;

  AppointmentsState get state => _state;

  String get searchQuery => _searchQuery;
  String? get selectedAppointmentStatus => _selectedAppointmentStatus;
  String? get selectedWalkInStatus => _selectedWalkInStatus;

  bool isCancelling(String id) => _cancellingIds.contains(id);

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  /// Selecting the already-selected label clears the filter (tap again to
  /// reset to "all").
  void selectAppointmentStatus(String? label) {
    _selectedAppointmentStatus = _selectedAppointmentStatus == label
        ? null
        : label;
    notifyListeners();
  }

  void selectWalkInStatus(String? label) {
    _selectedWalkInStatus = _selectedWalkInStatus == label ? null : label;
    notifyListeners();
  }

  /// The status a card actually displays (serviceProgress status once a
  /// linked order exists, otherwise the appointment's own workflow status) —
  /// matches `_AppointmentCard`'s chip logic so the filter matches what the
  /// user sees.
  String _appointmentDisplayStatus(Appointment appointment) =>
      appointment.serviceProgress?.status.localizedLabel ??
      appointment.status.localizedLabel;

  /// Distinct status labels available to filter by, computed from the
  /// currently loaded (not yet status-filtered) list so chips don't disappear
  /// once selected.
  List<String> get availableAppointmentStatuses => {
    for (final appointment in _state.appointments)
      _appointmentDisplayStatus(appointment),
  }.toList(growable: false);

  List<String> get availableWalkInStatuses => {
    for (final order in _state.walkInOrders)
      order.progress.status.localizedLabel,
  }.toList(growable: false);

  bool _matchesSearch(String haystack) {
    final query = _searchQuery.trim().toLowerCase();
    return query.isEmpty || haystack.toLowerCase().contains(query);
  }

  /// `sortedAppointments`-той ижил "бүрэн дуусаад бүрэн төлөгдсөн" хамгаалалт
  /// (харах: түүний доод коммент) — walk-in захиалгад ч мөн адил хэрэглэнэ.
  /// Мөн ижил хайлт/төлвийн шүүлтүүрийг хэрэглэнэ.
  List<WalkInOrder> get visibleWalkInOrders => _state.walkInOrders
      .where((order) => !order.progress.isSettled)
      .where(
        (order) => _matchesSearch('${order.tenantName} ${order.branchName}'),
      )
      .where(
        (order) =>
            _selectedWalkInStatus == null ||
            order.progress.status.localizedLabel == _selectedWalkInStatus,
      )
      .toList(growable: false);

  /// Active хүсэлтүүдийг ойрын цагаар нь, эцсийн төлөвүүдийг сүүлийн өөрчлөлт
  /// гэж үзэн шинэ огноогоор нь харуулна. Бүрэн дуусаад бүрэн төлөгдсөн
  /// (isSettled) захиалга энд огт харагдахгүй — түүхэнд шилжсэн гэж үзнэ
  /// (server /api/v1/app/appointments аль хэдийн шүүсэн байх ёстой; энэ нь
  /// зөвхөн кэшлэгдсэн хуучин датаны хамгаалалт). Repository-ийн буцаасан
  /// list нь unmodifiable байж болох тул энд заавал хуулж байж sort хийнэ.
  /// Хайлт/төлвийн шүүлтүүр (search bar, status chips) мөн энд хэрэгжинэ.
  List<Appointment> get sortedAppointments {
    final visible = _state.appointments
        .where((appointment) => appointment.serviceProgress?.isSettled != true)
        .where(
          (appointment) => _matchesSearch(
            '${appointment.tenantName} ${appointment.branchName} '
            '${appointment.vehiclePlate ?? ''}',
          ),
        )
        .where(
          (appointment) =>
              _selectedAppointmentStatus == null ||
              _appointmentDisplayStatus(appointment) ==
                  _selectedAppointmentStatus,
        );
    final active =
        visible.where((appointment) => appointment.status.isActive).toList()
          ..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
    final inactive =
        visible.where((appointment) => !appointment.status.isActive).toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return [...active, ...inactive];
  }

  Future<void> load() => _load(silent: false);

  /// Background refresh for pollers: no `loading` transition, and listeners
  /// are notified only when what is on screen actually changed. Skipped
  /// entirely while another load is in flight so slow polls cannot pile up.
  /// Failure handling is the same as [load] (live data is kept).
  Future<void> refreshSilently() async {
    if (_inFlight > 0) return;
    await _load(silent: true);
  }

  Future<void> _load({required bool silent}) async {
    final generation = ++_generation;
    final epoch = _epoch;
    _inFlight++;
    try {
      await _loadBody(generation, epoch, silent: silent);
    } finally {
      _inFlight--;
    }
  }

  Future<void> _loadBody(
    int generation,
    int epoch, {
    required bool silent,
  }) async {
    if (!silent) {
      _state = AppointmentsState(
        status: AppointmentsStatus.loading,
        appointments: _state.appointments,
        walkInOrders: _state.walkInOrders,
      );
      notifyListeners();
    }
    final previous = _state;
    var changed = true;
    try {
      // Network амжилттай үед cache-г бүхэлд нь солих нь өмнөх Account-ийн
      // үлдэгдэл болон шинэ response холилдохоос сэргийлнэ. walkInOrders
      // тусдаа дуудлага (харах: `RemoteAppointmentRepository.getWalkInOrders`)
      // тул зэрэгцүүлж дуудна — аль нэг нь амжилтгүй болвол бүгд амжилтгүй
      // (эс бөгөөс хагас бүрдсэн, зөрчилтэй төлөв харагдана).
      final results = await Future.wait([
        _repository.getAppointments(),
        _repository.getWalkInOrders(),
      ]);
      if (generation != _generation) return;
      final appointments = results[0] as List<Appointment>;
      final walkInOrders = results[1] as List<WalkInOrder>;
      _state = AppointmentsState(
        status: appointments.isEmpty && walkInOrders.isEmpty
            ? AppointmentsStatus.empty
            : AppointmentsStatus.data,
        appointments: appointments,
        walkInOrders: walkInOrders,
      );
      _hasLiveData = _state.status == AppointmentsStatus.data;
      changed = !silent || !_sameContent(previous, _state);
      await _cache.writeAppointments(appointments);
      if (epoch != _epoch) {
        // Signed out during the write: do not leave this account's
        // appointments on disk, and do not notify.
        await _cache.clearAppointments();
        return;
      }
      // Superseded by a newer load: its cache write is the current one, so
      // neither clear nor notify.
      if (generation != _generation) return;
    } on AppFailure catch (failure) {
      if (generation != _generation) return;
      if (_keepLiveData(failure.message)) {
        if (!silent || !_sameContent(previous, _state)) notifyListeners();
        return;
      }
      // Cache нь source of truth биш: зөвхөн сүүлийн амжилттай fetch-ийг
      // offline үед харуулна, failure message-г state дээр хадгална.
      final fallback = await _fallbackToCache(failure.message);
      if (generation != _generation) return;
      _state = fallback;
      _hasLiveData = false;
    } catch (_) {
      if (generation != _generation) return;
      if (_keepLiveData('Тодорхойгүй алдаа гарлаа.')) {
        if (!silent || !_sameContent(previous, _state)) notifyListeners();
        return;
      }
      final fallback = await _fallbackToCache('Тодорхойгүй алдаа гарлаа.');
      if (generation != _generation) return;
      _state = fallback;
      _hasLiveData = false;
    }
    if (changed) notifyListeners();
  }

  // Loads currently running (silent or not); guards [refreshSilently].
  int _inFlight = 0;

  // The domain models have no value equality, so unchanged-data detection
  // compares a field-by-field fingerprint of everything the UI renders.
  bool _sameContent(AppointmentsState a, AppointmentsState b) =>
      a.status == b.status &&
      a.message == b.message &&
      a.isFromCache == b.isFromCache &&
      _fingerprint(a) == _fingerprint(b);

  String _fingerprint(AppointmentsState s) {
    final buffer = StringBuffer();
    for (final a in s.appointments) {
      buffer
        ..write('A|${a.id}|${a.status.name}|${a.requestedAt.toIso8601String()}')
        ..write('|${a.tenantName}|${a.tenantSlug}|${a.branchName}|${a.note}')
        ..write('|${a.categoryNames.join(',')}|${a.vehiclePlate}');
      final p = a.payment;
      if (p != null) {
        buffer.write(
          '|pay:${p.status.name},${p.amount},${p.currency},'
          '${p.underpaidAmount},${p.qrText},${p.qrImageBase64.hashCode},'
          '${p.urls.map((u) => '${u.name}~${u.nameMn}~${u.link}~${u.logo.hashCode}~${u.description}').join(';')}',
        );
      }
      _writeProgress(buffer, a.serviceProgress);
      buffer.writeln();
    }
    for (final w in s.walkInOrders) {
      buffer.write('W|${w.tenantName}|${w.tenantSlug}|${w.branchName}');
      _writeProgress(buffer, w.progress);
      buffer.writeln();
    }
    return buffer.toString();
  }

  void _writeProgress(StringBuffer b, AppointmentServiceProgress? p) {
    if (p == null) return;
    b.write(
      '|sp:${p.id},${p.number},${p.status.name},${p.paymentStatus.name},'
      '${p.scheduledAt?.toIso8601String()},${p.startedAt?.toIso8601String()},'
      '${p.completedAt?.toIso8601String()},${p.estimatedDurationMinutes},'
      '${p.expectedFinishAt?.toIso8601String()},${p.totalAmount},'
      '${p.paidAmount},${p.vehiclePlate},${p.vehicleMake},${p.vehicleModel},'
      '${p.vehicleYear},${p.scheduledReturnAt?.toIso8601String()}',
    );
    for (final i in p.items) {
      b.write(
        '|it:${i.id},${i.name},${i.status.name},${i.kind.name},${i.quantity},'
        '${i.unitPrice},${i.total}',
      );
    }
    for (final h in p.statusHistory) {
      b.write(
        '|h:${h.id},${h.fromStatus?.name},${h.toStatus.name},'
        '${h.reasonTag?.name},${h.createdAt.toIso8601String()}',
      );
    }
    for (final r in p.reports) {
      b.write(
        '|r:${r.id},${r.templateName},${r.type},'
        '${r.createdAt.toIso8601String()},${r.mileageAtReport}',
      );
    }
  }

  /// Resets to the initial state and clears the on-disk cache, e.g. after
  /// the customer signs out — the next account must never see this one's
  /// cached appointments.
  Future<void> reset() async {
    _generation++;
    _epoch++;
    _hasLiveData = false;
    _state = const AppointmentsState();
    _cancellingIds.clear();
    _searchQuery = '';
    _selectedAppointmentStatus = null;
    _selectedWalkInStatus = null;
    notifyListeners();
    await _cache.clearAppointments();
  }

  /// Keeps the live lists on screen after a failed refresh; returns false
  /// when nothing live is showing and the cache/error fallback should apply.
  bool _keepLiveData(String failureMessage) {
    if (!_hasLiveData) return false;
    _state = AppointmentsState(
      status: AppointmentsStatus.data,
      appointments: _state.appointments,
      walkInOrders: _state.walkInOrders,
      message: failureMessage,
    );
    return true;
  }

  Future<AppointmentsState> _fallbackToCache(String failureMessage) async {
    final cached = await _cache.readAppointments() ?? const <Appointment>[];
    // The cache holds appointments only; walk-ins already in memory are
    // carried over so they do not vanish on a failed refresh.
    final walkInOrders = _state.walkInOrders;
    if (cached.isEmpty && walkInOrders.isEmpty) {
      return AppointmentsState(
        status: AppointmentsStatus.error,
        message: failureMessage,
      );
    }
    return AppointmentsState(
      status: AppointmentsStatus.data,
      appointments: cached,
      walkInOrders: walkInOrders,
      isFromCache: true,
      message: failureMessage,
    );
  }

  /// Cancels an appointment and reloads the list. Returns an error message on
  /// failure, or `null` on success.
  Future<String?> cancel(String id) async {
    if (_cancellingIds.contains(id)) return null;
    _cancellingIds.add(id);
    notifyListeners();
    try {
      await _repository.cancelAppointment(id);
      // Fired before awaiting our own reload so History refreshes in parallel,
      // and so it still fires if `load()` fails — the cancel already
      // succeeded server-side, so History is stale either way.
      onAppointmentCancelled?.call();
      await load();
      return null;
    } on AppFailure catch (failure) {
      return failure.message;
    } catch (_) {
      return 'Тодорхойгүй алдаа гарлаа.';
    } finally {
      _cancellingIds.remove(id);
      notifyListeners();
    }
  }
}
