import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/core/widgets/skeletons.dart';
import 'package:carcare_customer_mobile/features/booking/domain/walk_in_order.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_state.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/widgets/service_progress_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Захиалгагүй (walk-in, appointment-гүй) захиалгын дэлгэрэнгүй.
/// `AppointmentDetailScreen`-тэй адил зарчим — `AppointmentsController`-ийн
/// аль хэдийн ачаалсан жагсаалтаас id-аар олно, тусад нь дахин татахгүй
/// (list payload дотор бүх дэлгэрэнгүй — үнэ, ажлын жагсаалт — аль хэдийн
/// иржээ). Цуцлах/төлбөр/шилжүүлэх гэсэн ойлголт байхгүй тул
/// `AppointmentDetailScreen`-ээс хамаагүй хялбар.
class WalkInOrderDetailScreen extends StatelessWidget {
  const WalkInOrderDetailScreen({
    required this.orderId,
    required this.onBack,
    super.key,
  });

  final String orderId;
  final VoidCallback onBack;

  WalkInOrder? _find(AppointmentsController controller) {
    for (final order in controller.state.walkInOrders) {
      if (order.progress.id == orderId) return order;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppointmentsController>();
    final order = _find(controller);
    final isLoading =
        controller.state.status == AppointmentsStatus.loading ||
        controller.state.status == AppointmentsStatus.initial;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: const Text('Захиалгын дэлгэрэнгүй'),
      ),
      body: AppShellBackground(
        child: SafeArea(
          top: false,
          child: switch ((order, isLoading)) {
            (final WalkInOrder order, _) => _WalkInOrderDetailBody(
              order: order,
              onRefresh: controller.load,
            ),
            (null, true) => const SkeletonDetail(),
            (null, false) => _NotFound(onBack: onBack),
          },
        ),
      ),
    );
  }
}

class _WalkInOrderDetailBody extends StatelessWidget {
  const _WalkInOrderDetailBody({required this.order, required this.onRefresh});

  final WalkInOrder order;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          GlassSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.tenantName,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  order.branchName,
                  style: textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ServiceProgressSection(progress: order.progress),
        ],
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 52,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Захиалга олдсонгүй',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onBack, child: const Text('Буцах')),
        ],
      ),
    ),
  );
}
