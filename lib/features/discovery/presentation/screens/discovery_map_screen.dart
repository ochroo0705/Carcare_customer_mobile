import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/discovery_map.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Бүтэн дэлгэцийн газрын зураг — Explore-ийн жагсаалт дотор шигтгээгүй тул
/// одоо floating товчоор нээгддэг тусдаа хуудас. Дарсан цэгээс тухайн
/// салбарынхаа мэдээллийг web-тэй ижил байдлаар дэлгэнэ (`onBranchSelected`).
class DiscoveryMapScreen extends StatelessWidget {
  const DiscoveryMapScreen({
    required this.onBranchSelected,
    required this.onBack,
    super.key,
  });

  final void Function(Organization organization, Branch branch)
  onBranchSelected;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DiscoveryController>();
    final detailController = context.read<OrganizationDetailController>();
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: const Text('Газрын зураг'),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) => DiscoveryMap(
              organizations: controller.visibleOrganizations,
              hasActiveFilters: controller.hasActiveFilters,
              height: constraints.maxHeight,
              organizationDetailController: detailController,
              onBranchSelected: onBranchSelected,
              onShowList: onBack,
            ),
          ),
        ),
      ),
    );
  }
}
