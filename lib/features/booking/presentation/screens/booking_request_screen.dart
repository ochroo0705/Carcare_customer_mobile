import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:flutter/material.dart';

class BookingRequestScreen extends StatefulWidget {
  const BookingRequestScreen({
    required this.organization,
    required this.branch,
    required this.repository,
    required this.onBack,
    required this.onCompleted,
    required this.onUnauthenticated,
    super.key,
  });

  final OrganizationDetail organization;
  final BranchDetail branch;
  final AppointmentRepository repository;
  final VoidCallback onBack;
  final ValueChanged<CreatedAppointment> onCompleted;
  final VoidCallback onUnauthenticated;

  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends State<BookingRequestScreen> {
  final _noteController = TextEditingController();
  DateTime? _requestedAt;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
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
            OutlinedButton.icon(
              key: const ValueKey('booking-date-time'),
              onPressed: _pickDateTime,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _requestedAt == null
                    ? 'Өдөр, цаг сонгох'
                    : _formatDateTime(_requestedAt!),
              ),
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

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 180)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return;
    setState(() {
      _requestedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _error = null;
    });
  }

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

String _formatDateTime(DateTime value) =>
    '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
