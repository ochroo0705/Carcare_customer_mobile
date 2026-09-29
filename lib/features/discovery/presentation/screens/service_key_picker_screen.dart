import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/core/widgets/skeletons.dart';
import 'package:carcare_customer_mobile/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';

/// Cross-org "юу хийлгэх гэж байна?" — Booking tab-ийн НЭГ дэлгэц (web-ийн
/// нэгтгэсэн `/book`-той ижил): сонгосон ажлын түрлүүд (SystemServiceKey) жижиг
/// tag-ууд болж дээд хэсэгт байрлаж, тэдгээрийг БҮГДийг нь санал болгодог
/// cross-org салбарууд шууд доор нь жагсаана — хуудас шилжилтгүйгээр. "Ажлын
/// төрөл нэмэх" товч дарахад хайлт+сонголтын тор bottom sheet-ээр нээгдэнэ;
/// sheet дотор ӨӨРИЙН draft сонголттой — dismiss/цуцлах бол хаяна, "Хэрэглэх"
/// дарвал л tag bar болон жагсаалт руу нэг дор шинэчлэгдэнэ.
///
/// Сонголт хоосон үед салбарын жагсаалт ХООСОН (шүүлтгүй бүгдийг харуулахгүй)
/// — ажлын төрлөө сонгохыг урамшуулна (web-ийн адил шийдвэр).
class ServiceKeyPickerScreen extends StatefulWidget {
  const ServiceKeyPickerScreen({
    required this.repository,
    required this.onBranchSelected,
    super.key,
  });

  final OrganizationRepository repository;
  final void Function(
    Organization organization,
    Branch branch,
    List<ServiceKey> serviceKeys,
  )
  onBranchSelected;

  @override
  State<ServiceKeyPickerScreen> createState() => _ServiceKeyPickerScreenState();
}

enum _LoadStatus { loading, data, empty, error }

class _ServiceKeyPickerScreenState extends State<ServiceKeyPickerScreen> {
  _LoadStatus _keysStatus = _LoadStatus.loading;
  List<ServiceKey> _keys = const [];
  String? _keysError;

  final Set<String> _selectedIds = <String>{};

  _LoadStatus _resultsStatus = _LoadStatus.empty;
  String? _resultsError;
  final List<(Organization, Branch)> _results = [];

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    setState(() => _keysStatus = _LoadStatus.loading);
    try {
      final keys = await widget.repository.getServiceKeys();
      if (!mounted) return;
      setState(() {
        _keys = keys;
        _keysStatus = keys.isEmpty ? _LoadStatus.empty : _LoadStatus.data;
        _selectedIds.removeWhere((id) => keys.every((k) => k.id != id));
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _keysStatus = _LoadStatus.error;
        _keysError = failure.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _keysStatus = _LoadStatus.error;
        _keysError = 'Тодорхойгүй алдаа гарлаа.';
      });
    }
  }

  Future<void> _loadResults() async {
    if (_selectedIds.isEmpty) {
      setState(() {
        _resultsStatus = _LoadStatus.empty;
        _results.clear();
      });
      return;
    }
    setState(() => _resultsStatus = _LoadStatus.loading);
    try {
      // Cross-org тул нэг л том хуудсаар татаад client дээр АНД-логикоор
      // шүүнэ (web-ийн `/book`-той ижил хандлага) — энэ каталогийн одоогийн
      // хэмжээнд server талын хуудаслалт шаардлагагүй.
      final page = await widget.repository.getOrganizations(
        filter: const OrganizationFilter(pageSize: 200),
      );
      if (!mounted) return;
      final results = <(Organization, Branch)>[];
      for (final org in page.organizations) {
        for (final branch in org.branches) {
          final covers = _selectedIds.every(
            (id) => branch.serviceKeyIds.contains(id),
          );
          if (covers) results.add((org, branch));
        }
      }
      setState(() {
        _results
          ..clear()
          ..addAll(results);
        _resultsStatus = results.isEmpty ? _LoadStatus.empty : _LoadStatus.data;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _resultsStatus = _LoadStatus.error;
        _resultsError = failure.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resultsStatus = _LoadStatus.error;
        _resultsError = 'Тодорхойгүй алдаа гарлаа.';
      });
    }
  }

  List<ServiceKey> get _selectedKeys =>
      _keys.where((k) => _selectedIds.contains(k.id)).toList(growable: false);

  void _applySelection(Set<String> ids) {
    setState(
      () => _selectedIds
        ..clear()
        ..addAll(ids),
    );
    _loadResults();
  }

  void _removeKey(String id) {
    setState(() => _selectedIds.remove(id));
    _loadResults();
  }

  Future<void> _openPicker() async {
    final applied = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CategoryPickerSheet(
        keysStatus: _keysStatus,
        keysError: _keysError,
        keys: _keys,
        initialSelected: _selectedIds,
        onRetry: _loadKeys,
      ),
    );
    if (applied != null) _applySelection(applied);
  }

  @override
  Widget build(BuildContext context) => AppShellBackground(
    child: SafeArea(
      child: RefreshIndicator(
        onRefresh: () => Future.wait([_loadKeys(), _loadResults()]),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ямар ажил хийлгэх гэж байна?',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    _TagsBar(
                      keys: _selectedKeys,
                      onRemove: _removeKey,
                      onAdd: _openPicker,
                    ),
                  ],
                ),
              ),
            ),
            ..._resultsSlivers(),
          ],
        ),
      ),
    ),
  );

  List<Widget> _resultsSlivers() {
    switch (_resultsStatus) {
      case _LoadStatus.empty:
        if (_selectedIds.isEmpty) {
          return const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _MessageState(
                icon: Icons.build_outlined,
                title: 'Ажлын төрлөө сонгоно уу',
                message:
                    'Дээрх "Ажлын төрөл нэмэх" товчоор сонгоход тохирох '
                    'салбарууд эндээс харагдана.',
              ),
            ),
          ];
        }
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _MessageState(
              icon: Icons.search_off,
              title: 'Салбар олдсонгүй',
              message:
                  'Сонгосон ажлуудыг зэрэг гүйцэтгэдэг салбар олдсонгүй. '
                  'Ажлын төрлөөсөө хасаад дахин үзнэ үү.',
            ),
          ),
        ];
      case _LoadStatus.loading:
        return const [SliverFillRemaining(child: SkeletonAvatarCardList())];
      case _LoadStatus.error:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _MessageState(
              icon: Icons.cloud_off_outlined,
              title: 'Мэдээлэл ачаалсангүй',
              message: _resultsError ?? 'Дахин оролдоно уу.',
              actionLabel: 'Дахин оролдох',
              onAction: _loadResults,
            ),
          ),
        ];
      case _LoadStatus.data:
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            sliver: SliverList.separated(
              itemCount: _results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final (org, branch) = _results[index];
                return _BranchResultCard(
                  organization: org,
                  branch: branch,
                  onTap: () =>
                      widget.onBranchSelected(org, branch, _selectedKeys),
                );
              },
            ),
          ),
        ];
    }
  }
}

class _TagsBar extends StatelessWidget {
  const _TagsBar({
    required this.keys,
    required this.onRemove,
    required this.onAdd,
  });

  final List<ServiceKey> keys;
  final ValueChanged<String> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final key in keys)
          Chip(
            key: ValueKey('service-key-tag-${key.id}'),
            label: Text(key.name),
            onDeleted: () => onRemove(key.id),
            deleteIcon: const Icon(Icons.close, size: 16),
            deleteIconColor: scheme.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
            backgroundColor: scheme.primary.withValues(alpha: 0.1),
            side: BorderSide(color: scheme.primary.withValues(alpha: 0.3)),
          ),
        ActionChip(
          key: const ValueKey('service-key-add'),
          avatar: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Ажлын төрөл нэмэх'),
          onPressed: onAdd,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

/// Ажлын төрөл сонгох bottom sheet — ӨӨРИЙН draft сонголттой (нээгдэх үед
/// эцгийн одоогийн сонголтоор эхэлнэ). Sheet-ийг dismiss хийх (доош чирэх,
/// backdrop дарах) бол `Navigator.pop`-д утга дамжуулахгүй тул эцэг тал
/// (`_openPicker`-ийн `applied == null`) юу ч өөрчлөхгүй; "Хэрэглэх" дарвал
/// draft-аа `pop`-д дамжуулна.
class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.keysStatus,
    required this.keysError,
    required this.keys,
    required this.initialSelected,
    required this.onRetry,
  });

  final _LoadStatus keysStatus;
  final String? keysError;
  final List<ServiceKey> keys;
  final Set<String> initialSelected;
  final VoidCallback onRetry;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  late final Set<String> _draft = {...widget.initialSelected};
  String _query = '';

  List<ServiceKey> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.keys;
    return widget.keys
        .where((k) => k.name.toLowerCase().contains(q))
        .toList(growable: false);
  }

  void _toggle(String id, bool selected) {
    setState(() {
      if (selected) {
        _draft.add(id);
      } else {
        _draft.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ажлын төрөл сонгох',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (widget.keysStatus == _LoadStatus.data)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  key: const ValueKey('service-key-search'),
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Ажлын төрлөөр хайх...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(() => _query = ''),
                          ),
                    isDense: true,
                  ),
                ),
              ),
            Expanded(child: _body(scrollController)),
            _ApplyBar(
              count: _draft.length,
              onApply: () => Navigator.of(context).pop(_draft),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(ScrollController scrollController) {
    switch (widget.keysStatus) {
      case _LoadStatus.loading:
        return SkeletonList(
          itemCount: 8,
          separator: 8,
          itemBuilder: (_, _) => const Row(
            children: [
              SkeletonBox(height: 20, width: 20, radius: 6),
              SizedBox(width: 14),
              Expanded(child: SkeletonBox(height: 14)),
            ],
          ),
        );
      case _LoadStatus.error:
        return _MessageState(
          icon: Icons.cloud_off_outlined,
          title: 'Мэдээлэл ачаалсангүй',
          message: widget.keysError ?? 'Дахин оролдоно уу.',
          actionLabel: 'Дахин оролдох',
          onAction: widget.onRetry,
        );
      case _LoadStatus.empty:
        return const _MessageState(
          icon: Icons.build_outlined,
          title: 'Ажлын төрөл алга байна',
          message: 'Одоогоор сонгох ажлын төрөл бүртгэгдээгүй байна.',
        );
      case _LoadStatus.data:
        final filtered = _filtered;
        if (filtered.isEmpty) {
          return _MessageState(
            icon: Icons.search_off,
            title: 'Олдсонгүй',
            message: '"$_query" гэсэн ажлын төрөл олдсонгүй.',
          );
        }
        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final key = filtered[index];
            return _ServiceKeyCard(
              serviceKey: key,
              selected: _draft.contains(key.id),
              onChanged: (selected) => _toggle(key.id, selected),
            );
          },
        );
    }
  }
}

class _ApplyBar extends StatelessWidget {
  const _ApplyBar({required this.count, required this.onApply});

  final int count;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      border: Border(
        top: BorderSide(color: CarCareTheme.of(context).glassBorder),
      ),
    ),
    child: SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: const ValueKey('service-key-apply'),
        onPressed: onApply,
        child: Text(count > 0 ? 'Хэрэглэх ($count)' : 'Хэрэглэх'),
      ),
    ),
  );
}

class _ServiceKeyCard extends StatelessWidget {
  const _ServiceKeyCard({
    required this.serviceKey,
    required this.selected,
    required this.onChanged,
  });

  final ServiceKey serviceKey;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        key: ValueKey('service-key-${serviceKey.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!selected),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Icon(
                Icons.build_circle_outlined,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  serviceKey.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Checkbox(
                value: selected,
                onChanged: (value) => onChanged(value ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchResultCard extends StatelessWidget {
  const _BranchResultCard({
    required this.organization,
    required this.branch,
    required this.onTap,
  });

  final Organization organization;
  final Branch branch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        key: ValueKey('service-key-result-${branch.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  organization.name.isEmpty
                      ? '?'
                      : organization.name.characters.first.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branch.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      organization.name,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 18),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}
