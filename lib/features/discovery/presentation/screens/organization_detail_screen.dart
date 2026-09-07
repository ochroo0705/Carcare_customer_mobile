import 'package:cached_network_image/cached_network_image.dart';
import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/core/widgets/skeletons.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/core/config/app_environment.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OrganizationDetailScreen extends StatelessWidget {
  const OrganizationDetailScreen({
    required this.organization,
    required this.status,
    required this.errorMessage,
    required this.onRetry,
    required this.onBack,
    required this.onBook,
    required this.isFavorite,
    required this.onFavoriteToggle,
    super.key,
  });

  final OrganizationDetail? organization;
  final OrganizationDetailStatus status;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  final void Function(OrganizationDetail organization) onBook;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

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
            : _OrganizationDetails(
                organization: organization!,
                onBook: onBook,
                isFavorite: isFavorite,
                onFavoriteToggle: onFavoriteToggle,
              ),
      ),
    ),
  );
}

/// Байгууллагын профайл — салбар сонголт/захиалгын алхмуудыг ЭНД биш,
/// `BookingRequestScreen` дотор явуулна (category-first, дан цэгээс).
/// Энд зөвхөн танилцах мэдээлэл: ерөнхий үйлчилгээ, салбаруудын мэдээлэл
/// (хаяг/цаг), нэг л "Цаг захиалах" товч — тодорхой салбар сонгохгүйгээр.
class _OrganizationDetails extends StatelessWidget {
  const _OrganizationDetails({
    required this.organization,
    required this.onBook,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  final OrganizationDetail organization;
  final void Function(OrganizationDetail organization) onBook;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  /// Байгууллагын БҮХ салбарт байгаа ангиллууд (давхардалгүй, нэрээр
  /// эрэмбэлэгдсэн) — booking screen-ийн `_allCategories`-тай ижил логик.
  List<BranchServiceCategory> get _allCategories {
    final byId = <String, BranchServiceCategory>{};
    for (final branch in organization.branches) {
      for (final category in branch.categories) {
        byId[category.id] = category;
      }
    }
    final values = byId.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return values;
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
    children: [
      _OrganizationHero(
        organization: organization,
        isFavorite: isFavorite,
        onFavoriteToggle: onFavoriteToggle,
      ),
      if (_allCategories.isNotEmpty) ...[
        const SizedBox(height: 24),
        _SectionTitle(
          title: 'Үйлчилгээнүүд',
          subtitle: '${_allCategories.length} төрлийн үйлчилгээ санал болгодог',
        ),
        const SizedBox(height: 12),
        GlassSurface(child: _CategoryChipRow(categories: _allCategories)),
      ],
      const SizedBox(height: 24),
      _SectionTitle(
        title: 'Салбарууд',
        subtitle: '${organization.branches.length} салбар цаг захиалга авч байна',
      ),
      const SizedBox(height: 12),
      if (organization.branches.isEmpty)
        const _NoBranches()
      else
        for (final branch in organization.branches) ...[
          _BranchInfoCard(branch: branch),
          const SizedBox(height: 12),
        ],
      const SizedBox(height: 12),
      FilledButton.icon(
        key: ValueKey('detail-book-${organization.slug}'),
        onPressed:
            AppEnvironment.bookingEnabled && organization.branches.isNotEmpty
            ? () => onBook(organization)
            : null,
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text(
          AppEnvironment.bookingEnabled
              ? 'Цаг захиалах'
              : 'Захиалга түр хаалттай',
        ),
      ),
      const SizedBox(height: 24),
      if (AppEnvironment.bookingEnabled)
        const _BookingSteps()
      else
        const _BookingPausedNotice(),
    ],
  );
}

class _OrganizationHero extends StatelessWidget {
  const _OrganizationHero({
    required this.organization,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  final OrganizationDetail organization;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final openBranches = organization.branches
        .where(
          (branch) =>
              branch.openStatusAt(DateTime.now()) == BranchOpenStatus.open,
        )
        .length;
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
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      icon: Icons.storefront_outlined,
                      label: '${organization.branches.length} салбар',
                    ),
                    _InfoPill(
                      icon: Icons.schedule_rounded,
                      label: '$openBranches нээлттэй',
                      positive: openBranches > 0,
                    ),
                    const _InfoPill(
                      icon: Icons.event_available_outlined,
                      label: 'Онлайн захиалга',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isFavorite
                        ? FilledButton.tonalIcon(
                            key: ValueKey(
                              'detail-favorite-${organization.slug}',
                            ),
                            onPressed: onFavoriteToggle,
                            icon: const Icon(Icons.favorite_rounded),
                            label: const Text('Хадгалсан'),
                          )
                        : OutlinedButton.icon(
                            key: ValueKey(
                              'detail-favorite-${organization.slug}',
                            ),
                            onPressed: onFavoriteToggle,
                            icon: const Icon(Icons.favorite_border_rounded),
                            label: const Text('Хадгалах'),
                          ),
                  ),
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
/// цаг захиалах бүгд `BookingRequestScreen` дотор явагдана.
class _BranchInfoCard extends StatelessWidget {
  const _BranchInfoCard({required this.branch});

  final BranchDetail branch;

  @override
  Widget build(BuildContext context) => GlassSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                branch.name,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
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
        const SizedBox(height: 9),
        _DetailLine(icon: Icons.schedule_rounded, text: branch.hoursLabel),
        if (branch.categories.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CategoryChipRow(categories: branch.categories),
        ],
      ],
    ),
  );
}

class _BookingSteps extends StatelessWidget {
  const _BookingSteps();

  @override
  Widget build(BuildContext context) => GlassSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Захиалгын дараалал',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(
              child: _BookingStep(
                number: '1',
                icon: Icons.build_outlined,
                label: 'Үйлчилгээ',
                active: true,
              ),
            ),
            _StepConnector(),
            Expanded(
              child: _BookingStep(
                number: '2',
                icon: Icons.storefront_outlined,
                label: 'Салбар',
              ),
            ),
            _StepConnector(),
            Expanded(
              child: _BookingStep(
                number: '3',
                icon: Icons.schedule_outlined,
                label: 'Өдөр, цаг',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _BookingPausedNotice extends StatelessWidget {
  const _BookingPausedNotice();

  @override
  Widget build(BuildContext context) => const GlassSurface(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.construction_outlined),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Захиалгын систем шинэчлэгдэж байгаа тул одоогоор түр хаалттай байна.',
          ),
        ),
      ],
    ),
  );
}

class _BookingStep extends StatelessWidget {
  const _BookingStep({
    required this.number,
    required this.icon,
    required this.label,
    this.active = false,
  });

  final String number;
  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: active ? 0.16 : 0.07),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.24)),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 7),
        Text(
          '$number. $label',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector();

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 1,
    margin: const EdgeInsets.only(bottom: 24),
    color: CarCareTheme.of(context).glassBorder,
  );
}

/// Ангиллын жагсаалт (booking v2) — байгууллагын ерөнхий үйлчилгээ эсвэл нэг
/// салбарын санал болгож буй үйлчилгээг харуулахад ашиглана. Чипний тоог
/// хязгаарлаж ("+N бусад"), хэт урт/бөглөрсөн харагдахаас сэргийлнэ.
class _CategoryChipRow extends StatelessWidget {
  const _CategoryChipRow({required this.categories});

  final List<BranchServiceCategory> categories;

  static const _maxVisible = 6;

  @override
  Widget build(BuildContext context) {
    final visible = categories.take(_maxVisible).toList();
    final overflow = categories.length - visible.length;
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in visible)
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
        if (overflow > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: color.withValues(alpha: 0.16)),
            ),
            child: Text(
              '+$overflow бусад',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: color),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 3),
      Text(
        subtitle,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
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
