import 'package:cached_network_image/cached_network_image.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/branch_open_style.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Пин дарахад гарч ирэх карт — web-ийн газрын зураг дээрх карттай ижил
/// түвшний мэдээлэл (лого, нээлттэй/хаалттай төлөв + цаг, хаяг, утас,
/// ангилалууд) харуулахын тулд тухайн байгууллагын дэлгэрэнгүйг (`detailController`)
/// цөөнгүй ачаалж, ирэх хүртэл зөвхөн жагсаалтаас аль хэдийн байгаа
/// нэр/зай мэдээллийг харуулна.
/// This card is a quick preview meant to fit alongside the map — it shows a
/// handful of categories plus a "+N" count rather than every single one
/// (unlike the organization detail page, which has room for the full list).
const _maxPreviewCategories = 4;

class SelectedBranchCard extends StatelessWidget {
  const SelectedBranchCard({
    required this.organization,
    required this.branch,
    required this.detailController,
    required this.onClose,
    required this.onDetails,
    super.key,
  });

  final Organization organization;
  final Branch branch;
  final OrganizationDetailController detailController;
  final VoidCallback onClose;
  final VoidCallback onDetails;

  BranchDetail? _matchingBranch(OrganizationDetail detail) {
    for (final candidate in detail.branches) {
      if (candidate.id == branch.id) return candidate;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = detailController.organization;
    final detailMatches = detail != null && detail.slug == organization.slug;
    final loadingDetail =
        detailController.status == OrganizationDetailStatus.loading &&
        !detailMatches;
    final branchDetail = detailMatches ? _matchingBranch(detail) : null;
    return Material(
      color: scheme.surface,
      elevation: 12,
      borderRadius: BorderRadius.circular(AppRadii.extraLarge),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardLogo(organization: organization),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          organization.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          branch.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        if (branchDetail != null) ...[
                          const SizedBox(height: 6),
                          _OpenStatusLine(branch: branchDetail),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Хаах',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (branch.distanceLabel != null) ...[
                _CardDetail(
                  icon: Icons.near_me_outlined,
                  text: branch.distanceLabel!,
                ),
                const SizedBox(height: 6),
              ],
              _CardDetail(
                icon: Icons.place_outlined,
                text: branchDetail?.fullAddress ?? branch.locationLabel,
              ),
              if (branchDetail != null) ...[
                const SizedBox(height: 6),
                _CardDetail(
                  icon: Icons.schedule_rounded,
                  text: branchDetail.hoursLabel,
                ),
              ],
              if (detail?.phone != null) ...[
                const SizedBox(height: 6),
                _PhoneLine(phone: detail!.phone!),
              ],
              if (loadingDetail) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Дэлгэрэнгүй ачаалж байна…',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
              if (branchDetail != null &&
                  branchDetail.categories.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Quick preview card: a taste of what's offered, not the
                    // full list — that's what the detail page is for.
                    for (final category in branchDetail.categories.take(
                      _maxPreviewCategories,
                    ))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          category.name,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    if (branchDetail.categories.length > _maxPreviewCategories)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          '+${branchDetail.categories.length - _maxPreviewCategories}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Дэлгэрэнгүй'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardLogo extends StatelessWidget {
  const _CardLogo({required this.organization});

  final Organization organization;

  @override
  Widget build(BuildContext context) {
    final letter = Center(
      child: Text(
        organization.name.characters.isEmpty
            ? '?'
            : organization.name.characters.first.toUpperCase(),
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
    final logoUrl = organization.logoUrl?.trim();
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: CarCareTheme.of(context).glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl == null || logoUrl.isEmpty
          ? letter
          : CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => letter,
              errorWidget: (_, _, _) => letter,
            ),
    );
  }
}

class _OpenStatusLine extends StatelessWidget {
  const _OpenStatusLine({required this.branch});

  final BranchDetail branch;

  @override
  Widget build(BuildContext context) {
    final status = branch.openStatusAt(DateTime.now());
    final color = branchOpenColor(status, context);
    final label = switch (status) {
      BranchOpenStatus.open => 'Нээлттэй',
      BranchOpenStatus.closed => 'Хаалттай',
      BranchOpenStatus.unknown => 'Төлөв тодорхойгүй',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.readable(color, Theme.of(context).brightness),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PhoneLine extends StatelessWidget {
  const _PhoneLine({required this.phone});

  final String phone;

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: _call,
    borderRadius: BorderRadius.circular(AppRadii.small),
    child: Row(
      children: [
        Icon(
          Icons.phone_outlined,
          size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            phone,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CardDetail extends StatelessWidget {
  const _CardDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 17,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}
