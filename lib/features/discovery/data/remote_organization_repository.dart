import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/features/discovery/data/organization_dto.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';

/// Public organization catalog-ийн API adapter.
///
/// `/orgs` нь list-д зориулсан summary payload, `/orgs/[slug]` нь booking-д
/// хэрэгтэй detail payload буцаадаг тул хоёр response-ийг нэг DTO гэж үзэхгүй.
/// Detail-ийн memory cache нь нэг app session доторх давхар хүсэлтийг багасгана;
/// урт хугацааны offline cache-г [CachingOrganizationRepository] хариуцна.
class RemoteOrganizationRepository implements OrganizationRepository {
  RemoteOrganizationRepository(this._client);

  final ApiClient _client;
  final Map<String, OrganizationDetail> _detailCache = {};

  @override
  Future<OrganizationPage> getOrganizations({
    OrganizationFilter? filter,
  }) async {
    final query = <String, String>{};
    final current = filter ?? const OrganizationFilter();
    if (current.query.isNotEmpty) query['q'] = current.query;
    if (current.city.isNotEmpty) query['city'] = current.city;
    if (current.district.isNotEmpty) query['district'] = current.district;
    query['page'] = current.page.toString();
    query['pageSize'] = current.pageSize.toString();
    if (current.hasNearMe) {
      query['lat'] = current.lat!.toString();
      query['lng'] = current.lng!.toString();
      if (current.radiusKm != null) {
        query['radius'] = current.radiusKm!.toString();
      }
    }
    if (current.openNow) query['openNow'] = '1';
    if (current.weekend) query['weekend'] = '1';
    final path = '/orgs?${Uri(queryParameters: query).query}';
    final json = await _client.getJson(path);
    return organizationPageFromJson(json);
  }

  @override
  Future<OrganizationMapPage> getMapMarkers({
    required MapViewport viewport,
    OrganizationFilter? filter,
  }) async {
    final current = filter ?? const OrganizationFilter();
    final query = <String, String>{
      'north': viewport.north.toString(),
      'south': viewport.south.toString(),
      'east': viewport.east.toString(),
      'west': viewport.west.toString(),
    };
    if (current.query.isNotEmpty) query['q'] = current.query;
    if (current.city.isNotEmpty) query['city'] = current.city;
    if (current.district.isNotEmpty) query['district'] = current.district;
    if (current.hasNearMe) {
      query['lat'] = current.lat!.toString();
      query['lng'] = current.lng!.toString();
      if (current.radiusKm != null) query['radius'] = current.radiusKm!.toString();
    }
    if (current.openNow) query['openNow'] = '1';
    if (current.weekend) query['weekend'] = '1';
    final json = await _client.getJson(
      '/orgs/map?${Uri(queryParameters: query).query}',
    );
    return organizationMapPageFromJson(json);
  }

  @override
  Future<OrganizationDetail> getOrganization(String slug) async {
    final cached = _detailCache[slug];
    if (cached != null) return cached;
    final json = await _client.getJson('/orgs/${Uri.encodeComponent(slug)}');
    final item = json['org'];
    if (item is! Map) throw const UnexpectedFailure('API өгөгдөл буруу байна.');
    final detail = OrganizationDetailDto.fromJson(
      Map<String, dynamic>.from(item),
    ).toDomain();
    _detailCache[slug] = detail;
    return detail;
  }
}
