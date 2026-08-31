import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OrganizationDetailScreen extends StatelessWidget {
  const OrganizationDetailScreen({
    required this.organization,
    required this.isLoading,
    required this.onBack,
    super.key,
  });

  final Organization? organization;
  final bool isLoading;
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
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : organization == null
            ? _NotFound(onBack: onBack)
            : _OrganizationDetails(organization: organization!),
      ),
    ),
  );
}

class _OrganizationDetails extends StatefulWidget {
  const _OrganizationDetails({required this.organization});

  final Organization organization;

  @override
  State<_OrganizationDetails> createState() => _OrganizationDetailsState();
}

class _OrganizationDetailsState extends State<_OrganizationDetails> {
  late String _selectedBranchId;

  Organization get organization => widget.organization;

  @override
  void initState() {
    super.initState();
    _selectedBranchId = organization.branches.isEmpty
        ? ''
        : organization.branches
              .firstWhere(
                (branch) => branch.isOpen,
                orElse: () => organization.branches.first,
              )
              .id;
  }

  @override
  void didUpdateWidget(covariant _OrganizationDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organization.slug == organization.slug) return;
    _selectedBranchId = organization.branches.isEmpty
        ? ''
        : organization.branches.first.id;
  }

  Branch? get _selectedBranch {
    for (final branch in organization.branches) {
      if (branch.id == _selectedBranchId) return branch;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
    children: [
      _OrganizationHero(organization: organization),
      const SizedBox(height: 24),
      _SectionTitle(
        title: 'Салбар сонгох',
        subtitle:
            '${organization.branches.length} салбар цаг захиалга авч байна',
      ),
      const SizedBox(height: 12),
      if (organization.branches.isEmpty)
        const _NoBranches()
      else ...[
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: organization.branches.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final branch = organization.branches[index];
              return ChoiceChip(
                key: ValueKey('branch-choice-${branch.id}'),
                selected: branch.id == _selectedBranchId,
                onSelected: (_) {
                  setState(() => _selectedBranchId = branch.id);
                },
                avatar: _StatusDot(isOpen: branch.isOpen),
                label: Text(branch.name),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          child: _selectedBranch == null
              ? const SizedBox.shrink()
              : _SelectedBranchCard(
                  key: ValueKey(_selectedBranch!.id),
                  organization: organization,
                  branch: _selectedBranch!,
                  onBook: () => _showBookingHandoff(
                    context,
                    organization,
                    _selectedBranch!,
                  ),
                ),
        ),
      ],
      const SizedBox(height: 24),
      const _BookingSteps(),
    ],
  );

  Future<void> _showBookingHandoff(
    BuildContext context,
    Organization organization,
    Branch branch,
  ) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Захиалга эхлүүлэх',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      organization.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SummaryRow(
            icon: Icons.storefront_outlined,
            label: 'Сонгосон салбар',
            value: branch.name,
          ),
          const SizedBox(height: 12),
          Text(
            'Дараагийн үе шатанд үйлчилгээ, өдөр болон боломжит цагаа сонгоно.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Үйлчилгээ сонгох — дараагийн шат'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _OrganizationHero extends StatelessWidget {
  const _OrganizationHero({required this.organization});

  final Organization organization;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final openBranches = organization.branches
        .where((branch) => branch.isOpen)
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
                      child: Text(
                        organization.name.characters.first.toUpperCase(),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
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
                              Text(
                                organization.phone,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedBranchCard extends StatelessWidget {
  const _SelectedBranchCard({
    required this.organization,
    required this.branch,
    required this.onBook,
    super.key,
  });

  final Organization organization;
  final Branch branch;
  final VoidCallback onBook;

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
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            _OpenBadge(isOpen: branch.isOpen),
          ],
        ),
        const SizedBox(height: 16),
        _DetailLine(icon: Icons.place_outlined, text: branch.address),
        const SizedBox(height: 11),
        _DetailLine(
          icon: Icons.location_city_outlined,
          text: '${branch.city} · ${branch.district}',
        ),
        const SizedBox(height: 11),
        _DetailLine(icon: Icons.schedule_rounded, text: branch.hours),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: organization.phone),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Утасны дугаар хууллаа')),
                  );
                },
                icon: const Icon(Icons.phone_outlined),
                label: const Text('Утас хуулах'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onBook,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Цаг захиалах'),
              ),
            ),
          ],
        ),
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
                icon: Icons.storefront_outlined,
                label: 'Салбар',
                active: true,
              ),
            ),
            _StepConnector(),
            Expanded(
              child: _BookingStep(
                number: '2',
                icon: Icons.build_outlined,
                label: 'Үйлчилгээ',
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
  const _OpenBadge({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final color = isOpen
        ? AppColors.green
        : Theme.of(context).colorScheme.error;
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
          _StatusDot(isOpen: isOpen),
          const SizedBox(width: 6),
          Text(
            isOpen ? 'Нээлттэй' : 'Хаалттай',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: isOpen ? AppColors.green : Theme.of(context).colorScheme.error,
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
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
