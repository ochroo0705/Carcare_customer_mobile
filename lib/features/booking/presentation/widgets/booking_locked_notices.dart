import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:flutter/material.dart';

/// `lockCategories` урсгал үргэлжлэх боломжгүй үеийн бүтэн дэлгэцийн мэдэгдэл
/// (салбар олдоогүй, эсвэл сонгосон ангилал БҮГД цаашид энэ салбарт байхгүй
/// болсон) — цаашаа явахгүй, буцаж дахин сонгуулна.
class LockedFlowUnavailable extends StatelessWidget {
  const LockedFlowUnavailable({
    super.key,
    required this.branchMissing,
    required this.onBack,
  });

  final bool branchMissing;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            branchMissing
                ? 'Сонгосон салбар олдсонгүй. Дахин сонгоно уу.'
                : 'Сонгосон бүх үйлчилгээг энэ салбар цаашид санал болгохгүй '
                      'боллоо. Дахин сонгоно уу.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onBack, child: const Text('Буцах')),
        ],
      ),
    ),
  );
}

/// Хэсэгчлэн боломжгүй болсон ангиллуудыг сануулах — блокдоггүй, зөвхөн
/// мэдээлнэ (боломжтой хэсгээр захиалга үргэлжилнэ).
class LockedCategoriesWarning extends StatelessWidget {
  const LockedCategoriesWarning({super.key, required this.unavailableNames});

  final List<String> unavailableNames;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Энэ салбар цаашид дараах үйлчилгээг санал болгохгүй тул '
              'захиалгаас хасагдлаа: ${unavailableNames.join(', ')}.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
