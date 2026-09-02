import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/widgets/booking_calendar.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/widgets/time_slot_grid.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BookingRequestScreen extends StatefulWidget {
  const BookingRequestScreen({
    required this.organization,
    required this.branch,
    required this.repository,
    required this.onAddVehicle,
    required this.onBack,
    required this.onCompleted,
    required this.onUnauthenticated,
    super.key,
  });

  final OrganizationDetail organization;
  final BranchDetail branch;
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
  DateTime? _selectedDate;
  ({int hour, int minute})? _selectedSlot;
  String? _selectedVehicleId;
  bool _userTouchedVehicle = false;
  bool _submitting = false;
  String? _error;

  List<({int hour, int minute})> get _slots => widget.branch.slotsForDay();

  DateTime? get _requestedAt {
    final date = _selectedDate;
    final slot = _selectedSlot;
    if (date == null || slot == null) return null;
    return DateTime(date.year, date.month, date.day, slot.hour, slot.minute);
  }

  @override
  void initState() {
    super.initState();
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
            GlassSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.organization.name,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(widget.branch.name),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassSurface(
              child: BookingCalendar(
                month: _displayedMonth,
                selectedDate: _selectedDate,
                onMonthChanged: (month) =>
                    setState(() => _displayedMonth = month),
                onDateSelected: (date) => setState(() {
                  _selectedDate = date;
                  _selectedSlot = null;
                  _error = null;
                }),
              ),
            ),
            if (_selectedDate != null) ...[
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
                      widget.branch.hoursLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TimeSlotGrid(
                      slots: _slots,
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
        branchId: widget.branch.id,
        requestedAt: requestedAt,
        note: _noteController.text,
        accountVehicleId: _selectedVehicleId,
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
