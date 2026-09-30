import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/availability.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_state.dart';
import 'package:flutter/foundation.dart';

/// How a [BookingFormController.submit] call ended. The screen turns this into
/// navigation (`onCompleted` / `onUnauthenticated`); the controller itself
/// stays free of callbacks.
enum BookingSubmitStatus {
  /// Validation failed or another submit was already in flight. Nothing was
  /// sent.
  ignored,
  completed,
  unauthenticated,
  failed,
}

class BookingSubmitOutcome {
  const BookingSubmitOutcome(this.status, [this.created]);

  final BookingSubmitStatus status;
  final CreatedAppointment? created;
}

/// Form state and submit logic of the booking request screen. Owned by the
/// screen (created in `initState`, disposed in `dispose`).
class BookingFormController extends ChangeNotifier {
  BookingFormController({
    required this.organization,
    required this.repository,
    required this.vehiclesController,
    this.initialBranchId,
    this.initialCategoryIds,
    this.lockCategories = false,
    this.lockBranch = false,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _initSelection();
    final now = _clock();
    displayedMonth = DateTime(now.year, now.month);
    vehiclesController.addListener(_maybeAutoSelectSingleVehicle);
    final state = vehiclesController.state;
    if (state.status == VehiclesStatus.initial) {
      vehiclesController.load();
    } else if (_shouldAutoSelectVehicle(state)) {
      // Vehicles were already loaded before this screen opened; set directly
      // (no listener is attached to the widget tree yet).
      selectedVehicleId = state.vehicles.single.id;
    }
  }

  final OrganizationDetail organization;
  final AppointmentRepository repository;
  final VehiclesController vehiclesController;
  final String? initialBranchId;
  final List<String>? initialCategoryIds;
  final bool lockCategories;
  final bool lockBranch;
  final DateTime Function() _clock;

  late DateTime displayedMonth;
  // Category-first: эхлээд үйлчилгээгээ сонгоно, дараа нь ЗӨВХӨН тэдгээрийг
  // БҮГДийг нь санал болгодог салбарууд харагдана. Категори сонгогдоогүй бол
  // салбар сонгох боломжгүй (null) — ганц тохиромжтой салбар байвал автоматаар
  // сонгогдоно.
  BranchDetail? selectedBranch;
  DateTime? selectedDate;
  ({int hour, int minute})? selectedSlot;
  final Set<String> selectedCategoryIds = <String>{};
  String? selectedVehicleId;
  bool _userTouchedVehicle = false;
  bool submitting = false;
  String? error;

  // Availability endpoint-ийн төлөв (booking v2).
  DayAvailability? availability;
  bool loadingSlots = false;
  String? slotsError;

  /// Огноо/салбар/ангилал хурдан дараалан солиход хуучин хүсэлтийн хариу
  /// шинэ сонголтыг дарж бичихээс сэргийлнэ — зөвхөн ХАМГИЙН СҮҮЛД эхэлсэн
  /// `loadAvailability` дуудлагын хариу л хэрэглэгдэнэ.
  int _availabilityRequestId = 0;
  bool _disposed = false;

  /// [lockCategories] үед: `initialBranchId` энэ байгууллагын салбарын
  /// жагсаалтад олдсонгүй — аюулгүй орлуулагч байхгүй; хэрэглэгчийг буцаана.
  bool lockedBranchMissing = false;

  /// [lockCategories] үед: `initialCategoryIds`-аас энэ салбар ЦААШИД санал
  /// болгодоггүй болсон ангиллуудын нэрс — зөвхөн сануулах зорилготой.
  List<String> lockedUnavailableCategoryNames = const [];

  void _initSelection() {
    final preferredMatches = organization.branches
        .where((branch) => branch.id == initialBranchId)
        .toList(growable: false);
    final preferredBranch = preferredMatches.isEmpty
        ? null
        : preferredMatches.first;
    // `lockCategories` үед `initialBranchId` олдоогүй бол ганц-салбарын
    // fallback-аар БУСАД салбарыг чимээгүйхэн сонгуулахгүй.
    selectedBranch =
        preferredBranch ??
        (!lockCategories && !lockBranch && organization.branches.length == 1
            ? organization.branches.single
            : null);
    if (lockBranch && preferredBranch == null) {
      lockedBranchMissing = true;
    }
    if (lockCategories) {
      final requestedCategoryIds = initialCategoryIds ?? const [];
      final branch = selectedBranch;
      if (branch == null) {
        lockedBranchMissing = true;
      } else {
        // Салбар өөрийн ангиллаа өөрчилсөн байж болзошгүй тул ХАРЬЯАЛАГДАХГҮЙ
        // болсон ангилал бүрийг мэдэгдэнэ, зөвхөн ХАРЬЯАЛАГДАХЫГ сонгоно.
        final offeredIds = branch.categories.map((c) => c.id).toSet();
        final unavailableNames = <String>[];
        for (final id in requestedCategoryIds) {
          if (offeredIds.contains(id)) {
            selectedCategoryIds.add(id);
          } else {
            final name = allCategories
                .where((category) => category.id == id)
                .map((category) => category.name)
                .firstOrNull;
            unavailableNames.add(name ?? id);
          }
        }
        lockedUnavailableCategoryNames = unavailableNames;
      }
    }
  }

  /// [lockCategories] урсгал үргэлжлэх боломжгүй тохиолдол: салбар огт
  /// олдоогүй, эсвэл сонгосон ангилал БҮГД цаашид санал болгогдохгүй болсон.
  bool get lockedFlowBlocked =>
      ((lockCategories || lockBranch) && lockedBranchMissing) ||
      (lockCategories &&
          selectedCategoryIds.isEmpty &&
          (initialCategoryIds?.isNotEmpty ?? false));

  /// [lockBranch] үед зөвхөн ТУХАЙН салбарын ангиллууд; бусад тохиолдолд
  /// байгууллагын БҮХ салбарын ангиллын нэгдэл (давхардалгүй, нэрээр эрэмбэлсэн).
  List<BranchServiceCategory> get allCategories {
    if (lockBranch) {
      final categories = <BranchServiceCategory>[
        ...(selectedBranch?.categories ?? const <BranchServiceCategory>[]),
      ];
      categories.sort((a, b) => a.name.compareTo(b.name));
      return categories;
    }
    final byId = <String, BranchServiceCategory>{};
    for (final branch in organization.branches) {
      for (final category in branch.categories) {
        byId[category.id] = category;
      }
    }
    final values = byId.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return values;
  }

  /// Сонгосон ангилал БҮГДийг санал болгодог салбарууд (АНД).
  List<BranchDetail> get compatibleBranches => organization.branches
      .where(
        (branch) => selectedCategoryIds.every(
          (id) => branch.categories.any((category) => category.id == id),
        ),
      )
      .toList(growable: false);

  /// Сонгосон ангилалуудын нийт хугацаа (booking v2).
  int get selectedDurationMinutes => (selectedBranch?.categories ?? const [])
      .where((category) => selectedCategoryIds.contains(category.id))
      .fold(0, (sum, category) => sum + category.durationMinutes);

  /// Сонгосон нүхний бодит UTC мөч — `availability`-аас, device-local
  /// hour/minute-ээс биш.
  DateTime? get requestedAt {
    final slot = selectedSlot;
    if (slot == null) return null;
    return availability?.slots
        .where((s) => s.time == slot)
        .map((s) => s.utc)
        .firstOrNull;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setDisplayedMonth(DateTime month) {
    displayedMonth = month;
    _notify();
  }

  void selectDate(DateTime date) {
    selectedDate = date;
    selectedSlot = null;
    error = null;
    _notify();
    loadAvailability();
  }

  void selectSlot(({int hour, int minute}) slot) {
    selectedSlot = slot;
    error = null;
    _notify();
  }

  /// Салбар солиход: хугацаа өөрчлөгдөж болох тул сонгосон цаг болон боломжит
  /// цагийн жагсаалтыг цэвэрлэж дахин татна.
  void selectBranch(BranchDetail branch) {
    if (branch.id == selectedBranch?.id) return;
    selectedBranch = branch;
    selectedSlot = null;
    availability = null;
    slotsError = null;
    error = null;
    _notify();
    if (selectedDate != null) loadAvailability();
  }

  /// Ангилал сонгох/цуцлахад: тохирох салбаруудыг дахин тооцоод, одоо сонгосон
  /// салбар цаашид тохирохгүй бол — ганц тохирох салбар үлдсэн бол автоматаар
  /// түүнийг сонгоно, эс бөгөөс дахин сонгуулахаар null болгоно.
  void toggleCategory(String categoryId, bool selected) {
    if (selected) {
      selectedCategoryIds.add(categoryId);
    } else {
      selectedCategoryIds.remove(categoryId);
    }
    // `lockBranch` үед selectedBranch хэзээ ч солигдохгүй — allCategories аль
    // хэдийн тухайн салбарын ангиллаар хязгаарлагдсан.
    if (!lockBranch) {
      final compatible = compatibleBranches;
      final stillValid =
          selectedBranch != null &&
          compatible.any((b) => b.id == selectedBranch!.id);
      if (!stillValid) {
        selectedBranch = compatible.length == 1 ? compatible.single : null;
        selectedDate = null;
      }
    }
    selectedSlot = null;
    availability = null;
    slotsError = null;
    error = null;
    _notify();
    if (selectedDate != null) loadAvailability();
  }

  void selectVehicle(String? id) {
    _userTouchedVehicle = true;
    selectedVehicleId = id;
    _notify();
  }

  /// Сонгосон салбар + өдөр + ангилалуудад тохирох боломжит цагуудыг татна.
  Future<void> loadAvailability() async {
    final branch = selectedBranch;
    final date = selectedDate;
    if (branch == null || date == null) return;
    final requestId = ++_availabilityRequestId;
    loadingSlots = true;
    slotsError = null;
    availability = null;
    selectedSlot = null;
    _notify();
    try {
      final result = await repository.getAvailability(
        branchId: branch.id,
        date: date,
        categoryIds: selectedCategoryIds.toList(),
      );
      if (!_disposed && requestId == _availabilityRequestId) {
        availability = result;
        loadingSlots = false;
        _notify();
      }
    } on AppFailure catch (failure) {
      if (!_disposed && requestId == _availabilityRequestId) {
        slotsError = failure.message;
        loadingSlots = false;
        _notify();
      }
    } catch (_) {
      if (!_disposed && requestId == _availabilityRequestId) {
        slotsError = 'Цаг ачаалж чадсангүй.';
        loadingSlots = false;
        _notify();
      }
    }
  }

  /// Апп background-оос буцаж ирэхэд сонгосон огноо/цаг хугацаандаа хоцорсон
  /// эсвэл дүүрсэн байж болзошгүй — дахин ачаална (сонгосон цагийг цэвэрлэнэ).
  void onAppResumed() {
    final branch = selectedBranch;
    final date = selectedDate;
    if (branch == null || date == null) return;
    final today = _clock();
    final todayKey = DateTime(today.year, today.month, today.day);
    if (date.isBefore(todayKey)) {
      selectedDate = null;
      selectedSlot = null;
      availability = null;
      slotsError = null;
      _notify();
      return;
    }
    loadAvailability();
  }

  /// Pre-selects the customer's vehicle when they own exactly one, so a
  /// single-car customer doesn't have to open the picker. Any manual change —
  /// including choosing "Сонгохгүй" — disables it, so it never fights them.
  bool _shouldAutoSelectVehicle(VehiclesState state) =>
      !_userTouchedVehicle &&
      selectedVehicleId == null &&
      state.status == VehiclesStatus.data &&
      state.vehicles.length == 1;

  void _maybeAutoSelectSingleVehicle() {
    final state = vehiclesController.state;
    if (_disposed || !_shouldAutoSelectVehicle(state)) return;
    selectedVehicleId = state.vehicles.single.id;
    _notify();
  }

  /// Sends the booking request. Returns immediately (`ignored`) while another
  /// submit is in flight, so a double tap cannot create duplicate bookings.
  Future<BookingSubmitOutcome> submit(String note) async {
    if (submitting) {
      return const BookingSubmitOutcome(BookingSubmitStatus.ignored);
    }
    final branch = selectedBranch;
    if (branch == null) {
      error = 'Эхлээд үйлчилгээ, дараа нь салбараа сонгоно уу.';
      _notify();
      return const BookingSubmitOutcome(BookingSubmitStatus.ignored);
    }
    final at = requestedAt;
    if (at == null || !at.isAfter(_clock())) {
      error = 'Ирээдүйн өдөр, цаг сонгоно уу.';
      _notify();
      return const BookingSubmitOutcome(BookingSubmitStatus.ignored);
    }
    submitting = true;
    error = null;
    _notify();
    try {
      final result = await repository.createAppointment(
        branchId: branch.id,
        requestedAt: at,
        note: note,
        accountVehicleId: selectedVehicleId,
        categoryIds: selectedCategoryIds.toList(),
      );
      return BookingSubmitOutcome(BookingSubmitStatus.completed, result);
    } on UnauthenticatedFailure {
      return const BookingSubmitOutcome(BookingSubmitStatus.unauthenticated);
    } on ConflictFailure catch (failure) {
      error = failure.message;
      return const BookingSubmitOutcome(BookingSubmitStatus.failed);
    } on AppFailure catch (failure) {
      error = failure.message;
      return const BookingSubmitOutcome(BookingSubmitStatus.failed);
    } finally {
      submitting = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    vehiclesController.removeListener(_maybeAutoSelectSingleVehicle);
    super.dispose();
  }
}
