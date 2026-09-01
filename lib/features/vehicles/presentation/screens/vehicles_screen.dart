import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_state.dart';
import 'package:flutter/material.dart';

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({
    required this.controller,
    required this.isAuthenticated,
    required this.onLoginRequested,
    required this.onAddVehicle,
    super.key,
  });

  final VehiclesController controller;
  final bool isAuthenticated;
  final VoidCallback onLoginRequested;
  final VoidCallback onAddVehicle;

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: !isAuthenticated
        ? null
        : FloatingActionButton.extended(
            key: const ValueKey('vehicles-add-fab'),
            onPressed: onAddVehicle,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Машин нэмэх'),
          ),
    body: AppShellBackground(
      child: SafeArea(
        child: isAuthenticated
            ? _VehiclesBody(controller: controller)
            : _UnauthenticatedPrompt(onLoginRequested: onLoginRequested),
      ),
    ),
  );
}

class _UnauthenticatedPrompt extends StatelessWidget {
  const _UnauthenticatedPrompt({required this.onLoginRequested});

  final VoidCallback onLoginRequested;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 58,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 18),
          Text(
            'Машинаа харахын тулд нэвтэрнэ үү',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Таны бүртгэсэн машинууд энд харагдана.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('vehicles-login'),
            onPressed: onLoginRequested,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Нэвтрэх'),
          ),
        ],
      ),
    ),
  );
}

class _VehiclesBody extends StatelessWidget {
  const _VehiclesBody({required this.controller});

  final VehiclesController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return switch (state.status) {
      VehiclesStatus.initial || VehiclesStatus.loading => Semantics(
        container: true,
        liveRegion: true,
        label: 'Машинуудыг ачаалж байна',
        child: Center(child: CircularProgressIndicator()),
      ),
      VehiclesStatus.error => _ErrorView(
        message: state.message ?? 'Тодорхойгүй алдаа гарлаа.',
        onRetry: controller.load,
      ),
      VehiclesStatus.empty => const _EmptyVehicles(),
      VehiclesStatus.data => _VehiclesList(controller: controller),
    };
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: message,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              key: const ValueKey('vehicles-retry'),
              onPressed: onRetry,
              child: const Text('Дахин оролдох'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyVehicles extends StatelessWidget {
  const _EmptyVehicles();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 58,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 18),
          Text(
            'Бүртгэсэн машин алга',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Доорх товчоор шинэ машинаа бүртгүүлээрэй.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _VehiclesList extends StatelessWidget {
  const _VehiclesList({required this.controller});

  final VehiclesController controller;

  @override
  Widget build(BuildContext context) {
    final vehicles = controller.state.vehicles;
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        key: const PageStorageKey('vehicles-list'),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
        itemCount: vehicles.length + 1,
        separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 18 : 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _VehiclesHeader();
          }
          final vehicle = vehicles[index - 1];
          return _VehicleCard(
            vehicle: vehicle,
            isDeleting: controller.isDeleting(vehicle.id),
            onDelete: () => _confirmDelete(context, vehicle),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Машин устгах уу?'),
        content: Text('${vehicle.make} ${vehicle.model} — ${vehicle.plate}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Үгүй'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Тийм, устгах'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await controller.delete(vehicle.id);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

class _VehiclesHeader extends StatelessWidget {
  const _VehiclesHeader();

  @override
  Widget build(BuildContext context) => Text(
    'Миний машинууд',
    style: Theme.of(context).textTheme.headlineSmall
        ?.copyWith(fontWeight: FontWeight.w900),
  );
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.isDeleting,
    required this.onDelete,
  });

  final Vehicle vehicle;
  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => GlassSurface(
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary
                .withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.directions_car_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${vehicle.make} ${vehicle.model}',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                vehicle.year == null
                    ? vehicle.plate
                    : '${vehicle.plate} · ${vehicle.year}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: ValueKey('delete-vehicle-${vehicle.id}'),
          onPressed: isDeleting ? null : onDelete,
          tooltip: 'Устгах',
          icon: isDeleting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
        ),
      ],
    ),
  );
}
