import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_state.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/services/location_permission_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-page view of a single appointment. Reads the appointment reactively
/// from [AppointmentsController] by id rather than taking it as a constructor
/// argument, so the same screen serves a list tap, the post-booking landing,
/// and (later) a push-notification deep link — each of which only knows the id.
/// When the id isn't in the loaded list yet (e.g. right after booking, before
/// the refetch lands), it shows a loading state and resolves once `load()`
/// completes.
class AppointmentDetailScreen extends StatelessWidget {
  const AppointmentDetailScreen({
    required this.appointmentId,
    required this.organizationRepository,
    required this.onBack,
    required this.onPay,
    super.key,
  });

  final String appointmentId;

  /// Used to fetch the branch's location/hours/contact — none of which the
  /// appointment payload carries (it has only the branch *name*).
  final OrganizationRepository organizationRepository;
  final VoidCallback onBack;

  /// Opens the fee-payment screen for [appointment]. Wired by the router, the
  /// same way the appointments list does it.
  final ValueChanged<Appointment> onPay;

  Appointment? _find(AppointmentsController controller) {
    for (final appointment in controller.state.appointments) {
      if (appointment.id == appointmentId) return appointment;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppointmentsController>();
    final appointment = _find(controller);
    final isLoading =
        controller.state.status == AppointmentsStatus.loading ||
        controller.state.status == AppointmentsStatus.initial;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: const Text('Цагийн дэлгэрэнгүй'),
      ),
      body: AppShellBackground(
        child: SafeArea(
          top: false,
          child: switch ((appointment, isLoading)) {
            (final Appointment appointment, _) => _AppointmentDetailBody(
              appointment: appointment,
              organizationRepository: organizationRepository,
              isCancelling: controller.isCancelling(appointment.id),
              onCancel: appointment.status.canCancel
                  ? () => _confirmCancel(context, controller, appointment)
                  : null,
              onPay: appointment.canPayFee
                  ? () => onPay(appointment)
                  : null,
            ),
            (null, true) => const Center(child: CircularProgressIndicator()),
            (null, false) => _NotFound(onBack: onBack),
          },
        ),
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    AppointmentsController controller,
    Appointment appointment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Захиалга цуцлах уу?'),
        content: Text('${appointment.tenantName} — ${appointment.branchName}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Үгүй'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Тийм, цуцлах'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await controller.cancel(appointment.id);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

class _AppointmentDetailBody extends StatelessWidget {
  const _AppointmentDetailBody({
    required this.appointment,
    required this.organizationRepository,
    required this.isCancelling,
    this.onCancel,
    this.onPay,
  });

  final Appointment appointment;
  final OrganizationRepository organizationRepository;
  final bool isCancelling;
  final VoidCallback? onCancel;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      appointment.tenantName,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(status: appointment.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                appointment.branchName,
                style: textTheme.bodyMedium?.copyWith(color: muted),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.event_outlined,
                label: 'Цаг',
                value: _formatDateTime(appointment.requestedAt),
              ),
              if (appointment.categoryName != null)
                _DetailRow(
                  icon: Icons.construction_outlined,
                  label: 'Ангилал',
                  value: appointment.categoryName!,
                ),
              if (appointment.vehiclePlate != null)
                _DetailRow(
                  icon: Icons.directions_car_outlined,
                  label: 'Тээврийн хэрэгсэл',
                  value: appointment.vehiclePlate!,
                ),
              if (appointment.note != null &&
                  appointment.note!.trim().isNotEmpty)
                _DetailRow(
                  icon: Icons.sticky_note_2_outlined,
                  label: 'Тэмдэглэл',
                  value: appointment.note!,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _BranchInfoCard(
          tenantSlug: appointment.tenantSlug,
          branchName: appointment.branchName,
          repository: organizationRepository,
        ),
        if (onPay != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.red.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    appointment.payment!.status == AppointmentFeeStatus.failed
                        ? 'Хураамжийн QR үүсгэхэд алдаа гарсан'
                        : 'Цаг захиалгын хураамж төлөгдөөгүй',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.red,
                    ),
                  ),
                ),
                FilledButton(
                  key: ValueKey('detail-pay-${appointment.id}'),
                  onPressed: onPay,
                  child: const Text('Төлөх'),
                ),
              ],
            ),
          ),
        ],
        // Хураамж төлөгдсөн бол баталгаажуулах badge — цаг захиалгын status
        // (Хүлээгдэж буй) нь салангид: төлбөр төлөгдсөн ч ажилтан баталгаажуулах
        // хүртэл PENDING хэвээр. Хоёрыг андуурахгүйн тулд төлбөрийг тусад нь
        // тэмдэглэнэ.
        if (appointment.payment?.status == AppointmentFeeStatus.paid) ...[
          const SizedBox(height: 14),
          _FeePaidBadge(key: ValueKey('detail-fee-paid-${appointment.id}')),
        ],
        if (onCancel != null) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: ValueKey('detail-cancel-${appointment.id}'),
            onPressed: isCancelling ? null : onCancel,
            icon: isCancelling
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.close_rounded),
            label: const Text('Захиалга цуцлах'),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
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

/// Location, work hours and contact for the appointment's branch. None of this
/// is in the appointment payload (which carries only the branch *name*), so it
/// fetches the organization detail by slug and matches the branch by name.
/// Degrades gracefully: a spinner while loading, an offline note when the fetch
/// fails for lack of network, and a muted "not found" if the branch can't be
/// matched.
class _BranchInfoCard extends StatefulWidget {
  const _BranchInfoCard({
    required this.tenantSlug,
    required this.branchName,
    required this.repository,
  });

  final String tenantSlug;
  final String branchName;
  final OrganizationRepository repository;

  @override
  State<_BranchInfoCard> createState() => _BranchInfoCardState();
}

class _BranchInfoCardState extends State<_BranchInfoCard> {
  bool _loading = true;
  bool _offline = false;
  BranchDetail? _branch;
  String? _phone;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offline = false;
    });
    try {
      final org = await widget.repository.getOrganization(widget.tenantSlug);
      if (!mounted) return;
      BranchDetail? match;
      for (final branch in org.branches) {
        if (branch.name.trim() == widget.branchName.trim()) {
          match = branch;
          break;
        }
      }
      setState(() {
        _branch = match;
        _phone = org.phone;
        _loading = false;
      });
    } on NetworkFailure {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = true;
      });
    } on AppFailure {
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openMaps(BranchDetail branch) async {
    final destination = '${branch.latitude},${branch.longitude}';
    // With location permission, open directions (Google Maps routes from the
    // user's position and highlights the path). Without it, just drop a pin on
    // the place — we don't force a permission prompt from a maps tap.
    LocationAccessState access;
    try {
      access = await const PermissionHandlerLocationPermissionService().check();
    } catch (_) {
      access = LocationAccessState.denied;
    }
    final directions = access == LocationAccessState.granted;
    // Prefer each platform's native map app: Apple Maps on iOS, Google Maps on
    // Android. Both are https universal links, so if the native app is absent
    // they still open in the browser (see the no-Maps-app case).
    final Uri uri;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      uri = directions
          ? Uri.parse('https://maps.apple.com/?daddr=$destination&dirflg=d')
          : Uri.parse('https://maps.apple.com/?q=$destination');
    } else {
      uri = directions
          ? Uri.parse(
              'https://www.google.com/maps/dir/?api=1&destination=$destination',
            )
          : Uri.parse(
              'https://www.google.com/maps/search/?api=1&query=$destination',
            );
    }
    // Edge case: no app can handle the URL (Maps unavailable) — launchUrl
    // returns false or throws depending on platform.
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('launch returned false');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Газрын зураг нээх боломжгүй байна')),
      );
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Дуудлага хийж чадсангүй')),
      );
    }
  }

  Future<void> _copy(String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Утасны дугаар хууллаа')));
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Байршил ба цагийн хуваарь',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (_loading)
            Row(
              children: [
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text('Ачаалж байна…', style: TextStyle(color: muted)),
              ],
            )
          else if (_offline)
            _Note(
              icon: Icons.wifi_off_rounded,
              text: 'Сүлжээгүй үед байршил, цагийн мэдээлэл харагдахгүй.',
            )
          else if (_branch == null)
            _Note(
              icon: Icons.info_outline_rounded,
              text: 'Салбарын дэлгэрэнгүй мэдээлэл олдсонгүй.',
            )
          else
            ..._content(context, _branch!, muted),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, BranchDetail branch, Color muted) {
    final hasCoords = branch.latitude != null && branch.longitude != null;
    return [
      if (branch.fullAddress.trim().isNotEmpty)
        _DetailRow(
          icon: Icons.place_outlined,
          label: 'Хаяг',
          value: branch.fullAddress,
        ),
      Row(
        children: [
          Icon(Icons.schedule_rounded, size: 18, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              branch.hoursLabel,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          _OpenBadge(status: branch.openStatusAt(DateTime.now())),
        ],
      ),
      const SizedBox(height: 14),
      if (hasCoords)
        OutlinedButton.icon(
          key: const ValueKey('detail-show-on-maps'),
          onPressed: () => _openMaps(branch),
          icon: const Icon(Icons.map_outlined),
          label: const Text('Газрын зураг дээр харах'),
        ),
      if (_phone != null) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                key: const ValueKey('detail-call'),
                onPressed: () => _call(_phone!),
                icon: const Icon(Icons.phone_outlined),
                label: const Text('Залгах'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              key: const ValueKey('detail-copy-phone'),
              onPressed: () => _copy(_phone!),
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Дугаар хуулах',
            ),
          ],
        ),
      ],
    ];
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: muted))),
      ],
    );
  }
}

class _OpenBadge extends StatelessWidget {
  const _OpenBadge({required this.status});

  final BranchOpenStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BranchOpenStatus.open => ('Нээлттэй', AppColors.green),
      BranchOpenStatus.closed => ('Хаалттай', AppColors.red),
      BranchOpenStatus.unknown => (
        'Тодорхойгүй',
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AppointmentStatus.confirmed => AppColors.green,
      AppointmentStatus.pending => AppColors.blue,
      AppointmentStatus.rejected ||
      AppointmentStatus.cancelled => AppColors.red,
      AppointmentStatus.noShow || AppointmentStatus.unknown => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.localizedLabel,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Хураамж төлөгдсөнийг харуулах ногоон badge (цаг захиалгын status-аас
/// тусдаа — доор жагсаалтын дэлгэц дээр ижил дүр зурагтай).
class _FeePaidBadge extends StatelessWidget {
  const _FeePaidBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.green.withValues(alpha: 0.12),
      border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.check_circle_rounded, size: 18, color: AppColors.green),
        SizedBox(width: 8),
        Text(
          'Хураамж төлөгдсөн',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.green),
        ),
      ],
    ),
  );
}

String _formatDateTime(DateTime value) =>
    '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
