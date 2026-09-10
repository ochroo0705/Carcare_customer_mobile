import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/history/presentation/format_amount.dart';
import 'package:carcare_customer_mobile/features/history/presentation/widgets/service_order_status_chip.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';
import 'package:flutter/material.dart';

class VehicleDetailScreen extends StatelessWidget {
  const VehicleDetailScreen({
    required this.vehicle,
    required this.onBack,
    this.appointments = const [],
    this.appointmentsLoading = false,
    this.onAppointmentSelected,
    this.orders = const [],
    this.ordersLoading = false,
    this.onOrderSelected,
    super.key,
  });

  final Vehicle vehicle;
  final VoidCallback onBack;
  final List<Appointment> appointments;
  final bool appointmentsLoading;
  final ValueChanged<String>? onAppointmentSelected;
  final List<ServiceOrder> orders;
  final bool ordersLoading;
  final ValueChanged<String>? onOrderSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final facts = <({String label, String value})>[
      (label: 'Үйлдвэрлэсэн он', value: _value(vehicle.year?.toString())),
      (label: 'VIN', value: _value(vehicle.vin)),
      (label: 'Өнгө', value: _value(vehicle.colorName)),
      (label: 'Моторын багтаамж', value: _capacity(vehicle.capacity)),
      (label: 'Шатахуун', value: _value(vehicle.fuelType)),
      (label: 'Жолооны хүрд', value: _value(vehicle.wheelPosition)),
      (label: 'Зориулалт', value: _value(vehicle.purpose)),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: const Text('Машины дэлгэрэнгүй'),
      ),
      body: AppShellBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              GlassSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.directions_car_outlined,
                            color: scheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehicle.plate,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${vehicle.make} ${vehicle.model}',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'ХУР-ийн техникийн мэдээлэл',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${vehicle.serviceCount} үйлчилгээ · ${vehicle.diagnosisCount} оношилгоо',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    for (final fact in facts) ...[
                      const Divider(height: 1),
                      _FactRow(label: fact.label, value: fact.value),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _AppointmentsSection(
                appointments: appointments,
                isLoading: appointmentsLoading,
                onAppointmentSelected: onAppointmentSelected,
              ),
              const SizedBox(height: 12),
              _ServiceOrdersSection(
                orders: orders,
                isLoading: ordersLoading,
                onOrderSelected: onOrderSelected,
              ),
              const SizedBox(height: 12),
              Text(
                'Энд харагдах мэдээлэл нь бүртгэлд хадгалагдсан HUR-ийн утгууд дээр үндэслэнэ.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _value(String? value) =>
      value == null || value.trim().isEmpty ? '—' : value;

  static String _capacity(int? value) => value == null ? '—' : '$value см³';
}

class _ServiceOrdersSection extends StatelessWidget {
  const _ServiceOrdersSection({
    required this.orders,
    required this.isLoading,
    required this.onOrderSelected,
  });

  final List<ServiceOrder> orders;
  final bool isLoading;
  final ValueChanged<String>? onOrderSelected;

  @override
  Widget build(BuildContext context) {
    final sorted = [...orders]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Үйлчилгээний түүх',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${sorted.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (isLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ] else if (sorted.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Энэ машинтай холбоотой үйлчилгээний түүх байхгүй байна.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            for (var i = 0; i < sorted.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              InkWell(
                onTap: onOrderSelected == null
                    ? null
                    : () => onOrderSelected!(sorted[i].id),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sorted[i].tenantName,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_formatDate(sorted[i].completedAt)} · ${sorted[i].branchName}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${formatAmount(sorted[i].totalAmount)}₮',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ServiceOrderStatusChip(status: sorted[i].status),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AppointmentsSection extends StatelessWidget {
  const _AppointmentsSection({
    required this.appointments,
    required this.isLoading,
    required this.onAppointmentSelected,
  });

  final List<Appointment> appointments;
  final bool isLoading;
  final ValueChanged<String>? onAppointmentSelected;

  @override
  Widget build(BuildContext context) {
    final sorted = [...appointments]
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Цагийн захиалгын түүх',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${sorted.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (isLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ] else if (sorted.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Энэ машинтай холбоотой цагийн захиалга байхгүй байна.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            for (var i = 0; i < sorted.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              InkWell(
                onTap: onAppointmentSelected == null
                    ? null
                    : () => onAppointmentSelected!(sorted[i].id),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sorted[i].tenantName,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_formatDateTime(sorted[i].requestedAt)} · ${sorted[i].branchName}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (sorted[i].categoryName != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                sorted[i].categoryName!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        sorted[i].status.localizedLabel,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) =>
    '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _formatDate(DateTime value) =>
    '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
