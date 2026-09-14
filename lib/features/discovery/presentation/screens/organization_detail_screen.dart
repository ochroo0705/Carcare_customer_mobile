import 'package:cached_network_image/cached_network_image.dart';
import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/core/widgets/skeletons.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/services/location_permission_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class OrganizationDetailScreen extends StatelessWidget {
  const OrganizationDetailScreen({
    required this.organization,
    this.distanceLocation,
    this.branchId,
    required this.status,
    required this.errorMessage,
    required this.onRetry,
    required this.onBack,
    super.key,
  });

  final OrganizationDetail? organization;
  final ({double lat, double lng})? distanceLocation;
  final String? branchId;
  final OrganizationDetailStatus status;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: onBack),
      title: const Text('Сервисийн мэдээлэл'),
    ),
    body: AppShellBackground(
      child: SafeArea(
        top: false,
        child:
            status == OrganizationDetailStatus.loading ||
                status == OrganizationDetailStatus.initial
            ? const SkeletonDetail()
            : status == OrganizationDetailStatus.error
            ? _DetailError(
                message: errorMessage ?? 'Мэдээлэл ачаалсангүй.',
                onRetry: onRetry,
              )
            : organization == null
            ? _NotFound(onBack: onBack)
            : _BranchDetailView(
                organization: organization!,
                branchId: branchId,
                distanceLocation: distanceLocation,
              ),
      ),
    ),
  );
}

/// Нэг салбарын танилцах хуудас — Explore одоо зөвхөн харах (browse) хэсэг
/// болсон тул сонголт/захиалгын үйлдэлгүй: байгууллагын танилцуулга (лого,
/// утас, хадгалах) дээр дарж орсон яг тэр салбарынхаа хаяг/цаг/үйлчилгээг
/// харуулна. Цаг захиалах нь тусдаа Booking таб руу шилжсэн.
class _BranchDetailView extends StatelessWidget {
  const _BranchDetailView({
    required this.organization,
    required this.branchId,
    required this.distanceLocation,
  });

  final OrganizationDetail organization;
  final String? branchId;
  final ({double lat, double lng})? distanceLocation;

  BranchDetail? get _branch {
    if (organization.branches.isEmpty) return null;
    final id = branchId;
    if (id == null) return organization.branches.first;
    for (final branch in organization.branches) {
      if (branch.id == id) return branch;
    }
    return organization.branches.first;
  }

  @override
  Widget build(BuildContext context) {
    final branch = _branch;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
      children: [
        _OrganizationHero(organization: organization),
        const SizedBox(height: 24),
        if (branch == null)
          const _NoBranches()
        else
          _BranchInfoCard(
            branch: branch,
            distanceLocation: distanceLocation,
            highlightLabel: null,
          ),
      ],
    );
  }
}

class _OrganizationHero extends StatelessWidget {
  const _OrganizationHero({required this.organization});

  final OrganizationDetail organization;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassSurface(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned(
            right: -44,
            top: -52,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 66,
                      height: 66,
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
                      child: _HeroLogo(
                        name: organization.name,
                        logoUrl: organization.logoUrl,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            organization.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  organization.phone ?? 'Утас тодорхойгүй',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              if (organization.phone != null)
                                InkWell(
                                  key: ValueKey(
                                    'detail-copy-phone-${organization.slug}',
                                  ),
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
                      ),
                    ),
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

/// Байгууллагын лого — hero-гийн gradient хүрээ дотор дүүргэж харуулна
/// (`OrganizationAvatar`-тай ижил `CachedNetworkImage` cache-ийг URL-ээр
/// хуваалцана). Лого байхгүй/уншиж байх/алдаа гарвал нэрний эхний үсэг рүү
/// уначна — дискавери жагсаалттай ижил зан төлөв, hero-гийн загварыг хадгална.
class _HeroLogo extends StatelessWidget {
  const _HeroLogo({required this.name, required this.logoUrl});

  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    // Center the letter itself: as a CachedNetworkImage placeholder/errorWidget
    // it fills the 66×66 image box, which does not center its child (the letter
    // would otherwise stick to the top-left).
    final letter = Center(
      child: Text(
        name.characters.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
    final url = logoUrl?.trim();
    if (url == null || url.isEmpty) return letter;
    return CachedNetworkImage(
      imageUrl: url,
      width: 66,
      height: 66,
      fit: BoxFit.cover,
      placeholder: (_, _) => letter,
      errorWidget: (_, _, _) => letter,
    );
  }
}

/// Нэг салбарын танилцах мэдээлэл (хаяг, цагийн хуваарь, санал болгож буй
/// үйлчилгээ) — сонголт/захиалгын үйлдэлгүй, зөвхөн харуулна. Салбар сонгох,
/// цаг захиалах бүгд Booking таб дотор явагдана.
class _BranchInfoCard extends StatelessWidget {
  const _BranchInfoCard({
    required this.branch,
    required this.distanceLocation,
    required this.highlightLabel,
  });

  final BranchDetail branch;
  final ({double lat, double lng})? distanceLocation;
  final String? highlightLabel;

  Future<void> _openDirections(BuildContext context) async {
    final destination = '${branch.latitude},${branch.longitude}';
    // With location permission, open turn-by-turn directions (the map app
    // routes from the user's position). Without it, just drop a pin — we
    // don't force a permission prompt from a plain "view this place" tap.
    LocationAccessState access;
    try {
      access = await const PermissionHandlerLocationPermissionService().check();
    } catch (_) {
      access = LocationAccessState.denied;
    }
    final directions = access == LocationAccessState.granted;
    // Prefer each platform's native map app: Apple Maps on iOS, Google Maps
    // on Android. Both are https universal links, so if the native app is
    // absent they still open in the browser.
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
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('launch returned false');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Газрын зураг нээх боломжгүй байна')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => GlassSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch.name,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (highlightLabel != null) ...[
                    const SizedBox(height: 5),
                    _InfoPill(
                      icon: Icons.near_me_outlined,
                      label: highlightLabel!,
                      positive: true,
                    ),
                  ],
                ],
              ),
            ),
            _OpenBadge(status: branch.openStatusAt(DateTime.now())),
          ],
        ),
        const SizedBox(height: 12),
        _DetailLine(icon: Icons.place_outlined, text: branch.fullAddress),
        const SizedBox(height: 9),
        _DetailLine(
          icon: Icons.location_city_outlined,
          text: branch.locationLabel,
        ),
        if (distanceLocation != null &&
            branch.distanceLabelFrom(
                  userLatitude: distanceLocation!.lat,
                  userLongitude: distanceLocation!.lng,
                ) !=
                null) ...[
          const SizedBox(height: 9),
          _DetailLine(
            icon: Icons.near_me_outlined,
            text: branch.distanceLabelFrom(
              userLatitude: distanceLocation!.lat,
              userLongitude: distanceLocation!.lng,
            )!,
          ),
        ],
        if (branch.latitude != null && branch.longitude != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openDirections(context),
            icon: const Icon(Icons.directions_outlined, size: 18),
            label: const Text('Чиглэл харах'),
          ),
        ],
        const SizedBox(height: 9),
        _DetailLine(icon: Icons.schedule_rounded, text: branch.hoursLabel),
        if (branch.schedules.isNotEmpty) ...[
          const SizedBox(height: 12),
          _WeeklyHoursTable(schedules: branch.schedules),
        ],
        if (_UpcomingScheduleNotices.hasAny(branch)) ...[
          const SizedBox(height: 12),
          _UpcomingScheduleNotices(branch: branch),
        ],
        if (branch.categories.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Үзүүлдэг үйлчилгээнүүд',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _CategoryChipRow(categories: branch.categories),
        ],
      ],
    ),
  );
}

const _weekdayOrder = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _weekdayLabels = {
  'MON': 'Даваа',
  'TUE': 'Мягмар',
  'WED': 'Лхагва',
  'THU': 'Пүрэв',
  'FRI': 'Баасан',
  'SAT': 'Бямба',
  'SUN': 'Ням',
};

/// Долоо хоногийн бүтэн цагийн хуваарь — `branch.hoursLabel` зөвхөн өнөөдрийн
/// нэг мөрийг харуулдаг тул үүнийг долоо хоног бүрээр дэлгэв.
class _WeeklyHoursTable extends StatelessWidget {
  const _WeeklyHoursTable({required this.schedules});

  final List<BranchScheduleRule> schedules;

  BranchScheduleRule? _ruleFor(String weekday) {
    for (final rule in schedules) {
      if (rule.weekday == weekday) return rule;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final today = _weekdayOrder[(DateTime.now().weekday + 6) % 7];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Долоо хоногийн цагийн хуваарь',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final weekday in _weekdayOrder)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    _weekdayLabels[weekday]!,
                    style: weekday == today
                        ? TextStyle(fontWeight: FontWeight.w700)
                        : TextStyle(color: color),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final rule = _ruleFor(weekday);
                    final label = rule == null || !rule.isOpen
                        ? 'Хаалттай'
                        : (rule.openTime != null && rule.closeTime != null
                              ? '${rule.openTime}–${rule.closeTime}'
                              : 'Цагийн мэдээлэл тодорхойгүй');
                    return Text(
                      label,
                      style: weekday == today
                          ? TextStyle(fontWeight: FontWeight.w700)
                          : TextStyle(color: color),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Ойрын тусгай өдрүүд (амралт/өөрчлөгдсөн цаг) болон улирлын хуваарийн
/// мэдэгдэл — зөвхөн өнөөдрөөс хойшхи (одоо хүчинтэй/ирээдүйн) зүйлийг
/// харуулна, өнгөрсөн тусгай өдрүүдийг харуулах шаардлагагүй.
class _UpcomingScheduleNotices extends StatelessWidget {
  const _UpcomingScheduleNotices({required this.branch});

  final BranchDetail branch;

  static String get _today {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static List<BranchScheduleException> _upcomingExceptions(
    BranchDetail branch,
  ) => branch.scheduleExceptions
      .where((exception) => exception.date.compareTo(_today) >= 0)
      .toList(growable: false);

  static List<BranchScheduleSeason> _activeOrUpcomingSeasons(
    BranchDetail branch,
  ) => branch.scheduleSeasons
      .where((season) => season.endsOn.compareTo(_today) >= 0)
      .toList(growable: false);

  static bool hasAny(BranchDetail branch) =>
      _upcomingExceptions(branch).isNotEmpty ||
      _activeOrUpcomingSeasons(branch).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final exceptions = _upcomingExceptions(branch);
    final seasons = _activeOrUpcomingSeasons(branch);
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Онцгой өдрүүд',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final exception in exceptions)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${exception.date}: ${exception.label ?? (exception.isOpen ? 'Өөрчлөгдсөн цагтай' : 'Амарна')}'
              '${exception.isOpen && exception.openTime != null && exception.closeTime != null ? ' (${exception.openTime}–${exception.closeTime})' : ''}',
              style: TextStyle(color: color),
            ),
          ),
        for (final season in seasons)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${season.name}: ${season.startsOn} – ${season.endsOn}',
              style: TextStyle(color: color),
            ),
          ),
      ],
    );
  }
}

/// Ангиллын жагсаалт (booking v2) — нэг салбарын санал болгож буй БҮХ
/// үйлчилгээг харуулна. Энэ хуудас нь ганц салбарт зориулагдсан тул
/// (жагсаалт дахь бусад мэдээллийг эзэлдэггүй) хязгаарлах шаардлагагүй.
class _CategoryChipRow extends StatelessWidget {
  const _CategoryChipRow({required this.categories});

  final List<BranchServiceCategory> categories;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in categories)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: color.withValues(alpha: 0.16)),
            ),
            child: Text(
              category.name,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    this.positive = false,
  });

  final IconData icon;
  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive
        ? AppColors.green
        : Theme.of(context).colorScheme.onSurfaceVariant;
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
          _StatusDot(status: status),
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

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final BranchOpenStatus status;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: switch (status) {
        BranchOpenStatus.open => AppColors.green,
        BranchOpenStatus.closed => Theme.of(context).colorScheme.error,
        BranchOpenStatus.unknown => Theme.of(
          context,
        ).colorScheme.onSurfaceVariant,
      },
      shape: BoxShape.circle,
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        icon,
        size: 19,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ),
    ],
  );
}

class _NoBranches extends StatelessWidget {
  const _NoBranches();

  @override
  Widget build(BuildContext context) => const GlassSurface(
    child: Row(
      children: [
        Icon(Icons.storefront_outlined),
        SizedBox(width: 12),
        Expanded(child: Text('Энэ байгууллага идэвхтэй салбаргүй байна.')),
      ],
    ),
  );
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
          const Icon(Icons.search_off, size: 48),
          const SizedBox(height: 12),
          const Text('Байгууллага олдсонгүй'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onBack,
            child: const Text('Жагсаалт руу буцах'),
          ),
        ],
      ),
    ),
  );
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Дахин оролдох')),
        ],
      ),
    ),
  );
}
