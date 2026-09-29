import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/core/widgets/skeletons.dart';
import 'package:carcare_customer_mobile/core/widgets/skeleton.dart';
import 'package:carcare_customer_mobile/core/widgets/state_views.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/branch_card.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/branch_filter_panel.dart';
import 'package:carcare_customer_mobile/features/discovery/services/device_location_service.dart';
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
    this.locationService = const GeolocatorDeviceLocationService(),
    super.key,
  });

  final OrganizationRepository repository;

  /// Device location for the "near me" filter; injectable for tests.
  final DeviceLocationService locationService;
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

  // Branch filters — this screen's own state, deliberately not shared with
  // Discovery's controller so filters set in one tab never narrow the other.
  String _city = '';
  String _district = '';
  String _tag = '';
  bool _nearMe = false;
  bool _openNow = false;
  bool _weekend = false;
  ({double lat, double lng})? _location;
  bool _nearMePending = false;
  bool _openNowPending = false;
  bool _weekendPending = false;
  List<BranchTagOption> _tagOptions = const [];

  // The last fetch made with no branch filters. City/district options come
  // from here, not from the filtered results — otherwise picking "open now"
  // with zero matches would empty the city list and strand the user.
  List<Organization> _catalog = const [];

  // Bumped per results request; a response from an older request is dropped
  // so rapid filter changes can never land out of order.
  int _generation = 0;

  // Rebuilt on every setState so the open filter sheet (a separate route)
  // tracks the screen's filter values and result count live.
  final ValueNotifier<int> _revision = ValueNotifier(0);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _revision.value++;
  }

  @override
  void initState() {
    super.initState();
    _loadKeys();
    _loadTagOptions();
  }

  @override
  void dispose() {
    _revision.dispose();
    super.dispose();
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

  Future<void> _loadTagOptions() async {
    try {
      final tags = await widget.repository.getBranchTags();
      if (!mounted) return;
      setState(() => _tagOptions = tags);
    } catch (_) {
      // Optional filter: the tag dropdown simply stays hidden on failure.
    }
  }

  bool get _hasServerFilters =>
      _city.isNotEmpty ||
      _district.isNotEmpty ||
      _tag.isNotEmpty ||
      _openNow ||
      _weekend ||
      _location != null;

  int get _activeFilterCount => [
    _city.isNotEmpty,
    _district.isNotEmpty,
    _tag.isNotEmpty,
    _nearMe,
    _openNow,
    _weekend,
  ].where((active) => active).length;

  OrganizationFilter get _filter => OrganizationFilter(
    // Cross-org, so one large page is fetched and the service keys are
    // AND-matched on the client (same approach as the web `/book`); the
    // catalog is small enough that server paging isn't needed yet.
    pageSize: 200,
    city: _city,
    district: _district,
    tag: _tag,
    openNow: _openNow,
    weekend: _weekend,
    lat: _location?.lat,
    lng: _location?.lng,
  );

  bool _covers(Branch branch) =>
      _selectedIds.every((id) => branch.serviceKeyIds.contains(id));

  Future<void> _loadResults() async {
    final generation = ++_generation;
    if (_selectedIds.isEmpty) {
      setState(() {
        _resultsStatus = _LoadStatus.empty;
        _results.clear();
      });
      return;
    }
    setState(() => _resultsStatus = _LoadStatus.loading);
    try {
      final needsCatalog = _hasServerFilters && _catalog.isEmpty;
      final responses = await Future.wait([
        widget.repository.getOrganizations(filter: _filter),
        if (needsCatalog)
          widget.repository.getOrganizations(
            filter: const OrganizationFilter(pageSize: 200),
          ),
      ]);
      if (!mounted || generation != _generation) return;
      final page = responses.first;
      final results = <(Organization, Branch)>[
        for (final org in page.organizations)
          for (final branch in org.branches)
            if (_covers(branch)) (org, branch),
      ];
      if (_location != null) {
        // Nearest first; branches without a distance go last.
        results.sort(
          (a, b) => (a.$2.distanceKm ?? double.infinity).compareTo(
            b.$2.distanceKm ?? double.infinity,
          ),
        );
      }
      setState(() {
        if (!_hasServerFilters) {
          _catalog = page.organizations;
        } else if (needsCatalog) {
          _catalog = responses.last.organizations;
        }
        _results
          ..clear()
          ..addAll(results);
        _resultsStatus = results.isEmpty ? _LoadStatus.empty : _LoadStatus.data;
      });
    } on AppFailure catch (failure) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _resultsStatus = _LoadStatus.error;
        _resultsError = failure.message;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _resultsStatus = _LoadStatus.error;
        _resultsError = 'Тодорхойгүй алдаа гарлаа.';
      });
    }
  }

  /// Branches in the unfiltered catalog that can do every selected job —
  /// the pool the location options are drawn from, so each offered city or
  /// district can actually produce a result.
  Iterable<Branch> get _candidateBranches =>
      _catalog.expand((org) => org.branches).where(_covers);

  List<String> get _cities => ({
    for (final branch in _candidateBranches)
      if (branch.city.trim().isNotEmpty) branch.city.trim(),
  }.toList()..sort());

  List<String> get _districts => ({
    for (final branch in _candidateBranches)
      if ((_city.isEmpty || branch.city.trim() == _city) &&
          branch.district.trim().isNotEmpty)
        branch.district.trim(),
  }.toList()..sort());

  void _setCity(String? value) {
    final next = value?.trim() ?? '';
    if (next == _city) return;
    // A district belongs to one city, so changing the city clears it.
    setState(() {
      _city = next;
      _district = '';
    });
    _loadResults();
  }

  void _setDistrict(String? value) {
    final next = value?.trim() ?? '';
    if (next == _district) return;
    setState(() => _district = next);
    _loadResults();
  }

  void _setTag(String id, String name) {
    if (id == _tag) return;
    setState(() => _tag = id);
    _loadResults();
  }

  Future<void> _setOpenNow(bool value) async {
    setState(() {
      _openNow = value;
      _openNowPending = true;
    });
    await _loadResults();
    if (mounted) setState(() => _openNowPending = false);
  }

  Future<void> _setWeekend(bool value) async {
    setState(() {
      _weekend = value;
      _weekendPending = true;
    });
    await _loadResults();
    if (mounted) setState(() => _weekendPending = false);
  }

  Future<void> _setNearMe(bool enabled) async {
    if (!enabled) {
      setState(() {
        _nearMe = false;
        _location = null;
      });
      await _loadResults();
      return;
    }
    // Optimistic: the chip selects at once and spins while locating.
    setState(() {
      _nearMe = true;
      _nearMePending = true;
    });
    final location = await widget.locationService.current();
    if (!mounted) return;
    // Turned off again while the location was being fetched.
    if (!_nearMe) {
      setState(() => _nearMePending = false);
      return;
    }
    if (location == null) {
      setState(() {
        _nearMe = false;
        _nearMePending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Байршлыг авч чадсангүй. Байршлын зөвшөөрөл, тохиргоогоо шалгана уу.',
          ),
        ),
      );
      return;
    }
    setState(() => _location = (lat: location.lat, lng: location.lng));
    await _loadResults();
    if (mounted) setState(() => _nearMePending = false);
  }

  void _clearFilters() {
    if (_activeFilterCount == 0) return;
    setState(() {
      _city = '';
      _district = '';
      _tag = '';
      _nearMe = false;
      _location = null;
      _openNow = false;
      _weekend = false;
    });
    _loadResults();
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

  Widget _filterPanel() => BranchFilterPanel(
    city: _city,
    district: _district,
    cities: _cities,
    districts: _districts,
    onCityChanged: _setCity,
    onDistrictChanged: _setDistrict,
    tag: _tag,
    tagOptions: _tagOptions,
    onTagChanged: _setTag,
    nearMe: _nearMe,
    openNow: _openNow,
    weekend: _weekend,
    nearMePending: _nearMePending,
    openNowPending: _openNowPending,
    weekendPending: _weekendPending,
    onNearMeChanged: _setNearMe,
    onOpenNowChanged: _setOpenNow,
    onWeekendChanged: _setWeekend,
  );

  Future<void> _openFilters() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => ValueListenableBuilder<int>(
      valueListenable: _revision,
      builder: (context, _, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Шүүлтүүр',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (_activeFilterCount > 0)
                    TextButton(
                      key: const ValueKey('service-key-filters-clear'),
                      onPressed: _clearFilters,
                      child: const Text('Бүгдийг арилгах'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _filterPanel(),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('service-key-filters-done'),
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(switch (_resultsStatus) {
                  _LoadStatus.loading => 'Хайж байна…',
                  _LoadStatus.error => 'Хаах',
                  _ => '${_results.length} салбар харуулах',
                }),
              ),
            ],
          ),
        ),
      ),
    ),
  );

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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ямар ажил хийлгэх гэж байна?',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        // Filters only narrow results, so they appear once
                        // there is a selection to narrow.
                        if (_selectedIds.isNotEmpty)
                          IconButton(
                            key: const ValueKey('service-key-filters'),
                            tooltip: 'Шүүлтүүр',
                            onPressed: _openFilters,
                            icon: Badge(
                              isLabelVisible: _activeFilterCount > 0,
                              label: Text('$_activeFilterCount'),
                              child: const Icon(Icons.tune_rounded),
                            ),
                          ),
                      ],
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
              child: EmptyView(
                icon: Icons.build_outlined,
                title: 'Ажлын төрлөө сонгоно уу',
                message:
                    'Хийлгэх ажлаа сонгоход тэдгээрийг бүгдийг гүйцэтгэдэг '
                    'салбарууд энд харагдана.',
              ),
            ),
          ];
        }
        if (_activeFilterCount > 0 && _candidateBranches.isNotEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyView(
                icon: Icons.filter_alt_off_outlined,
                title: 'Шүүлтүүрт тохирох салбар алга',
                message:
                    'Сонгосон ажлуудыг хийдэг салбар бий, гэхдээ '
                    'шүүлтүүрт таарахгүй байна.',
                action: OutlinedButton(
                  key: const ValueKey('service-key-empty-clear-filters'),
                  onPressed: _clearFilters,
                  child: const Text('Шүүлтүүр арилгах'),
                ),
              ),
            ),
          ];
        }
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyView(
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
            child: ErrorView(
              message: _resultsError ?? 'Мэдээлэл ачаалсангүй.',
              onRetry: _loadResults,
            ),
          ),
        ];
      case _LoadStatus.data:
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Text(
                '${_results.length} салбар олдлоо',
                key: const ValueKey('service-key-result-count'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            sliver: SliverList.separated(
              itemCount: _results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final (org, branch) = _results[index];
                // Same card as Discovery so a branch looks identical in both
                // lists; the wrapper keeps this screen's test key.
                return KeyedSubtree(
                  key: ValueKey('service-key-result-${branch.id}'),
                  child: BranchCard(
                    organization: org,
                    branch: branch,
                    onTap: () =>
                        widget.onBranchSelected(org, branch, _selectedKeys),
                  ),
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
    // Nothing picked yet: choosing is the only next step, so it gets the
    // page's primary button. Once tags exist it shrinks into the tag row.
    if (keys.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const ValueKey('service-key-add'),
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ажлын төрөл сонгох'),
        ),
      );
    }
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
            deleteButtonTooltipMessage: 'Хасах',
            materialTapTargetSize: MaterialTapTargetSize.padded,
            visualDensity: VisualDensity.compact,
            backgroundColor: scheme.primary.withValues(alpha: 0.1),
            side: BorderSide(color: scheme.primary.withValues(alpha: 0.3)),
          ),
        ActionChip(
          key: const ValueKey('service-key-add'),
          avatar: Icon(Icons.add_rounded, size: 18, color: scheme.primary),
          label: const Text('Нэмэх'),
          labelStyle: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
          ),
          onPressed: onAdd,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.compact,
          backgroundColor: scheme.primary.withValues(alpha: 0.1),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
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
                    tooltip: 'Хаах',
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
                            tooltip: 'Цэвэрлэх',
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
        return ErrorView(
          message: widget.keysError ?? 'Мэдээлэл ачаалсангүй.',
          onRetry: widget.onRetry,
        );
      case _LoadStatus.empty:
        return const EmptyView(
          icon: Icons.build_outlined,
          title: 'Ажлын төрөл алга байна',
          message: 'Одоогоор сонгох ажлын төрөл бүртгэгдээгүй байна.',
        );
      case _LoadStatus.data:
        final filtered = _filtered;
        if (filtered.isEmpty) {
          return EmptyView(
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
        child: Text(count > 0 ? 'Хэрэглэх ($count)' : 'Сонголтыг цэвэрлэх'),
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
    final radius = BorderRadius.circular(AppRadii.large);
    // Selected rows get a tinted surface and accent border so picks stand
    // out when scanning a long list; the checkbox alone was too faint.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: radius,
        color: selected ? scheme.primary.withValues(alpha: 0.1) : null,
        border: Border.all(
          color: selected
              ? scheme.primary.withValues(alpha: 0.6)
              : Colors.transparent,
        ),
      ),
      child: GlassSurface(
        padding: EdgeInsets.zero,
        child: InkWell(
          key: ValueKey('service-key-${serviceKey.id}'),
          borderRadius: radius,
          onTap: () => onChanged(!selected),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    serviceKey.name,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
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
      ),
    );
  }
}
