import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/organization_avatar.dart';
import 'package:flutter/material.dart';

/// Салбарын карт — Explore жагсаалт одоо байгууллагын биш салбарын түвшинд
/// харагдана; эзэн байгууллагын нэрийг дэд гарчиг болгож үлдээв.
class BranchCard extends StatelessWidget {
  const BranchCard({
    required this.organization,
    required this.branch,
    required this.onTap,
    super.key,
  });
  final Organization organization;
  final Branch branch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassSurface(
      key: ValueKey('branch-${organization.slug}-${branch.id}'),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrganizationAvatar(
            name: organization.name,
            logoUrl: organization.logoUrl,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.name,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                // Бизнесийн төрлийн шошго (жиш: "Угаалгын газар") — нэрийн
                // яг доор, тухайн салбар "ямар газар вэ" гэдгийг эхлээд
                // харуулна (хаяг/зайнаас илүү тэргүүлэх ач холбогдолтой тул).
                // Олон шошготой бол ердийн текстээр таслалаар нэгтгэнэ — chip
                // биш, гарчгийн мөр өнгөлөг/түгжрэлтэй болохоос сэргийлнэ.
                if (branch.tags.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    branch.tags.map((t) => t.name).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  organization.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  branch.locationLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (branch.distanceLabel != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _InfoChip(
                        icon: Icons.near_me_outlined,
                        label: branch.distanceLabel!,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
