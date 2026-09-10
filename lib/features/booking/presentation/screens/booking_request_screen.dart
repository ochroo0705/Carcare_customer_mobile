import 'package:cached_network_image/cached_network_image.dart';
import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/availability.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/widgets/booking_calendar.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/widgets/time_slot_grid.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class BookingRequestScreen extends StatefulWidget {
  const BookingRequestScreen({
    required this.organization,
    this.initialBranchId,
    required this.repository,
    required this.onAddVehicle,
    required this.onBack,
    required this.onCompleted,
    required this.onUnauthenticated,
    super.key,
  });

  final OrganizationDetail organization;
  final String? initialBranchId;
  final AppointmentRepository repository;
  final VoidCallback onAddVehicle;
  final VoidCallback onBack;
  final ValueChanged<CreatedAppointment> onCompleted;
  final VoidCallback onUnauthenticated;

  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends State<BookingRequestScreen> {
  final _noteController = TextEditingController();
  late final VehiclesController _vehiclesController;
  late DateTime _displayedMonth;
  // Category-first: эхлээд үйлчилгээгээ сонгоно, дараа нь ЗӨВХӨН тэдгээрийг
  // БҮГДийг нь санал болгодог салбарууд харагдана. Категори сонгогдоогүй бол
  // салбар сонгох боломжгүй (null) — ганц тохиромжтой салбар байвал автоматаар
  // сонгогдоно.
  BranchDetail? _selectedBranch;
  DateTime? _selectedDate;
  ({int hour, int minute})? _selectedSlot;
  final Set<String> _selectedCategoryIds = <String>{};
  String? _selectedVehicleId;
  bool _userTouchedVehicle = false;
  bool _submitting = false;
  String? _error;

  // Availability endpoint-ийн төлөв (booking v2). Огноо/ангилал солигдоход
  // серверээс шинэ цагууд татна.
  DayAvailability? _availability;
  bool _loadingSlots = false;
  String? _slotsError;

  /// Байгууллагын БҮХ салбарт байгаа ангиллууд (давхардалгүй, нэрээр
  /// эрэмбэлэгдсэн) — категори/салбар аль алиныг нь эхлээд сонгож болох
  /// "сольж болдог" сонголтын жагсаалт. Нэг tenant-ийн хүрээнд тул нэршлийн
  /// зөрчил (өөр байгууллагын ижил төстэй нэртэй ангилал) үүсэхгүй.
  List<BranchServiceCategory> get _allCategories {
    final byId = <String, BranchServiceCategory>{};
    for (final branch in widget.organization.branches) {
      for (final category in branch.categories) {
        byId[category.id] = category;
      }
    }
    final values = byId.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return values;
  }

  /// Сонгосон ангилал БҮГДийг санал болгодог салбарууд (АНД) — ангилал огт
  /// сонгоогүй бол БҮХ салбар (`every` хоосон жагсаалт дээр үнэн).
  List<BranchDetail> get _compatibleBranches => widget.organization.branches
      .where(
        (branch) => _selectedCategoryIds.every(
          (id) => branch.categories.any((category) => category.id == id),
        ),
      )
      .toList(growable: false);

  /// Сонгосон ангилалуудын нийт хугацаа (booking v2) — товч мэдээлэлд.
  /// Category-first урсгалд салбар нь сонгосон ангилал БҮГДийг заавал санал
  /// болгодог (`_compatibleBranches`-аас сонгогдсон) тул шууд нийлбэрлэнэ.
  int get _selectedDurationMinutes => (_selectedBranch?.categories ?? const [])
      .where((category) => _selectedCategoryIds.contains(category.id))
      .fold(0, (sum, category) => sum + category.durationMinutes);

  /// Сонгосон салбар + өдөр + ангилалуудад тохирох боломжит цагуудыг серверээс татна.
  Future<void> _loadAvailability() async {
    final branch = _selectedBranch;
    final date = _selectedDate;
    if (branch == null || date == null) return;
    setState(() {
      _loadingSlots = true;
      _slotsError = null;
      _availability = null;
      _selectedSlot = null;
    });
    try {
      final availability = await widget.repository.getAvailability(
        branchId: branch.id,
        date: date,
        categoryIds: _selectedCategoryIds.toList(),
      );
      if (mounted) {
        setState(() {
          _availability = availability;
          _loadingSlots = false;
        });
      }
    } on AppFailure catch (failure) {
      if (mounted) {
        setState(() {
          _slotsError = failure.message;
          _loadingSlots = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _slotsError = 'Цаг ачаалж чадсангүй.';
          _loadingSlots = false;
        });
      }
    }
  }

  DateTime? get _requestedAt {
    final date = _selectedDate;
    final slot = _selectedSlot;
    if (date == null || slot == null) return null;
    return DateTime(date.year, date.month, date.day, slot.hour, slot.minute);
  }

  /// Салбар солиход: хугацаа өөрчлөгдөж болох тул сонгосон цаг болон боломжит
  /// цагийн жагсаалтыг цэвэрлэж дахин татна.
  void _selectBranch(BranchDetail branch) {
    if (branch.id == _selectedBranch?.id) return;
    setState(() {
      _selectedBranch = branch;
      _selectedSlot = null;
      _availability = null;
      _slotsError = null;
      _error = null;
    });
    if (_selectedDate != null) _loadAvailability();
  }

  /// Ангилал сонгох/цуцлахад: тохирох салбаруудыг дахин тооцоод, одоо сонгосон
  /// салбар цаашид тохирохгүй бол — ганц тохирох салбар үлдсэн бол автоматаар
  /// түүнийг сонгоно, эс бөгөөс дахин сонгуулахаар null болгоно.
  void _toggleCategory(String categoryId, bool selected) {
    setState(() {
      if (selected) {
        _selectedCategoryIds.add(categoryId);
      } else {
        _selectedCategoryIds.remove(categoryId);
      }
      final compatible = _compatibleBranches;
      final stillValid =
          _selectedBranch != null &&
          compatible.any((b) => b.id == _selectedBranch!.id);
      if (!stillValid) {
        _selectedBranch = compatible.length == 1 ? compatible.single : null;
        _selectedDate = null;
      }
      _selectedSlot = null;
      _availability = null;
      _slotsError = null;
      _error = null;
    });
    if (_selectedDate != null) _loadAvailability();
  }

  @override
  void initState() {
    super.initState();
    // Category-first, ямар ч урьдчилан сонгосон салбаргүйгээр эхэлнэ (тухайн
    // байгууллагын профайл хуудас endээс энд зөвхөн нэг л "Цаг захиалах"
    // товч байдаг тул). Ганц салбартай байгууллагад л шууд сонгогдоно —
    // сонголт ямар ч утгагүй тохиолдолд шаардлагагүй алхам нэмэхгүй.
    final preferredMatches = widget.organization.branches
        .where((branch) => branch.id == widget.initialBranchId)
        .toList(growable: false);
    final preferredBranch = preferredMatches.isEmpty
        ? null
        : preferredMatches.first;
    _selectedBranch = preferredBranch ??
        (widget.organization.branches.length == 1
            ? widget.organization.branches.single
            : null);
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month);
    _vehiclesController = context.read<VehiclesController>();
    _vehiclesController.addListener(_maybeAutoSelectSingleVehicle);
    final state = _vehiclesController.state;
    if (state.status == VehiclesStatus.initial) {
      _vehiclesController.load();
    } else if (_shouldAutoSelectVehicle(state)) {
      // Vehicles were already loaded before this screen opened; set directly
      // (setState is illegal before the first build).
      _selectedVehicleId = state.vehicles.single.id;
    }
  }

  @override
  void dispose() {
    _vehiclesController.removeListener(_maybeAutoSelectSingleVehicle);
    _noteController.dispose();
    super.dispose();
  }

  /// Pre-selects the customer's vehicle when they own exactly one, so a
  /// single-car customer doesn't have to open the picker. Mirrors the web
  /// order form's single-vehicle auto-select (carservice.mn `27a9875`). Any
  /// manual change — including choosing "Сонгохгүй" — disables it, so it never
  /// fights the customer.
  bool _shouldAutoSelectVehicle(VehiclesState state) =>
      !_userTouchedVehicle &&
      _selectedVehicleId == null &&
      state.status == VehiclesStatus.data &&
      state.vehicles.length == 1;

  void _maybeAutoSelectSingleVehicle() {
    final state = _vehiclesController.state;
    if (!mounted || !_shouldAutoSelectVehicle(state)) return;
    setState(() => _selectedVehicleId = state.vehicles.single.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: widget.onBack),
      title: const Text('Цаг хүсэх'),
    ),
    body: AppShellBackground(
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _BookingHeader(
              organization: widget.organization,
              selectedBranch: _selectedBranch,
              categoryCount: _allCategories.length,
            ),
            if (_allCategories.isNotEmpty) ...[
              const SizedBox(height: 16),
              GlassSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Үйлчилгээ сонгох',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedCategoryIds.isEmpty
                          ? 'Хэрэгтэй үйлчилгээгээ сонгоно уу (нэг буюу хэд) — доорх '
                                'салбарын сонголт үүнд тохируулан шүүгдэнэ.'
                          : 'Нийт ойролцоогоор $_selectedDurationMinutes мин',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in _allCategories)
                          FilterChip(
                            label: Text(category.name),
                            // Checkmark-гүй — эс бөгөөс сонгоход chip өргөсөж
                            // Wrap-ийн бусад chip-үүд шилжинэ (jank).
                            showCheckmark: false,
                            selected: _selectedCategoryIds.contains(
                              category.id,
                            ),
                            onSelected: (selected) =>
                                _toggleCategory(category.id, selected),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            // Дэвийн шийдвэрээр: ангилал сонгогдоогүй бол салбар сонгох
            // хэсгийг НУУНА (grey/disable биш) — ганц салбартай байгууллагад
            // аль хэдийн автоматаар сонгогдсон байх тул харах шаардлагагүй.
            // Харин байгууллагад ангилал огт байхгүй бол (сонгох зүйл алга)
            // энэ дүрэм хэрэглэгдэхгүй — эс бөгөөс салбар сонгох боломж
            // мөнхөд алга болно (сонгох ганц ч категори байхгүй тул).
            if (widget.organization.branches.length > 1 &&
                (_allCategories.isEmpty ||
                    _selectedCategoryIds.isNotEmpty)) ...[
              const SizedBox(height: 16),
              GlassSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Салбар сонгох',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    if (_compatibleBranches.isEmpty)
                      Text(
                        'Сонгосон бүх үйлчилгээг нэгэн зэрэг санал болгодог '
                        'салбар алга байна. Үйлчилгээнийхээ сонголтоо өөрчилнө үү.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    else
                      // Ганц салбар үлдсэн ч dropdown-г харуулсаар байна —
                      // эс бөгөөс автоматаар сонгогдоод юу ч харагдахгүй болж,
                      // хэрэглэгчид "алга болсон" мэт санагдана (зөвхөн дээрх
                      // толгой хэсэгт нэрийг нь харах боломжтой байсан).
                      DropdownButtonFormField<String>(
                        // Категори сольсноор `_selectedBranch` энэ виджетээс
                        // ГАДУУР (`_toggleCategory`) өөрчлөгдөж болох тул value-г
                        // `key`-д оруулж, дахин зурахад шинэ утгаараа эхэлнэ
                        // (`initialValue` дотоод төлөв тул өөрөө дахин синк хийхгүй).
                        key: ValueKey(
                          'booking-branch-dropdown-${_selectedBranch?.id}',
                        ),
                        initialValue: _selectedBranch?.id,
                        decoration: const InputDecoration(labelText: 'Салбар'),
                        hint: const Text('Салбараа сонгоно уу'),
                        items: [
                          for (final branch in _compatibleBranches)
                            DropdownMenuItem(
                              value: branch.id,
                              child: Text(branch.name),
                            ),
                        ],
                        onChanged: (id) {
                          if (id == null) return;
                          _selectBranch(
                            _compatibleBranches.firstWhere((b) => b.id == id),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
            if (_selectedBranch != null) ...[
              const SizedBox(height: 16),
              GlassSurface(
                child: BookingCalendar(
                  month: _displayedMonth,
                  selectedDate: _selectedDate,
                  branch: _selectedBranch,
                  onMonthChanged: (month) =>
                      setState(() => _displayedMonth = month),
                  onDateSelected: (date) {
                    setState(() {
                      _selectedDate = date;
                      _selectedSlot = null;
                      _error = null;
                    });
                    _loadAvailability();
                  },
                ),
              ),
            ],
            if (_selectedBranch != null && _selectedDate != null) ...[
              const SizedBox(height: 12),
              GlassSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Цаг сонгох',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _availability != null
                          ? 'Нэг захиалга ≈ ${_availability!.durationMinutes} мин'
                          : (_selectedBranch?.hoursLabel ?? ''),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingSlots)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (_slotsError != null)
                      Text(
                        _slotsError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    else if (_availability != null && !_availability!.open)
                      Text(
                        _availability!.reason ?? 'Энэ өдөр хаалттай.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      TimeSlotGrid(
                        slots: _availability?.slots ?? const [],
                        selected: _selectedSlot,
                        onSelected: (slot) => setState(() {
                          _selectedSlot = slot;
                          _error = null;
                        }),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _VehiclePicker(
              controller: _vehiclesController,
              selectedVehicleId: _selectedVehicleId,
              onChanged: (id) => setState(() {
                _userTouchedVehicle = true;
                _selectedVehicleId = id;
              }),
              onAddVehicle: widget.onAddVehicle,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Тэмдэглэл (заавал биш)',
                alignLabelWithHint: true,
              ),
            ),
            Text(
              'Энэ нь хүсэлт илгээх үйлдэл. Сервис баталгаажуулсны дараа цаг баталгаажна.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('submit-booking'),
              onPressed: _submitting ? null : _submit,
              icon: const Icon(Icons.send_outlined),
              label: Text(_submitting ? 'Илгээж байна…' : 'Хүсэлт илгээх'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    final branch = _selectedBranch;
    if (branch == null) {
      setState(
        () => _error = 'Эхлээд үйлчилгээ, дараа нь салбараа сонгоно уу.',
      );
      return;
    }
    final requestedAt = _requestedAt;
    if (requestedAt == null || !requestedAt.isAfter(DateTime.now())) {
      setState(() => _error = 'Ирээдүйн өдөр, цаг сонгоно уу.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.repository.createAppointment(
        branchId: branch.id,
        requestedAt: requestedAt,
        note: _noteController.text,
        accountVehicleId: _selectedVehicleId,
        categoryIds: _selectedCategoryIds.toList(),
      );
      if (mounted) widget.onCompleted(result);
    } on UnauthenticatedFailure {
      if (mounted) widget.onUnauthenticated();
    } on ConflictFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _VehiclePicker extends StatelessWidget {
  const _VehiclePicker({
    required this.controller,
    required this.selectedVehicleId,
    required this.onChanged,
    required this.onAddVehicle,
  });

  final VehiclesController controller;
  final String? selectedVehicleId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onAddVehicle;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (state.status == VehiclesStatus.error || state.vehicles.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const ValueKey('booking-add-vehicle'),
          onPressed: onAddVehicle,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Машин нэмэх (заавал биш)'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          key: const ValueKey('booking-vehicle'),
          initialValue: selectedVehicleId,
          decoration: const InputDecoration(
            labelText: 'Тээврийн хэрэгсэл (заавал биш)',
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Сонгохгүй'),
            ),
            for (final vehicle in state.vehicles)
              DropdownMenuItem<String?>(
                value: vehicle.id,
                child: Text(
                  '${vehicle.plate} · ${vehicle.make} ${vehicle.model}',
                ),
              ),
          ],
          onChanged: onChanged,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('booking-add-vehicle'),
            onPressed: onAddVehicle,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Шинэ машин нэмэх'),
          ),
        ),
      ],
    );
  }
}

/// Захиалгын хуудасны толгой хэсэг — байгууллагын лого/утас, ба сонгосон
/// салбарын (эсвэл түүнийг сонгоогүй бол байгууллагын товч тоо баримтын)
/// мэдээллийг харуулна. Зөвхөн танилцуулах — сонголт/захиалгын үйлдэлгүй.
class _BookingHeader extends StatelessWidget {
  const _BookingHeader({
    required this.organization,
    required this.selectedBranch,
    required this.categoryCount,
  });

  final OrganizationDetail organization;
  final BranchDetail? selectedBranch;
  final int categoryCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final branch = selectedBranch;
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary.withValues(alpha: 0.34),
                      AppColors.blue.withValues(alpha: 0.22),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  border: Border.all(
                    color: CarCareTheme.of(context).glassBorder,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _BookingHeaderLogo(
                  name: organization.name,
                  logoUrl: organization.logoUrl,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organization.name,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (organization.phone != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 15,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              organization.phone!,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            key: const ValueKey('booking-copy-phone'),
                            borderRadius: BorderRadius.circular(99),
                            onTap: () async {
                              await Clipboard.setData(
                                ClipboardData(text: organization.phone!),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Утасны дугаар хууллаа'),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.copy_outlined,
                                size: 15,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (branch == null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(
                  icon: Icons.storefront_outlined,
                  label: '${organization.branches.length} салбар',
                ),
                if (categoryCount > 0)
                  _InfoPill(
                    icon: Icons.design_services_outlined,
                    label: '$categoryCount үйлчилгээ',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Эхлээд үйлчилгээгээ сонгоно уу',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ] else ...[
            Row(
              children: [
                _OpenBadge(status: branch.openStatusAt(DateTime.now())),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    branch.hoursLabel,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              branch.name,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (branch.fullAddress.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                branch.fullAddress,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _BookingHeaderLogo extends StatelessWidget {
  const _BookingHeaderLogo({required this.name, required this.logoUrl});

  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    // Center the letter itself: as a CachedNetworkImage placeholder/errorWidget
    // it fills the image box, which does not center its child by default.
    final letter = Center(
      child: Text(
        name.characters.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
    final url = logoUrl?.trim();
    if (url == null || url.isEmpty) return letter;
    return CachedNetworkImage(
      imageUrl: url,
      width: 56,
      height: 56,
      fit: BoxFit.cover,
      placeholder: (_, _) => letter,
      errorWidget: (_, _, _) => letter,
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  const _OpenBadge({required this.status});

  final BranchOpenStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      BranchOpenStatus.open => AppColors.green,
      BranchOpenStatus.closed => Theme.of(context).colorScheme.error,
      BranchOpenStatus.unknown => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            switch (status) {
              BranchOpenStatus.open => 'Нээлттэй',
              BranchOpenStatus.closed => 'Хаалттай',
              BranchOpenStatus.unknown => 'Төлөв тодорхойгүй',
            },
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
