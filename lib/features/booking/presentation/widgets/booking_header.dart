import 'package:cached_network_image/cached_network_image.dart';
import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/branch_open_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Захиалгын хуудасны толгой хэсэг — байгууллагын лого/утас, ба сонгосон
/// салбарын (эсвэл түүнийг сонгоогүй бол байгууллагын товч тоо баримтын)
/// мэдээллийг харуулна. Зөвхөн танилцуулах — сонголт/захиалгын үйлдэлгүй.
class BookingHeader extends StatelessWidget {
  const BookingHeader({
    super.key,
    required this.organization,
    required this.selectedBranch,
    required this.categoryCount,
  });

  final OrganizationDetail organization;
  final BranchDetail? selectedBranch;
  final int categoryCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final branch = selectedBranch;
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
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
                child: _BookingHeaderLogo(
                  name: organization.name,
                  logoUrl: organization.logoUrl,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organization.name,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (organization.phone != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 15,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              organization.phone!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            key: const ValueKey('booking-copy-phone'),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (branch == null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(
                  icon: Icons.storefront_outlined,
                  label: '${organization.branches.length} салбар',
                ),
                if (categoryCount > 0)
                  _InfoPill(
                    icon: Icons.design_services_outlined,
                    label: '$categoryCount үйлчилгээ',
                  ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                _OpenBadge(status: branch.openStatusAt(DateTime.now())),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    branch.hoursLabel,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              branch.name,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (branch.fullAddress.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                branch.fullAddress,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _BookingHeaderLogo extends StatelessWidget {
  const _BookingHeaderLogo({required this.name, required this.logoUrl});

  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    // Center the letter itself: as a CachedNetworkImage placeholder/errorWidget
    // it fills the image box, which does not center its child by default.
    final letter = Center(
      child: Text(
        name.characters.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
    final url = logoUrl?.trim();
    if (url == null || url.isEmpty) return letter;
    return CachedNetworkImage(
      imageUrl: url,
      width: 56,
      height: 56,
      fit: BoxFit.cover,
      placeholder: (_, _) => letter,
      errorWidget: (_, _, _) => letter,
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadii.pill),
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
    final color = branchOpenColor(status, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            switch (status) {
              BranchOpenStatus.open => 'Нээлттэй',
              BranchOpenStatus.closed => 'Хаалттай',
              BranchOpenStatus.unknown => 'Төлөв тодорхойгүй',
            },
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.readable(color, Theme.of(context).brightness),
            ),
          ),
        ],
      ),
    );
  }
}
