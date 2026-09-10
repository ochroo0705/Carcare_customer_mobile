import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/availability.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/widgets/booking_calendar.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/widgets/time_slot_grid.dart';
import 'package:flutter/material.dart';

/// Баталгаажсан (эсвэл хараахан хариу аваагүй), захиалгагүй цагийг өөр
/// хугацаанд шилжүүлэх дэлгэц. `booking_request_screen.dart`-ийн огноо+цагийн
/// сонголтын orchestration-той адил зарчим, гэхдээ салбар аль хэдийн тогтсон
/// (энэ Appointment-ийнх) тул зөвхөн огноо/цаг сонгоно — ангилал/машин/
/// тэмдэглэл байхгүй (веб талын `rescheduleAppointmentByAccount`-тай ижил
/// хамрах хүрээ).
class RescheduleAppointmentScreen extends StatefulWidget {
  const RescheduleAppointmentScreen({
    required this.appointment,
    required this.repository,
    required this.onBack,
    required this.onRescheduled,
    super.key,
  });

  final Appointment appointment;
  final AppointmentRepository repository;
  final VoidCallback onBack;

  /// Returns an error message on failure, or `null` on success (mirrors
  /// `AppointmentsController.reschedule`).
  final Future<String?> Function(DateTime requestedAt) onRescheduled;

  @override
  State<RescheduleAppointmentScreen> createState() =>
      _RescheduleAppointmentScreenState();
}

class _RescheduleAppointmentScreenState
    extends State<RescheduleAppointmentScreen> {
  late DateTime _displayedMonth;
  DateTime? _selectedDate;
  ({int hour, int minute})? _selectedSlot;
  DayAvailability? _availability;
  bool _loadingSlots = false;
  String? _slotsError;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month);
  }

  Future<void> _loadAvailability() async {
    final date = _selectedDate;
    final branchId = widget.appointment.branchId;
    if (date == null || branchId == null) return;
    setState(() {
      _loadingSlots = true;
      _slotsError = null;
      _availability = null;
      _selectedSlot = null;
    });
    try {
      final availability = await widget.repository.getAvailability(
        branchId: branchId,
        date: date,
        categoryIds: const [],
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

  Future<void> _submit() async {
    final requestedAt = _requestedAt;
    if (requestedAt == null || _submitting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Цагаа шилжүүлэх үү?'),
        content: const Text(
          'Сонгосон шинэ огноо, цаг руу энэ захиалгыг шилжүүлэх үү?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Шилжүүлэх'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await widget.onRescheduled(requestedAt);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _submitting = false;
        _error = error;
      });
      return;
    }
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    final branchId = widget.appointment.branchId;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: const Text('Цаг шилжүүлэх'),
      ),
      body: AppShellBackground(
        child: SafeArea(
          top: false,
          child: branchId == null
              ? _NoBranchInfo(onBack: widget.onBack)
              : _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.appointment.tenantName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.appointment.branchName,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Шинэ огноо',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        BookingCalendar(
          month: _displayedMonth,
          selectedDate: _selectedDate,
          onDateSelected: (date) {
            setState(() => _selectedDate = date);
            _loadAvailability();
          },
          onMonthChanged: (month) => setState(() => _displayedMonth = month),
        ),
        if (_selectedDate != null) ...[
          const SizedBox(height: 16),
          Text(
            'Боломжит цаг',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (_loadingSlots)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_slotsError != null)
            Text(
              _slotsError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (_availability != null)
            TimeSlotGrid(
              slots: _availability!.slots,
              selected: _selectedSlot,
              onSelected: (slot) => setState(() => _selectedSlot = slot),
            ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _requestedAt == null || _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Шилжүүлэх'),
        ),
      ],
    );
  }
}

class _NoBranchInfo extends StatelessWidget {
  const _NoBranchInfo({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Энэ захиалгын салбарын мэдээлэл дутуу байна. Дахин ачаалж үзнэ үү.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onBack, child: const Text('Буцах')),
        ],
      ),
    ),
  );
}
