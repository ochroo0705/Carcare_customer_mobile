import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/booking/domain/bookable_service.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_repository.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/service_selection_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:flutter/material.dart';

class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({
    required this.organization,
    required this.branch,
    required this.repository,
    required this.onBack,
    super.key,
  });

  final Organization organization;
  final Branch branch;
  final ServiceRepository repository;
  final VoidCallback onBack;

  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  late final ServiceSelectionController controller;

  @override
  void initState() {
    super.initState();
    controller = ServiceSelectionController(widget.repository, widget.branch.id)
      ..addListener(_onChanged)
      ..load();
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: widget.onBack),
      title: const Text('Үйлчилгээ сонгох'),
    ),
    body: AppShellBackground(child: SafeArea(top: false, child: _body())),
    bottomNavigationBar: controller.selectedServices.isEmpty
        ? null
        : _SelectionSummary(
            count: controller.selectedServices.length,
            totalPrice: controller.totalPrice,
            totalDurationMinutes: controller.totalDurationMinutes,
            onContinue: _showNextStep,
          ),
  );

  Widget _body() {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.errorMessage != null) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        title: 'Үйлчилгээ ачаалсангүй',
        message: controller.errorMessage!,
        actionLabel: 'Дахин оролдох',
        onAction: controller.load,
      );
    }
    if (controller.services.isEmpty) {
      return _MessageState(
        icon: Icons.build_circle_outlined,
        title: 'Үйлчилгээ бүртгэгдээгүй байна',
        message: 'Энэ салбарт онлайнаар сонгох үйлчилгээ одоогоор алга.',
        actionLabel: 'Буцах',
        onAction: widget.onBack,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: [
        _BookingContext(organization: widget.organization, branch: widget.branch),
        const SizedBox(height: 22),
        Text(
          'Ямар үйлчилгээ хэрэгтэй вэ?',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Нэг эсвэл хэд хэдэн үйлчилгээ сонгож болно. Үнэ, хугацаа нь урьдчилсан тооцоо.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _CategoryChip(
                label: 'Бүгд',
                selected: controller.selectedCategoryId == null,
                onSelected: () => controller.selectCategory(null),
              ),
              for (final category in controller.categories) ...[
                const SizedBox(width: 8),
                _CategoryChip(
                  label: category.name,
                  selected: controller.selectedCategoryId == category.id,
                  onSelected: () => controller.selectCategory(category.id),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final service in controller.visibleServices) ...[
          _ServiceCard(
            service: service,
            selected: controller.isSelected(service.id),
            onTap: () => controller.toggleService(service.id),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Future<void> _showNextStep() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Үйлчилгээ сонгогдлоо',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${controller.selectedServices.length} үйлчилгээ · ${_durationLabel(controller.totalDurationMinutes)} · ${_money(controller.totalPrice)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Дараагийн шатанд боломжит өдөр, цаг сонгоно. Энэ хэсгийг дараагийн implementation-аар холбоно.',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: null,
              child: const Text('Өдөр, цаг сонгох — дараагийн шат'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BookingContext extends StatelessWidget {
  const _BookingContext({required this.organization, required this.branch});

  final Organization organization;
  final Branch branch;

  @override
  Widget build(BuildContext context) => GlassSurface(
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Icon(
            Icons.storefront_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                organization.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                branch.name,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.check_circle_rounded, color: AppColors.green),
      ],
    ),
  );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    selected: selected,
    onSelected: (_) => onSelected(),
    label: Text(label),
  );
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.selected,
    required this.onTap,
  });

  final BookableService service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassSurface(
      key: ValueKey('service-${service.id}'),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: selected ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: selected ? scheme.primary : CarCareTheme.of(context).glassBorder,
                width: 1.5,
              ),
            ),
            child: selected
                ? Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  service.description,
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  children: [
                    _Meta(icon: Icons.schedule_outlined, label: _durationLabel(service.durationMinutes)),
                    _Meta(icon: Icons.payments_outlined, label: _money(service.price)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.labelMedium),
    ],
  );
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({
    required this.count,
    required this.totalPrice,
    required this.totalDurationMinutes,
    required this.onContinue,
  });

  final int count;
  final int totalPrice;
  final int totalDurationMinutes;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: CarCareTheme.of(context).glassBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count үйлчилгээ · ${_durationLabel(totalDurationMinutes)}'),
                Text(
                  _money(totalPrice),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            key: const ValueKey('continue-to-time'),
            onPressed: onContinue,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Үргэлжлүүлэх'),
          ),
        ],
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}

String _money(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '${buffer.toString()} ₮';
}

String _durationLabel(int minutes) {
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  if (hours == 0) return '$remaining мин';
  if (remaining == 0) return '$hours цаг';
  return '$hours цаг $remaining мин';
}
